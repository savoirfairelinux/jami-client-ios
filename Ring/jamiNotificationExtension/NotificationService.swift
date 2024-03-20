/*
 *  Copyright (C) 2021-2022 Savoir-faire Linux Inc.
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

class NotificationService: UNNotificationServiceExtension {

    private static let localNotificationName = Notification.Name("com.savoirfairelinux.jami.appActive.internal")

    private let notificationTimeout = DispatchTimeInterval.seconds(25)

    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent = UNMutableNotificationContent()
    private let httpStreamHandler = HTTPStreamHandler()

    private var adapterService: AdapterService = AdapterService(withAdapter: Adapter())

    private var accountIsActive = false
    var tasksCompleted = false /// all values from dht parsed, conversation synchronized if needed and files downloaded
    var numberOfFiles = 0 /// number of files need to be downloaded
    var numberOfMessages = 0 /// number of scheduled messages
    var syncCompleted = false
    var waitForCloning = false
    private let tasksGroup = DispatchGroup()
    var accountId = ""
    let thumbnailSize = 100

    typealias LocalNotification = (content: UNMutableNotificationContent, type: LocalNotificationType)

    private var pendingLocalNotifications = [String: [LocalNotification]]() /// local notification waiting for name lookup
    private var pendingCalls = [String: [AnyHashable: Any]]() /// calls waiting for name lookup
    private var names = [String: String]() /// map of peerId and best name

    // A private class used to encapsulate logic for reading HTTP streams
    class HTTPStreamHandler: NSObject, URLSessionDataDelegate {
        lazy var session: URLSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 10
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            return URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }()
        
        private var task: URLSessionDataTask?

        // A some state variables used to block until some data is received
        private let semaphore = DispatchSemaphore(value: 0)
        private var streamingDone = false
        private var streamData: String?
        private var streamError: Error?

        func startStreaming(from url: URL) -> String? {
            task = session.dataTask(with: url)
            // Start the data task
            task?.resume()
            // Wait here until the first chunk of data is received
            semaphore.wait()
            // Cancel the task from processing any more data (if it hasn't already been queued)
            cancelPendingTask()
            // If an error occurred, print it and return nil
            if let error = streamError {
                print("HTTP Stream error: \(error)")
                return nil
            }
            // Return the data
            return streamData
        }
        
        func cancelPendingTask() {
            task?.cancel()
        }

        // Delegate method called when data is received
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if let dataString = String(data: data, encoding: .utf8), !streamingDone {
                // Make the data available for return from `startStreaming`
                streamData = dataString
                // Prevent this method from processing any more data
                streamingDone = true
                // Signal the semaphore to unblock
                semaphore.signal()
            }
        }

        // Handle task completion, including errors
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                // Handle the error, for example, by setting an error property
                streamError = error
                if !streamingDone {
                    // If streaming is not marked as done, signal the semaphore to unblock
                    // This is important to handle cases where data may not be received due to the error
                    streamingDone = true
                    semaphore.signal()
                }
            }
        }
    }

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

        /// if main app is active extension should save notification data and let app handle notification
        saveData(data: requestData)
        if appIsActive() {
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
        if let data = httpStreamHandler.startStreaming(from: url) {
            tasksGroup.enter()
            print("$$$$$$$$$$ [\(Thread.current)] NOTIF HTTPStreamHandler got answer +++")
            let lines = data.split(whereSeparator: \.isNewline)
            for line in lines {
                do {
                    guard let jsonData = line.data(using: .utf8),
                          let map = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                          let keyPath = getKeyPath(data: requestData),
                          let treatedMessages = getTreatedMessagesPath(data: requestData) else {
                        return
                    }
                    let result = adapterService.decrypt(keyPath: keyPath.path, accountId: accountId, messagesPath: treatedMessages.path, value: map)
                    let handleCall: (String, String) -> Void = { [weak self] (peerId, hasVideo) in
                        guard let self = self else {
                            return
                        }
                        var info = request.content.userInfo
                        info["peerId"] = peerId
                        info["hasVideo"] = hasVideo
                        let name = self.bestName(accountId: self.accountId, contactId: peerId)
                        /// jami will be started. Set accounts to not active state
                        if self.accountIsActive {
                            self.accountIsActive = false
                            self.adapterService.stop(accountId: self.accountId)
                        }
                        if name.isEmpty {
                            info["displayName"] = peerId
                            self.pendingCalls[peerId] = info
                            self.startAddressLookup(address: peerId, accountId: self.accountId)
                            return
                        }
                        info["displayName"] = name
                        self.presentCall(info: info)
                    }
                    switch result {
                    case .call(let peerId, let hasVideo):
                        handleCall(peerId, "\(hasVideo)")
                        return
                    case .gitMessage(let convId):
                        self.handleGitMessage(convId: convId, loadAll: convId.isEmpty) // async
                    case .clone:
                        // Should start daemon and wait until clone completed
                        self.waitForCloning = true
                        self.handleGitMessage(convId: "", loadAll: false) // async
                    case .unknown:
                        break
                    }
                } catch {
                    print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler stream decoding error: \(error)")
                    print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler data line: \(line)")
                }
            }
            
            // Block here until: tasks done or nothing started
            
            self.verifyTasksStatus()
            _ = tasksGroup.wait(timeout: .now() + notificationTimeout)
        } else {
            print("$$$$$$$$$$ [\(Thread.current)] HTTPStreamHandler didn't get answer ---")
        }

        // serialization failed , Error Domain=NSCocoaErrorDomain Code=3840 "Unterminated string around line 1, column 10." UserInfo={NSDebugDescription=Unterminated string around line 1, column 10., NSJSONSerializationErrorIndex=10}
              //  _ = tasksGroup.wait(timeout: .now() + notificationTimeout)
    }

    override func serviceExtensionTimeWillExpire() {
        if !self.tasksCompleted {
            print("$$$$$$$$$$ [\(Thread.current)] URLSession failed --- done")
            self.tasksCompleted = true
            self.tasksGroup.leave()
        }
        finish()
    }

    private func isResubscribe(accountId: String, data: [String: String]) -> Bool {
        let isResubscribe = data["timeout"] != nil && data["timeout"] != "<null>"
        if !isResubscribe {
            return false
        }
        self.accountIsActive = true
        self.adapterService.startAccount(accountId: accountId, convId: "", loadAll: false)
        self.adapterService.pushNotificationReceived(accountId: accountId, data: data)
        // wait to proceed pushNotificationReceived
        sleep(5)
        return true
    }

    private func handleGitMessage(convId: String, loadAll: Bool) {
        /// check if account already acive
        guard !self.accountIsActive else { return }
        self.accountIsActive = true
       // tasksGroup.enter()

        print("$$$$$$$$$$ [\(Thread.current)] handleGitMessage 1")
        
        self.adapterService.startAccountsWithListener(accountId: self.accountId, convId: convId, loadAll: loadAll) { [weak self] event, eventData in
            guard let self = self else {
                return
            }

            print("$$$$$$$$$$ [\(Thread.current)] handleGitMessage 2 \(event)")

            switch event {
            case .message:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                self.numberOfMessages += 1
                self.configureMessageNotification(from: eventData.jamiId, body: eventData.content, accountId: self.accountId, conversationId: eventData.conversationId, groupTitle: "")
            case .fileTransferDone:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                if let url = URL(string: eventData.content) {
                    self.configureFileNotification(from: eventData.jamiId, url: url, accountId: self.accountId, conversationId: eventData.conversationId)
                } else {
                    self.numberOfFiles -= 1
                    self.verifyTasksStatus()
                }
            case .syncCompleted:
                self.syncCompleted = true
                self.verifyTasksStatus()
            case .fileTransferInProgress:
                self.numberOfFiles += 1
            case .invitation:
                self.conversationUpdated(conversationId: eventData.conversationId, accountId: self.accountId)
                self.syncCompleted = true
                self.numberOfMessages += 1
                self.configureMessageNotification(from: eventData.jamiId,
                                                  body: eventData.content,
                                                  accountId: self.accountId,
                                                  conversationId: eventData.conversationId,
                                                  groupTitle: eventData.groupTitle)
            case .conversationCloned:
                self.waitForCloning = false
                self.verifyTasksStatus()
            }
        }
    }

    private func verifyTasksStatus() {
        guard !self.tasksCompleted else { return } /// we already left taskGroup
        /// waiting for lookup
        if !pendingCalls.isEmpty || !pendingLocalNotifications.isEmpty {
            return
        }
        /// We could finish in two cases:
        /// 1. we did not start account we are not waiting for the signals from the daemon
        /// 2. conversation synchronization completed and all files downloaded
        if !self.accountIsActive || (self.syncCompleted && self.numberOfFiles == 0 && self.numberOfMessages == 0 && !self.waitForCloning) {
            print("$$$$$$$$$$ [\(Thread.current)] URLSession finished --- done")
            self.tasksCompleted = true
            self.tasksGroup.leave()
        }
        self.httpStreamHandler.cancelPendingTask()
    }

    private func finish() {
        if self.accountIsActive {
            self.accountIsActive = false
            self.adapterService.stop(accountId: self.accountId)
        } else {
            self.adapterService.removeDelegate()
        }
        /// cleanup pending notifications
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
        if let contentHandler = contentHandler {
            contentHandler(self.bestAttemptContent)
        }
    }

    private func appIsActive() -> Bool {
        let group = DispatchGroup()
        defer {
            self.removeObserver()
            group.leave()
        }
        var appIsActive = false
        group.enter()
        /// post darwin notification and wait for the answer from the main app. If answer received app is active
        self.listenToMainAppResponse { _ in
            appIsActive = true
        }
        CFNotificationCenterPostNotification(notificationCenter, CFNotificationName(Constants.notificationReceived), nil, nil, true)
        /// wait fro 100 milliseconds. If no answer from main app is received app is not active.
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

    private func requestedData(request: UNNotificationRequest, map: [String: Any]) -> Bool {
        guard let userInfo = request.content.userInfo as? [String: Any] else { return false }
        guard let valueIds = userInfo["valueIds"] as? [String: String],
              let id = map["id"] else {
            return false
        }
        return valueIds.values.contains("\(id)")
    }

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

    private func startAddressLookup(address: String, accountId: String) {
        var nameServer = self.adapterService.getNameServerFor(accountId: accountId)
        nameServer = ensureURLPrefix(urlString: nameServer)
        let urlString = nameServer + "/addr/" + address
        guard let url = URL(string: urlString) else {
            self.lookupCompleted(address: address, name: nil)
            return
        }
        let defaultSession = URLSession(configuration: .default)
        let task = defaultSession.dataTask(with: url) {[weak self](data, response, _) in
            guard let self = self else { return }
            var name: String?
            defer {
                self.lookupCompleted(address: address, name: name)
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

    private func lookupCompleted(address: String, name: String?) {
        for call in pendingCalls where call.key == address {
            var info = call.value
            if let name = name {
                info["displayName"] = name
            }
            presentCall(info: info)
            return
        }
        for pending in pendingLocalNotifications where pending.key == address {
            let notifications = pending.value
            for notification in notifications {
                if let name = name {
                    notification.content.title = name
                }
                presentLocalNotification(notification: notification)
            }
            pendingLocalNotifications.removeValue(forKey: address)
        }
    }

    private func needUpdateNotification(notification: LocalNotification, peerId: String, accountId: String) {
        if var pending = pendingLocalNotifications[peerId] {
            pending.append(notification)
            pendingLocalNotifications[peerId] = pending
        } else {
            pendingLocalNotifications[peerId] = [notification]
        }
        startAddressLookup(address: peerId, accountId: accountId)
    }
}
// MARK: paths
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

    private func getTreatedMessagesPath(data: [String: String]) -> URL? {
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

// MARK: present notifications
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

    private func configureFileNotification(from: String, url: URL, accountId: String, conversationId: String) {
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        let imageName = url.lastPathComponent
        content.body = imageName
        var data = [String: String]()
        data[Constants.NotificationUserInfoKeys.participantID.rawValue] = from
        data[Constants.NotificationUserInfoKeys.accountID.rawValue] = accountId
        data[Constants.NotificationUserInfoKeys.conversationID.rawValue] = conversationId
        content.userInfo = data
        if let image = createThumbnailImage(fileURLString: url.path), let attachement = createAttachment(identifier: imageName, image: image, options: nil) {
            content.attachments = [ attachement ]
        }
        let title = self.bestName(accountId: accountId, contactId: from)
        if title.isEmpty {
            content.title = from
            needUpdateNotification(notification: LocalNotification(content, .file), peerId: from, accountId: accountId)
        } else {
            content.title = title
            presentLocalNotification(notification: LocalNotification(content, .file))
        }
    }

    private func configureMessageNotification(from: String, body: String, accountId: String, conversationId: String, groupTitle: String) {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = UNNotificationSound.default
        var data = [String: String]()
        data[Constants.NotificationUserInfoKeys.participantID.rawValue] = from
        data[Constants.NotificationUserInfoKeys.accountID.rawValue] = accountId
        data[Constants.NotificationUserInfoKeys.conversationID.rawValue] = conversationId
        content.userInfo = data
        let title = !groupTitle.isEmpty ? groupTitle : self.bestName(accountId: accountId, contactId: from)
        if title.isEmpty {
            content.title = from
            needUpdateNotification(notification: LocalNotification(content, .message), peerId: from, accountId: accountId)
        } else {
            content.title = title
            presentLocalNotification(notification: LocalNotification(content, .message))
        }
    }

    private func presentLocalNotification(notification: LocalNotification) {
        let content = notification.content
        setNotificationCount(notification: content)
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let notificationRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { [weak self] (error) in
            if notification.type == .message {
                self?.numberOfMessages -= 1
            } else {
                self?.numberOfFiles -= 1
            }
            self?.verifyTasksStatus()
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
        }
    }

    private func presentCall(info: [AnyHashable: Any]) {
        CXProvider.reportNewIncomingVoIPPushPayload(info, completion: { error in
            print("NotificationService", "Did report voip notification, error: \(String(describing: error))")
        })
        self.pendingCalls.removeAll()
        self.pendingLocalNotifications.removeAll()
        self.verifyTasksStatus()
    }
}
