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

protocol DarwinNotificationHandler {
    func listenToMainAppResponse(completion: @escaping (Bool) -> Void)
    func removeObserver()
}

enum NotificationField: String {
    case key
    case accountId = "to"
    case aps
}

class NotificationService: UNNotificationServiceExtension {

    private static let localNotification = Notification.Name("com.savoirfairelinux.jami.appActive.internal")

    private let notificationTimeout = DispatchTimeInterval.seconds(7)

    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent = UNMutableNotificationContent()

    private var adapterService: AdapterService = AdapterService(withAdapter: Adapter())

    private var accountIsActive = false
    var tasksCompleted = false /// all values from dht parsed, conversation synchronized if needed and files downloaded
    var numberOfFiles = 0 /// number of files need to be downloaded
    var syncCompleted = false
    private let tasksGroup = DispatchGroup()
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

        /// app is not active. Querry value from dht
        guard let proxyURL = getProxyCaches(data: requestData),
              var proxy = try? String(contentsOf: proxyURL, encoding: .utf8) else {
            return
        }
        if !proxy.hasPrefix("http://") {
            proxy = "http://" + proxy
        }
        guard let urlPrpxy = URL(string: proxy),
              let url = getRequestURL(data: requestData, proxyURL: urlPrpxy) else {
            return
        }
        tasksGroup.enter()
        let task = URLSession.shared.dataTask(with: url) {[weak self] (data, _, _) in
            guard let self = self,
                  let data = data else {
                return
            }
            let str = String(decoding: data, as: UTF8.self)
            let lines = str.split(whereSeparator: \.isNewline)
            for line in lines {
                do {
                    guard let jsonData = line.data(using: .utf8),
                          let map = try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String: Any],
                          let keyPath = self.getKeyPath(data: requestData),
                          let treatedMessages = self.getTreatedMessagesPath(data: requestData) else {
                        return }
                    let result = self.adapterService.decrypt(keyPath: keyPath.path, messagesPath: treatedMessages.path, value: map)
                    let handleCall: (String, String) -> Void = { [weak self] (peerId, hasVideo) in
                        guard let self = self else {
                            return
                        }
                        if #available(iOSApplicationExtension 14.5, *) {
                            /// jami will be started. Set accounts to not active state
                            if self.accountIsActive {
                                self.accountIsActive = false
                                self.adapterService.stop()
                            }
                            var info = request.content.userInfo
                            info["peerId"] = peerId
                            info["hasVideo"] = hasVideo
                            CXProvider.reportNewIncomingVoIPPushPayload(info, completion: { error in
                                print("NotificationService", "Did report voip notification, error: \(String(describing: error))")
                            })
                            self.verifyTasksStatus()
                        }
                    }
                    switch result {
                    case .call(let peerId, let hasVideo):
                        handleCall(peerId, "\(hasVideo)")
                    case .gitMessage:
                        /// check if account already acive
                        guard !self.accountIsActive else { break }
                        self.accountIsActive = true
                        self.adapterService.startAccountsWithListener { [weak self] event, eventData in
                            guard let self = self else {
                                return
                            }
                            switch event {
                            case .message:
                                self.presentMessageNotification(from: eventData.jamiId, body: eventData.content)
                            case .fileTransferDone:
                                if let url = URL(string: eventData.content) {
                                    self.presentFileNotification(from: eventData.jamiId, url: url)
                                }
                                self.numberOfFiles -= 1
                                self.verifyTasksStatus()
                            case .syncCompleted:
                                self.syncCompleted = true
                                self.verifyTasksStatus()
                            case .fileTransferInProgress:
                                self.numberOfFiles += 1
                            case .call:
                                handleCall(eventData.jamiId, eventData.content)
                            }
                        }
                    case .unknown:
                        break
                    }
                } catch {
                    print("serialization failed , \(error)")
                }
            }
            self.verifyTasksStatus()
        }
        task.resume()
        _ = tasksGroup.wait(timeout: .now() + notificationTimeout)
    }

    override func serviceExtensionTimeWillExpire() {
        finish()
    }

    private func verifyTasksStatus() {
        guard !self.tasksCompleted else { return } /// we already left taskGroup
        /// We could finish in two cases:
        /// 1. we did not start account we are not waiting for the signals from the daemon
        /// 2. conversation synchronization completed and all files downloaded
        if !self.accountIsActive || (self.syncCompleted && self.numberOfFiles == 0) {
            self.tasksCompleted = true
            self.tasksGroup.leave()
        }
    }

    private func finish() {
        if self.accountIsActive {
            self.accountIsActive = false
            self.adapterService.stop()
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

    private func requestedData(request: UNNotificationRequest, map: [String: Any]) -> Bool {
        guard let userInfo = request.content.userInfo as? [String: Any] else { return false }
        guard let valueIds = userInfo["valueIds"] as? [String: String],
              let id = map["id"] else {
            return false
        }
        return valueIds.values.contains("\(id)")
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
}

// MARK: DarwinNotificationHandler
extension NotificationService: DarwinNotificationHandler {
    func listenToMainAppResponse(completion: @escaping (Bool) -> Void) {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(notificationCenter,
                                        observer, { (_, _, _, _, _) in
                                            NotificationCenter.default.post(name: NotificationService.localNotification,
                                                                            object: nil,
                                                                            userInfo: nil)
                                        },
                                        Constants.notificationAppIsActive,
                                        nil,
                                        .deliverImmediately)
        NotificationCenter.default.addObserver(forName: NotificationService.localNotification, object: nil, queue: nil) { _ in
            completion(true)
        }
    }

    func removeObserver() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(notificationCenter, observer)
        NotificationCenter.default.removeObserver(self, name: NotificationService.localNotification, object: nil)
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
            let imageData = UIImage.pngData(image)
            try imageData()?.write(to: fileURL)
            let imageAttachment = try UNNotificationAttachment.init(identifier: identifier, url: fileURL, options: options)
            return imageAttachment
        } catch {}
        return nil
    }

    private func presentFileNotification(from: String, url: URL) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming file"
        let imageName = url.lastPathComponent
        content.subtitle = from
        content.body = imageName
        if let image = UIImage(contentsOfFile: url.path), let attachement = createAttachment(identifier: imageName, image: image, options: nil) {
            content.attachments = [ attachement ]
        }
        content.sound = UNNotificationSound.default
        setNotificationCount(notification: content)
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let identifier = Int64(arc4random_uniform(10000000))
        let notificationRequest = UNNotificationRequest(identifier: "\(identifier)", content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
        }
    }

    private func presentMessageNotification(from: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming message"
        content.subtitle = from
        content.body = body
        content.sound = UNNotificationSound.default
        setNotificationCount(notification: content)
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let identifier = Int64(arc4random_uniform(10000000))
        let notificationRequest = UNNotificationRequest(identifier: "\(identifier)", content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
        }
    }
}
