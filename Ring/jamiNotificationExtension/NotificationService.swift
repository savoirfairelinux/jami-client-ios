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

/*
 * This class is responsible for handling incoming notifications from the DHT proxy server.
 * The steps are as follows:
 *  1. The notification request is received as a JSON object and is processed to extract the necessary data
 *  2. If the main app is active, the notification data is saved and the app is notified to handle synchronization
 *     instead of the extension
 *  3. If the main app is not active, the notification data is used to start a data stream from the proxy server
 *     over HTTP
 *  4. The data stream is processed line by line, and each line is decrypted and processed
 *  5. The decrypted data is used to obtain the information needed to determine the action to take
 *  6. The action is taken, which may involve presenting a local notification or stopping the current backend
 *     instance and handing off control the foreground app (in the case of an incoming call)
 *
 * The class also handles the retrieval of contact names from the name server, which is done asynchronously.
 * In the case of a name being required, the notification is enqueued and the name is retrieved before the
 * notification is presented.
 *
 * The actions taken based on the notification data are as follows:
 *  - If the data is a call, the call is presented (the extension can be stopped as the foreground app will take over)
 *  - If the data is a message, the backend is started (if not already active) and events are parsed until the message
 *    body is received and enqueue for presentation
 *  - If the data is a file, the backend is started (if not already active) and events are parsed until the file is
 *    downloaded and the notification is enqueued for presentation
 *  - If the data is a clone request, the backend is started and events are parsed until the clone is completed
 *
 * Backend event handling is kept alive using a simple reference counting mechanism `itemsToPresent` and `syncCompleted`
 * which are incremented and decremented as events are processed and completed. When all events are processed and the
 * clone is completed, the backend is stopped. The HTTP stream is cancelled once all value IDs are processed or the
 * notification times out (30 seconds).
 */

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
            print("[\(Thread.current)] AutoDispatchGroup entering new task: \(id)")
            taskIds.insert(id)
            group.enter()
        }
    }

    func leave(id: String) {
        tasksQueue.sync {
            guard taskIds.contains(id) else { return }
            print("[\(Thread.current)] AutoDispatchGroup leaving task: \(id)")
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
        print("[\(Thread.current)] Starting URL Stream: \(url)")
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
        print("[\(Thread.current)] Stream handling complete")
        if let error = error {
            self.subject.onError(error)
        } else {
            self.subject.onCompleted()
        }
    }
}

// MARK: NotificationService
class NotificationService: UNNotificationServiceExtension {
    typealias LocalNotification = (content: UNMutableNotificationContent, type: LocalNotificationType)
    private static let localNotificationName = Notification.Name(appIdentifier + ".appActive.internal")

    private let notificationTimeout = DispatchTimeInterval.seconds(25)
    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent = UNMutableNotificationContent()

    // All asynchronous tasks are managed using the AutoDispatchGroup which tracks tasks using
    // IDs. Both the streaming and Jami backend tasks will be waited upon using this group.
    private let autoDispatchGroup = AutoDispatchGroup()
    private let httpStreamHandler = HTTPStreamHandler()
    private let disposeBag = DisposeBag()

    // The following objects are used to manage access to the Jami backend for synchronization
    private var accountIsActive = ManagedAtomic<Bool>(false)
    private var accountId: String = ""
    private var adapterService: AdapterService = AdapterService(withAdapter: Adapter())
    private var jamiTaskId: String = ""
    private var idsToProcess: Set<String> = []
    private let taskPropertyQueue = DispatchQueue(label: appIdentifier + ".TaskProperty.queue")
    // The following describe scheduled events and will be synchronized with the DispatchQueue
    private var itemsToPresent = 0
    private var syncCompleted = false
    private var waitForCloning = false

    // A queue of pending local notifications, waiting for a name lookup
    private let notificationQueue = DispatchQueue(label: appIdentifier + ".Notification.queue")
    private var pendingLocalNotifications = [String: [LocalNotification]]() // local notification waiting for name lookup
    private var pendingCalls = [String: [AnyHashable: Any]]() // calls waiting for name lookup
    private var names = [String: String]() // map of peerId and best name
    private let thumbnailSize = 100

    // Entry point for processing incoming notification requests.
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler

        // Using Task.init to replace deprecated async method
        Task {
            self.processNotificationRequest(request)
            _ = autoDispatchGroup.wait(timeout: .now() + notificationTimeout)
            self.finish()
        }
    }

    // Handles the initial processing of the notification request.
    private func processNotificationRequest(_ request: UNNotificationRequest) {
        print("------> [\(Thread.current)] Handling new notification")

        let requestData = requestToDictionary(request: request)
        guard !requestData.isEmpty else { return }

        // if main app is active extension should save notification data and let app handle notification
        saveDataIfNeeded(data: requestData)
        guard !appIsActive(),
              let accountId = requestData[NotificationField.accountId.rawValue],
              !isResubscribe(accountId: accountId, data: requestData) else {
            return
        }

        self.accountId = accountId
        prepareAndStartStreaming(for: request, with: requestData)
    }

    // Prepares for and starts the data stream based on notification data.
    private func prepareAndStartStreaming(for request: UNNotificationRequest, with requestData: [String: String]) {
        guard let idsString = requestData["ids"],
              let keyURL = getKeyURL(data: requestData),
              let treatedMessagesURL = getTreatedMessagesURL(data: requestData),
              let proxyURL = getProxyCaches(data: requestData),
              let url = getRequestURL(data: requestData, path: proxyURL) else {
            return
        }

        // Transform the comma-separated ids string
        self.idsToProcess = Set(idsString.split(separator: ",").map { String($0) })

        startStreaming(from: url, for: request, keyURL: keyURL, treatedMessagesURL: treatedMessagesURL)
    }

    // Starts streaming data from a specified URL and processes received lines.
    private func startStreaming(from url: URL, for request: UNNotificationRequest, keyURL: URL, treatedMessagesURL: URL) {
        let taskId = UUID().uuidString
        autoDispatchGroup.enter(id: taskId)

        httpStreamHandler.startStreaming(from: url)
            .subscribe(onNext: { [weak self] line in
                self?.processStreamLine(line, with: request, keyURL: keyURL, treatedMessagesURL: treatedMessagesURL)
            }, onError: { [weak self] error in
                print("[\(Thread.current)] Error streaming data: \(error)")
                self?.completeStreaming(taskId: taskId)
            }, onCompleted: { [weak self] in
                self?.completeStreaming(taskId: taskId)
            })
            .disposed(by: disposeBag)
    }

    // Processes each line received from the data stream.
    private func processStreamLine(_ line: String, with request: UNNotificationRequest, keyURL: URL, treatedMessagesURL: URL) {
        do {
            guard let jsonData = line.data(using: .utf8),
                  let map = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                  let id = map["id"] as? String, idsToProcess.contains(id),
                  map["cypher"] != nil else {
                return
            }

            idsToProcess.remove(id)
            processMap(map: map, keyURL: keyURL, treatedMessagesURL: treatedMessagesURL, userInfo: request.content.userInfo)
            if idsToProcess.isEmpty {
                httpStreamHandler.cancelStreaming()
            }
        } catch {
            print("[\(Thread.current)] Stream decoding error: \(error) line: \(line)")
        }
    }

    private func completeStreaming(taskId: String) {
        self.verifyTasksStatus()
        self.autoDispatchGroup.leave(id: taskId)
    }

    private func processMap(map: [String: Any], keyURL: URL, treatedMessagesURL: URL, userInfo: [AnyHashable: Any]) {
        let result = adapterService.decrypt(keyPath: keyURL.path, accountId: self.accountId, messagesPath: treatedMessagesURL.path, value: map)
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
        print("[\(Thread.current)] Notification handling timeout")
        finish()
    }

    private func isResubscribe(accountId: String, data: [String: String]) -> Bool {
        let isResubscribe = data["timeout"] != nil && data["timeout"] != "<null>"
        if !isResubscribe {
            return false
        }
        self.accountIsActive.store(true, ordering: .relaxed)
        self.adapterService.startAccount(accountId: accountId, convId: "", loadAll: false)
        self.adapterService.pushNotificationReceived(accountId: accountId, data: data)
        // TODO: comment this a bit more
        // wait to proceed pushNotificationReceived
        sleep(5)
        return true
    }

    private func handleGitMessage(convId: String, loadAll: Bool) {
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
                self.autoDispatchGroup.leave(id: jamiTaskId)
            }
        }
    }

    private func finish() {
        if self.accountIsActive.compareExchange(expected: true, desired: false, ordering: .relaxed).original {
            self.adapterService.stop(accountId: self.accountId)
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
        print("<------ [\(Thread.current)] Finished handling notification")
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

    private func saveDataIfNeeded(data: [String: String]) {
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
        for key in userInfo.keys {
            /// "aps" is a field added for alert notification type, so it could be received in the extension. This field is not needed by dht
            if String(describing: key) == NotificationField.aps.rawValue {
                continue
            }
            if let value = userInfo[key] {
                let keyString = String(describing: key)
                let valueString = String(describing: value)
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

    private func getKeyURL(data: [String: String]) -> URL? {
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
        if !config.groupTitle.isEmpty {
            content.title = config.groupTitle
        } else {
            content.title = self.bestName(accountId: self.accountId, contactId: config.from)
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
