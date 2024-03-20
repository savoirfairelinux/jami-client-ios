/*
 *  Copyright (C) 2021-2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import UserNotifications
import UIKit
import CallKit
import Foundation
import CoreFoundation
import os
import Darwin
import Contacts
import RxSwift
import Atomics

// swiftlint:disable file_length

protocol DarwinNotificationHandler {
    func listenToMainAppResponse(completion: @escaping (Bool) -> Void)
    func removeObserver()
}

enum NotificationField: String {
    case key
    case accountId = "to"
    case aps
}

enum LocalNotificationType: String {
    case message
    case file
}

// TODO: groupTitle is not used and should be set
struct NotificationConfig {
    let from: String
    var url: URL?
    let body: String
    let conversationId: String
    let groupTitle: String
}

// App identifier constant
let appIdentifier = "com.savoirfairelinux.jami"

// MARK: AutoDispatchGroup helper
class AutoDispatchGroup {
    private var taskIds = Set<String>()
    private let group = DispatchGroup()
    private let tasksQueue = DispatchQueue(label: appIdentifier + ".AutoDispatchGroup.queue")

    func enter(id: String) {
        tasksQueue.sync {
            print("$$$$$$$$$$ [\(Thread.current)] AutoDispatchGroup entering task: \(id)")
            taskIds.insert(id)
            group.enter()
        }
    }

    func leave(id: String) {
        tasksQueue.sync {
            guard taskIds.contains(id) else { return }
            print("$$$$$$$$$$ [\(Thread.current)] AutoDispatchGroup leaving task: \(id)")
            taskIds.remove(id)
            group.leave()
        }
    }

    func wait(timeout: DispatchTime = .distantFuture) -> DispatchTimeoutResult {
        group.wait(timeout: timeout)
    }
}

class HTTPStreamHandler: NSObject, URLSessionDataDelegate {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var dataBuffer = Data()
    private var task: URLSessionDataTask?
    private var subject = PublishSubject<String>()
    private let taskQueue = DispatchQueue(label: appIdentifier + ".HTTPStreamHandler.queue")

    func startStreaming(from url: URL) -> Observable<String> {
        taskQueue.sync {
            self.task = self.session.dataTask(with: url)
            self.task?.resume()
        }
        return subject
            .do(onDispose: { [weak self] in
                self?.cancelPendingTask()
            })
    }

    func cancelPendingTask() {
        taskQueue.sync {
            task?.cancel()
        }
    }

    func cancelStreaming() {
        cancelPendingTask()
        subject.onCompleted()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var receivedStrings = [String]()
        taskQueue.sync {
            self.dataBuffer.append(data)
            while let range = self.dataBuffer.range(of: "\n".data(using: .utf8)!) {
                let lineData = self.dataBuffer.subdata(in: 0..<range.lowerBound)
                self.dataBuffer.removeSubrange(0..<range.upperBound)
                if let lineString = String(data: lineData, encoding: .utf8) {
                    receivedStrings.append(lineString)
                }
            }
        }
        for string in receivedStrings {
            subject.onNext(string)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.subject.onError(error)
        } else {
            self.subject.onCompleted()
        }
    }
}

// MARK: NotificationService
class NotificationService: UNNotificationServiceExtension {

    private static let localNotificationName = Notification.Name(appIdentifier + ".appActive.internal")
    private let notificationTimeout = DispatchTimeInterval.seconds(25)
    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent = UNMutableNotificationContent()
    private let httpStreamHandler = HTTPStreamHandler()
    private let disposeBag = DisposeBag()

    private var adapterService: AdapterService = AdapterService(withAdapter: Adapter())

    private var accountIsActive = ManagedAtomic<Bool>(false)

    private let taskPropertyQueue = DispatchQueue(label: appIdentifier + ".TaskProperty.queue")
    // The following describe scheduled events and will be synchronized with the DispatchQueue
    private var itemsToPresent = 0
    private var syncCompleted = false
    private var waitForCloning = false
    
    private let autoDispatchGroup = AutoDispatchGroup()
    private var jamiTaskId: String = ""

    private var accountId: String = ""
    let thumbnailSize = 100

    typealias LocalNotification = (content: UNMutableNotificationContent, type: LocalNotificationType)

    // A queue of pending local notifications, waiting for a name lookup
    private let notificationQueue = DispatchQueue(label: appIdentifier + ".Notification.queue")
    private var pendingLocalNotifications = [String: [LocalNotification]]() /// local notification waiting for name lookup
    private var pendingCalls = [String: [AnyHashable: Any]]() /// calls waiting for name lookup
    private var names = [String: String]() /// map of peerId and best name

    // swiftlint:disable cyclomatic_complexity
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        defer {
            finish()
        }
        let requestData = requestToDictionary(request: request)
        if requestData.isEmpty {
            return
        }

        // let's get a list of the IDs that we are interested in, which is a comma separated
        // string at key: "ids" in the requestData dictionary
        guard let idsString = requestData["ids"] else {
            // if we don't have any IDs to process, we can't do anything
            return
        }
        var idsToProcess = Set(idsString.split(separator: ",").map { String($0) })

        /// if main app is active extension should save notification data and let app handle notification
        saveData(data: requestData)
        if appIsActive() {
            return
        }

        guard let keyPath = getKeyPath(data: requestData),
              let treatedMessagesURL = getTreatedMessagesURL(data: requestData) else {
            return
        }

        guard let account = requestData[NotificationField.accountId.rawValue] else { return }
        accountId = account
        if isResubscribe(accountId: accountId, data: requestData) {
            return
        }
        /// app is not active. Querry value from dht
        guard let proxyURL = getProxyCaches(data: requestData),
              let url = getRequestURL(data: requestData, path: proxyURL) else {
            return
        }

        print("$$$$$$$$$$ [\(Thread.current)] NOTIF HTTPStreamHandler start URL: \(url)")
        let taskId = UUID().uuidString
        self.autoDispatchGroup.enter(id: taskId)
        httpStreamHandler.startStreaming(from: url)
                .subscribe(onNext: { [self, weak httpStreamHandler] line in
                    print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler Received line: \(line)")
                    do {
                        // Filter out lines that don't contain the expected JSON structure
                        guard let jsonData = line.data(using: .utf8),
                              let map = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                              let id = map["id"] as? String,
                              map["cypher"] != nil else {
                            return
                        }
                        // Check if the ID is in the list of IDs we are interested in
                        if !idsToProcess.contains(id) {
                            print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler skipping line for id: \(id)")
                            return
                        }
                        // Remove the ID from the list of IDs to process so we don't process it again
                        idsToProcess.remove(id)
                        // Process the data
                        processLine(line: line, keyPath: keyPath, accountId: accountId,
                                    treatedMessagesURL: treatedMessagesURL, userInfo: request.content.userInfo)
                        // If we have processed all the IDs, we can finish and invoke onCompleted, then just wait for the taskGroup to finish
                        if idsToProcess.isEmpty {
                            print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler all IDs processed")
                            httpStreamHandler?.cancelStreaming()
                        }
                    } catch {
                        print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler stream decoding error: \(error) line: \(line)")
                    }
                }, onError: {[weak self] error in
                    print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler Error: \(error)")
                    self?.verifyTasksStatus()
                    self?.autoDispatchGroup.leave(id: taskId)
                }, onCompleted: {[weak self] in
                    print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler Streaming completed")
                    self?.verifyTasksStatus()
                    self?.autoDispatchGroup.leave(id: taskId)
                })
                .disposed(by: disposeBag)
        _ = autoDispatchGroup.wait(timeout: .now() + notificationTimeout)
        print("$$$$$$$$$$ [\(Thread.current)] NOTIF all handling finished !!!!!!")
    }
    // swiftlint:enable cyclomatic_complexity

    private func processLine(line: String, keyPath: URL, accountId: String, treatedMessagesURL: URL, userInfo: [AnyHashable: Any]) {
        print("$$$$$$$$$$ [\(Thread.current)] NOTIF process line: \(line)")
        guard let jsonData = line.data(using: .utf8),
              let map = (try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)) as? [String: Any] else {
            print("$$$$$$$$$$ [\(Thread.current)] NOTIF failed to parse JSON")
            return
        }
        let result = adapterService.decrypt(keyPath: keyPath.path, accountId: accountId, messagesPath: treatedMessagesURL.path, value: map)
        switch result {
        case .call(let peerId, let hasVideo):
            ({ [weak self] (peerId, hasVideo) in
                guard let self = self else {
                    return
                }
                var info = userInfo
                info["peerId"] = peerId
                info["hasVideo"] = hasVideo
                let name = self.bestName(accountId: self.accountId, contactId: peerId)
                // jami will be started. Set accounts to not active state
                if self.accountIsActive.compareExchange(expected: true, desired: false, ordering: .relaxed).original {
                    self.adapterService.stop(accountId: self.accountId)
                }
                if name.isEmpty {
                    info["displayName"] = peerId
                    self.pendingCalls[peerId] = info
                    self.startAddressLookup(address: peerId)
                    return
                }
                info["displayName"] = name
                self.presentCall(info: info)
            })(peerId, "\(hasVideo)")
            return
        case .gitMessage(let convId):
            self.handleGitMessage(convId: convId, loadAll: convId.isEmpty) // async
        case .clone:
            // Should start daemon and wait until clone completed
            self.taskPropertyQueue.sync { self.waitForCloning = true }
            self.handleGitMessage(convId: "", loadAll: false) // async
        case .unknown:
            break
        }
    }

    override func serviceExtensionTimeWillExpire() {
        print("$$$$$$$$$$ [\(Thread.current)] NOTIF timeout --- serviceExtensionTimeWillExpire")
        finish()
    }

    private func isResubscribe(accountId: String, data: [String: String]) -> Bool {
        let isResubscribe = data["timeout"] != nil && data["timeout"] != "<null>"
        if !isResubscribe {
            return false
        }
        print("$$$$$$$$$$ [\(Thread.current)] NOTIF resubscribe")
        self.accountIsActive.store(true, ordering: .relaxed)
        self.adapterService.startAccount(accountId: accountId, convId: "", loadAll: false)
        self.adapterService.pushNotificationReceived(accountId: accountId, data: data)
        // TODO: comment this a bit more
        // wait to proceed pushNotificationReceived
        sleep(5)
        return true
    }

    private func handleGitMessage(convId: String, loadAll: Bool) {
        print("$$$$$$$$$$ [\(Thread.current)] handleGitMessage")
        // If the account is already active, return, otherwise we set it to active and continue
        if self.accountIsActive.compareExchange(expected: false, desired: true, ordering: .relaxed).original {
            return
        }

        jamiTaskId = UUID().uuidString
        self.autoDispatchGroup.enter(id: jamiTaskId)
        self.adapterService.startAccountsWithListener(accountId: self.accountId, convId: convId, loadAll: loadAll) { [weak self] event, eventData in
            guard let self = self else {
                return
            }

            print("$$$$$$$$$$ [\(Thread.current)] handleGitMessage event: \(event)")
            var notifConfig = NotificationConfig(from: eventData.jamiId, url: nil, body: eventData.content,
                                                 conversationId: eventData.conversationId, groupTitle: eventData.groupTitle)
            switch event {
            case .message:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                self.taskPropertyQueue.sync { self.itemsToPresent += 1 }
                self.configureAndPresentNotification(config: notifConfig, type: LocalNotificationType.message)
            case .fileTransferDone:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                // If the content is a URL then we have already downloaded the file and can present the notification,
                // otherwise we need to download the file first, so add it to the items to present
                if let url = URL(string: eventData.content) {
                    notifConfig.url = url
                    self.configureAndPresentNotification(config: notifConfig, type: LocalNotificationType.file)
                } else {
                    self.taskPropertyQueue.sync { self.itemsToPresent -= 1 }
                    self.verifyTasksStatus()
                }
            case .syncCompleted:
                self.taskPropertyQueue.sync { self.syncCompleted = true }
                self.verifyTasksStatus()
            case .fileTransferInProgress:
                taskPropertyQueue.sync { self.itemsToPresent += 1 }
            case .invitation:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                self.taskPropertyQueue.sync {
                    self.syncCompleted = true
                    self.itemsToPresent += 1
                }
                self.configureAndPresentNotification(config: notifConfig, type: LocalNotificationType.message)
            case .conversationCloned:
                self.taskPropertyQueue.sync { self.waitForCloning = false }
                self.verifyTasksStatus()
            }
        }
    }

    private func verifyTasksStatus() {
        // waiting for lookup
        self.notificationQueue.sync {
            if !pendingCalls.isEmpty || !pendingLocalNotifications.isEmpty {
                return
            }
        }
        self.taskPropertyQueue.sync {
            // We could finish in two cases:
            // 1. we did not start account we are not waiting for the signals from the daemon
            // 2. conversation synchronization completed and all files downloaded
            if !self.accountIsActive.load(ordering: .relaxed) ||
                (self.syncCompleted && self.itemsToPresent == 0 && !self.waitForCloning) {	
                print("$$$$$$$$$$ [\(Thread.current)] verifyTasksStatus finished --- done")
                self.autoDispatchGroup.leave(id: jamiTaskId)
            }
        }
    }

    private func finish() {
        if self.accountIsActive.compareExchange(expected: true, desired: false, ordering: .relaxed).original {
            self.adapterService.stop(accountId: self.accountId)
            print("$$$$$$$$$$ [\(Thread.current)] After stop")
        } else {
            self.adapterService.removeDelegate()
        }
        // cleanup pending notifications
        self.notificationQueue.sync {
            if !self.pendingCalls.isEmpty, let info = self.pendingCalls.first?.value {
                self.presentCall(info: info)
            } else {
                for notifications in pendingLocalNotifications {
                    for notification in notifications.value {
                        self.presentLocalNotification(notification: notification)
                    }
                }
                pendingLocalNotifications.removeAll()
            }
        }
        if let contentHandler = contentHandler {
            contentHandler(self.bestAttemptContent)
        }
        self.httpStreamHandler.cancelStreaming()
    }

    private func appIsActive() -> Bool {
        let group = DispatchGroup()
        defer {
            self.removeObserver()
            group.leave()
        }
        var appIsActive = false
        group.enter()
        // post darwin notification and wait for the answer from the main app. If answer received app is active
        self.listenToMainAppResponse { _ in
            appIsActive = true
        }
        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(Constants.notificationReceived), nil, nil, true)
        // wait fro 300 milliseconds. If no answer from main app is received app is not active.
        _ = group.wait(timeout: .now() + 0.3)

        return appIsActive
    }

    private func saveData(data: [String: String]) {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }
        var notificationData = [[String: String]]()
        if let existingData = userDefaults.object(forKey: Constants.notificationData) as? [[String: String]] {
            notificationData = existingData
        }
        notificationData.append(data)
        userDefaults.set(notificationData, forKey: Constants.notificationData)
    }

    private func conversationUpdated(conversationId: String, accountId: String) {
        var conversationData = [String: String]()
        conversationData[Constants.NotificationUserInfoKeys.conversationID.rawValue] = conversationId
        conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue] = accountId
        self.setUpdatedConversations(conversation: conversationData)
    }

    private func setUpdatedConversations(conversation: [String: String]) {
        /*
         Save updated conversations so they can be reloaded when Jami
         becomes active.
         */
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }
        var conversationData = [[String: String]]()
        if let existingData = userDefaults.object(forKey: Constants.updatedConversations) as? [[String: String]] {
            conversationData = existingData
        }
        for data in conversationData
        where data[Constants.NotificationUserInfoKeys.conversationID.rawValue] ==
            conversation[Constants.NotificationUserInfoKeys.conversationID.rawValue] {
            return
        }

        conversationData.append(conversation)
        userDefaults.set(conversationData, forKey: Constants.updatedConversations)
    }

    private func requestToDictionary(request: UNNotificationRequest) -> [String: String] {
        var dictionary = [String: String]()
        let userInfo = request.content.userInfo
        print("$$$$$$$$$$ start NOTIF")
        for key in userInfo.keys {
            /// "aps" is a field added for alert notification type, so it could be received in the extension. This field is not needed by dht
            if String(describing: key) == NotificationField.aps.rawValue {
                continue
            }
            if let value = userInfo[key] {
                let keyString = String(describing: key)
                let valueString = String(describing: value)
                print("$$$$$$$$$$ \(keyString) - \(valueString)")
                dictionary[keyString] = valueString
            }
        }
        return dictionary
    }
}

// MARK: Name retrieval
extension NotificationService {
    private func bestName(accountId: String, contactId: String) -> String {
        if let name = self.names[contactId], !name.isEmpty {
            return name
        }
        if let contactProfileName = self.contactProfileName(accountId: accountId, contactId: contactId),
           !contactProfileName.isEmpty {
            self.names[contactId] = contactProfileName
            return contactProfileName
        }
        let registeredName = self.adapterService.getNameFor(address: contactId, accountId: accountId)
        if !registeredName.isEmpty {
            self.names[contactId] = registeredName
        }
        return registeredName
    }

    private func startAddressLookup(address: String) {
        var nameServer = self.adapterService.getNameServerFor(accountId: self.accountId)
        nameServer = ensureURLPrefix(urlString: nameServer)
        let urlString = nameServer + "/addr/" + address
        guard let url = URL(string: urlString) else {
            self.lookupCompleted(address: address)
            return
        }
        let defaultSession = URLSession(configuration: .default)
        let task = defaultSession.dataTask(with: url) {[weak self](data, response, _) in
            guard let self = self else { return }
            var name: String?
            defer {
                self.lookupCompleted(address: address)
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data else {
                return
            }
            do {
                guard let map = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: String] else { return }
                if map["name"] != nil {
                    name = map["name"]
                    self.names[address] = name
                }
            } catch {
                print("serialization failed , \(error)")
            }
        }
        task.resume()
    }

    private func ensureURLPrefix(urlString: String) -> String {
        var urlWithPrefix = urlString
        if !urlWithPrefix.hasPrefix("http://") && !urlWithPrefix.hasPrefix("https://") {
            urlWithPrefix = "http://" + urlWithPrefix
        }
        return urlWithPrefix
    }

    private func lookupCompleted(address: String) {
        let name = self.names[address]
        for call in pendingCalls where call.key == address {
            var info = call.value
            if let name = name {
                info["displayName"] = name
            }
            presentCall(info: info)
            return
        }
        var notificationsToPresent = [LocalNotification]()
        for pending in pendingLocalNotifications where pending.key == address {
            let notifications = pending.value
            for notification in notifications {
                if let name = name {
                    notification.content.title = name
                }
                notificationsToPresent.append(notification)
            }
            pendingLocalNotifications.removeValue(forKey: address)
        }
    }
}

// MARK: Paths and URLs
extension NotificationService {
    private func getRequestURL(data: [String: String], proxyURL: URL) -> URL? {
        guard let key = data[NotificationField.key.rawValue] else {
            return nil
        }
        return proxyURL.appendingPathComponent(key)
    }

    private func getRequestURL(data: [String: String], path: URL) -> URL? {
        guard let key = data[NotificationField.key.rawValue],
              let jsonData = NSData(contentsOf: path) as? Data else {
            return nil
        }
        guard let map = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: String],
              var proxyAddress = map.first?.value else {
            return nil
        }

        proxyAddress = ensureURLPrefix(urlString: proxyAddress)
        guard let urlPrpxy = URL(string: proxyAddress) else { return nil }
        return urlPrpxy.appendingPathComponent(key)
    }

    private func getKeyPath(data: [String: String]) -> URL? {
        guard let documentsPath = Constants.documentsPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return documentsPath.appendingPathComponent(accountId).appendingPathComponent("ring_device.key")
    }

    private func getTreatedMessagesURL(data: [String: String]) -> URL? {
        guard let cachesPath = Constants.cachesPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return cachesPath.appendingPathComponent(accountId).appendingPathComponent("treatedMessages")
    }

    private func getProxyCaches(data: [String: String]) -> URL? {
        guard let cachesPath = Constants.cachesPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return cachesPath.appendingPathComponent(accountId).appendingPathComponent("dhtproxy")
    }

    private func contactProfileName(accountId: String, contactId: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        let uri = "ring:" + contactId
        let path = documents.path + "/" + "\(accountId)" + "/profiles/" + "\(Data(uri.utf8).base64EncodedString()).vcf"
        if !FileManager.default.fileExists(atPath: path) { return nil }

        return VCardUtils.getNameFromVCard(filePath: path)
    }
}

// MARK: DarwinNotificationHandler
extension NotificationService: DarwinNotificationHandler {
    func listenToMainAppResponse(completion: @escaping (Bool) -> Void) {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(notificationCenter,
                                        observer, { (_, _, _, _, _) in
                                            NotificationCenter.default.post(name: NotificationService.localNotificationName,
                                                                            object: nil,
                                                                            userInfo: nil)
                                        },
                                        Constants.notificationAppIsActive,
                                        nil,
                                        .deliverImmediately)
        NotificationCenter.default.addObserver(forName: NotificationService.localNotificationName, object: nil, queue: nil) { _ in
            completion(true)
        }
    }

    func removeObserver() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(notificationCenter, observer)
        NotificationCenter.default.removeObserver(self, name: NotificationService.localNotificationName, object: nil)
    }

}

// MARK: Present and update notifications
extension NotificationService {
    private func createAttachment(identifier: String, image: UIImage, options: [NSObject: AnyObject]?) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(tmpSubFolderName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: tmpSubFolderURL, withIntermediateDirectories: true, attributes: nil)
            let imageFileIdentifier = identifier
            let fileURL = tmpSubFolderURL.appendingPathComponent(imageFileIdentifier)
            let imageData = image.jpegData(compressionQuality: 0.7)
            try imageData?.write(to: fileURL)
            let imageAttachment = try UNNotificationAttachment.init(identifier: identifier, url: fileURL, options: options)
            return imageAttachment
        } catch {}
        return nil
    }

    func createThumbnailImage(fileURLString: String) -> UIImage? {
        guard let escapedPath = fileURLString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        // Construct the file URL with the correct scheme and path
        guard let fileURL = URL(string: "file://" + escapedPath) else {
            return nil
        }

        let size = CGSize(width: thumbnailSize, height: thumbnailSize)

        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Int,
              let downsampledImage = createDownsampledImage(imageSource: imageSource,
                                                            targetSize: size,
                                                            pixelWidth: pixelWidth,
                                                            pixelHeight: pixelHeight) else {
            return nil
        }
        return UIImage(cgImage: downsampledImage)
    }

    func createDownsampledImage(imageSource: CGImageSource, targetSize: CGSize, pixelWidth: Int, pixelHeight: Int) -> CGImage? {
        let maxDimension = max(targetSize.width, targetSize.height)
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    // A generic function that configures a notification with the given content and type, and returns the notification
    private func configureNotification(config: NotificationConfig, type: LocalNotificationType) -> LocalNotification {
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        var data = [String: String]()
        data[Constants.NotificationUserInfoKeys.participantID.rawValue] = config.from
        data[Constants.NotificationUserInfoKeys.accountID.rawValue] = self.accountId
        data[Constants.NotificationUserInfoKeys.conversationID.rawValue] = config.conversationId
        content.userInfo = data
        switch type {
        case .message:
            content.body = config.body
        case .file:
            if let url = config.url {
                let imageName = url.lastPathComponent
                content.body = imageName
                if let image = createThumbnailImage(fileURLString: url.path),
                   let attachement = createAttachment(identifier: imageName, image: image, options: nil) {
                    content.attachments = [ attachement ]
                }
            }
        }
        if (!config.groupTitle.isEmpty) {
            content.title =  config.groupTitle
        } else {
            content.title =  self.bestName(accountId: self.accountId, contactId: config.from)
        }
        return (content, type)
    }

    private func configureAndPresentNotification(config: NotificationConfig, type: LocalNotificationType) {
        let notif = self.configureNotification(config: config, type: type)
        if notif.content.title.isEmpty {
            enqueueNotificationForNameUpdate(notification: notif, peerId: config.from)
        } else {
            self.presentLocalNotification(notification: notif)
        }
    }

    private func presentLocalNotification(notification: LocalNotification) {
        let content = notification.content
        setNotificationCount(notification: content)
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { [weak self] (error) in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
            guard let self = self else { return }
            self.taskPropertyQueue.sync { self.itemsToPresent -= 1 }
            self.verifyTasksStatus()
        }
    }

    private func presentCall(info: [AnyHashable: Any]) {
        // TODO: see if this should sync after daemon stop
        CXProvider.reportNewIncomingVoIPPushPayload(info, completion: { error in
            print("NotificationService", "Did report voip notification, error: \(String(describing: error))")
        })
        self.notificationQueue.sync {
            self.pendingCalls.removeAll()
            self.pendingLocalNotifications.removeAll()
        }
        self.verifyTasksStatus()
    }

    private func enqueueNotificationForNameUpdate(notification: LocalNotification, peerId: String) {
        self.notificationQueue.sync {
            if var pending = pendingLocalNotifications[peerId] {
                pending.append(notification)
                pendingLocalNotifications[peerId] = pending
            } else {
                pendingLocalNotifications[peerId] = [notification]
            }
        }
        startAddressLookup(address: peerId)
    }

    private func setNotificationCount(notification: UNMutableNotificationContent) {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }

        if let count = userDefaults.object(forKey: Constants.notificationsCount) as? NSNumber {
            let new: NSNumber = count.intValue + 1 as NSNumber
            notification.badge = new
            userDefaults.set(new, forKey: Constants.notificationsCount)
        }
    }
}
