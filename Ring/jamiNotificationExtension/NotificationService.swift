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

    /// darvin notifications
    private static let notificationReceived = CFNotificationName(rawValue: "com.savoirfairelinux.notificationExtension.receivedNotification" as CFString)
    private static let notificationAppIsActive = "com.savoirfairelinux.jami.appActive" as CFString
    /// local notifications
    private static let localNotification = Notification.Name("com.savoirfairelinux.jami.appActive.internal")
    /// user defaults
    private static let notificationData = "notificationData"
    private static let appGroupIdentifier = "group.com.savoirfairelinux.ring"

    private let documentsPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Documents")
    }()

    private let cachesPath: URL? = {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?.appendingPathComponent("Library").appendingPathComponent("Caches")
    }()

    private let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent!

    private var adapterService: AdapterService? = AdapterService(withAdapter: Adapter())

    static let myObserver = "anObserver"

    private var daemonStarted = false
    // swiftlint:disable cyclomatic_complexity
    // swiftlint:disable function_body_length
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        os_log("&&&&&&&&notification received")
        print("*****notification received")
        self.bestAttemptContent = UNMutableNotificationContent()
        self.adapterService = AdapterService(withAdapter: Adapter())
        self.contentHandler = contentHandler
        self.bestAttemptContent = UNMutableNotificationContent()
        defer {
            if self.daemonStarted && self.adapterService != nil {
                self.adapterService!.stopDaemon()
            }
            print("*****notification completed")
            os_log("&&&&&&&&notification completed")
            contentHandler(self.bestAttemptContent)
        }
        let requestData = requestToDictionary(request: request)
        if requestData.isEmpty {
            print("*****app is active")
            return
        }

        /// if main app is active extension should save notification data and let app handle notification
        saveData(data: requestData)
        if appIsActive() {
            return
        }

        /// app is not active. Querry value from dht
        guard let proxyURL = getProxyCaches(data: requestData),
              let proxy = try? String(contentsOf: proxyURL, encoding: .utf8) else {
            return
        }
        guard let urlPrpxy = URL(string: proxy),
              let url = getRequestURL(data: requestData, proxyURL: urlPrpxy) else {
            return
        }
        let group = DispatchGroup()
        group.enter()
        var taskCompleted = false
        let task = URLSession.shared.dataTask(with: url) {[weak self, weak group] (data, _, _) in
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
                    let result = self.adapterService!.decrypt(keyPath: keyPath.path, messagesPath: treatedMessages.path, value: map)
                    switch result {
                    case .call(let peerId, let isVideo):
                        if #available(iOSApplicationExtension 14.5, *) {
                            var info = request.content.userInfo
                            info["peerId"] = peerId
                            info["hasVideo"] = "\(isVideo)"
                            if self.daemonStarted && self.adapterService != nil {
                                self.daemonStarted = false
                                self.adapterService!.stopDaemon()
                            }
                            CXProvider.reportNewIncomingVoIPPushPayload(info, completion: { error in
                                print("NotificationService", "Did report voip notification, error: \(String(describing: error))")
                            })
                            if !taskCompleted {
                                os_log("&&&&&&&&call received, will leave group")
                                taskCompleted = true
                                group?.leave()
                            }
                            // we could return now, because jami would start and all other values will be proceed from there
                            return
                        }
                    case .gitMessage:
                        if !self.daemonStarted {
                            self.daemonStarted = true
                            os_log("&&&&&&&&need to pull commits")
                            self.adapterService!.startDaemonWithListener { [weak self, weak group] event, eventData in
                                guard let self = self else {
                                    return
                                }
                                switch event {
                                case .message:
                                    os_log("&&&&&&&&will present message notification")
                                    self.presentMessageNotification(from: eventData.jamiId, body: eventData.content)
                                case .fileTransfer:
                                    os_log("&&&&&&&&will present file notification")
                                    self.presentMessageNotification(from: eventData.jamiId, body: eventData.content)
                                case .completed:
                                    sleep(1)
                                    if !taskCompleted {
                                        os_log("&&&&&&&&completed, will leave group")
                                        taskCompleted = true
                                        group?.leave()
                                    }
                                }
                            }
                        }
                    case .unknown:
                        break
                    }
                } catch {
                    os_log("&&&&&&&&serialization failed")
                    print("serialization failed , \(error)")
                }
            }
            if !self.daemonStarted && !taskCompleted {
                os_log("&&&&&&&&daemon not started, will leave group")
                taskCompleted = true
                group?.leave()
            }
        }
        task.resume()
        _ = group.wait(timeout: .now() + 7)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler {
            os_log("&&&&&&&&notification service expire")
            contentHandler(self.bestAttemptContent)
        }
    }

    func appIsActive() -> Bool {
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
        CFNotificationCenterPostNotification(notificationCenter, NotificationService.notificationReceived, nil, nil, true)
        /// wait fro 100 milliseconds. If no answer from main app is received app is not active.
        _ = group.wait(timeout: .now() + 0.3)

        return appIsActive
    }

    func saveData(data: [String: String]) {
        guard let userDefaults = UserDefaults(suiteName: NotificationService.appGroupIdentifier) else {
            return
        }
        var notificationData = [[String: String]]()
        if let existingData = userDefaults.object(forKey: NotificationService.notificationData) as? [[String: String]] {
            notificationData = existingData
        }
        notificationData.append(data)
        userDefaults.set(notificationData, forKey: NotificationService.notificationData)
    }

    func requestToDictionary(request: UNNotificationRequest) -> [String: String] {
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

    func requestedData(request: UNNotificationRequest, map: [String: Any]) -> Bool {
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

    func getRequestURL(data: [String: String], proxyURL: URL) -> URL? {
        guard let key = data[NotificationField.key.rawValue] else {
            return nil
        }
        return proxyURL.appendingPathComponent(key)
    }

    func getKeyPath(data: [String: String]) -> URL? {
        guard let documentsPath = self.documentsPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return documentsPath.appendingPathComponent(accountId).appendingPathComponent("ring_device.key")
    }

    func getTreatedMessagesPath(data: [String: String]) -> URL? {
        guard let documentsPath = self.cachesPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return documentsPath.appendingPathComponent(accountId).appendingPathComponent("treatedMessages")
    }

    func getProxyCaches(data: [String: String]) -> URL? {
        guard let cachesPath = self.cachesPath,
              let accountId = data[NotificationField.accountId.rawValue] else {
            return nil
        }
        return cachesPath.appendingPathComponent(accountId).appendingPathComponent("dhtproxy")
    }
}

extension NotificationService: DarwinNotificationHandler {
    func listenToMainAppResponse(completion: @escaping (Bool) -> Void) {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(notificationCenter,
                                        observer, { (_, _, _, _, _) in
                                            NotificationCenter.default.post(name: NotificationService.localNotification,
                                                                            object: nil,
                                                                            userInfo: nil)
                                        },
                                        NotificationService.notificationAppIsActive,
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

    func presentMessageNotification(from: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming message"
        content.subtitle = from
        content.body = body
        content.sound = UNNotificationSound.default
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let identifier = Int64(arc4random_uniform(10000000))
        let notificationRequest = UNNotificationRequest(identifier: "\(identifier)", content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
        }
    }

    func presentfileNotification(from: String, url: String) {
        let content = UNMutableNotificationContent()
        content.title = "Incoming file"
        content.subtitle = from
        content.body = url
        if let url = URL(string: url),
           let attachment = try? UNNotificationAttachment(identifier: "image.jpg", url: url, options: nil) {
            content.attachments = [attachment]
        }
        content.sound = UNNotificationSound.default
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
