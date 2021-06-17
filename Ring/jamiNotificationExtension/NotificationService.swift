/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    private var adapterService: AdapterService!
    private var finished = true
    let group = DispatchGroup()

    private let center = CFNotificationCenterGetDarwinNotifyCenter()
    private var listenersStarted = false
    private static let notificationToPost = "com.savoirfairelinux.notificationExtension.receivedNotification" as CFString
    private static let notificationToListen = "com.savoirfairelinux.jami.appActiove" as CFString
    private var callback: ((_ mainAppHandledReceipt: Bool) -> Void)?
    var notificationProceed = false

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        if let userDefaults = UserDefaults(suiteName: "group.com.savoirfairelinux.ring") {
            let value = userDefaults.string(forKey: "appActive")
            if value == "true" {
                contentHandler(UNNotificationContent())
                return
            }
        }
        notificationProceed = false
        self.contentHandler = contentHandler
        self.checkIfAppActive { [weak self] active in
            guard !active, let self = self else {
                contentHandler(UNNotificationContent())
                return
            }
            self.startDeaemon(request: request)
        }
    }

    func startDeaemon(request: UNNotificationRequest) {
        finished = true
        bestAttemptContent = UNMutableNotificationContent()
        var notificationData = [String: String]()
        let data = request.content.userInfo
        for key in data.keys {
            if let value = data[key] {
                let valueString = String(describing: value)
                let keyString = String(describing: key)
                notificationData[keyString] = valueString
            }
        }
        group.enter()
        self.adapterService =
            AdapterService(withAdapter: Adapter(),
                           withEventHandler: {[weak self] event, eventData  in
                            guard let self = self else { return }
                            self.finished = false
                            switch event {
                            case .call:
                                if #available(iOSApplicationExtension 14.5, *) {
                                    notificationData["callId"] = eventData.callId
                                    notificationData["accountId"] = eventData.accountId
                                    notificationData["jamiId"] = eventData.jamiId
                                    self.bestAttemptContent?.title = "Incoming call"
                                    CXProvider.reportNewIncomingVoIPPushPayload(notificationData, completion: nil)
                                }
                            case .message:
                                self.bestAttemptContent?.title = "Incoming message"
                                self.bestAttemptContent?.subtitle = eventData.jamiId
                                self.bestAttemptContent?.body = eventData.content
                            case .fileTransfer:
                                self.bestAttemptContent?.title = "Incoming file transfer"
                            }
                            self.group.leave()
                            if let bestAttemptContent = self.bestAttemptContent, let handler = self.contentHandler {
                                handler(bestAttemptContent)
                            }
                           })
        self.adapterService.startDaemon()
        self.adapterService.pushNotificationReceived(from: "", message: notificationData)
        _ = group.wait(timeout: .now() + 10)
        if finished, let handler = self.contentHandler {
            handler(UNNotificationContent())
        }
    }

    func callback(_ name: String) {
        guard !notificationProceed else { return }
        if let callback = self.callback {
            notificationProceed = true
            callback(true)
        }
    }

    func checkIfAppActive(callback: @escaping (_ active: Bool) -> Void) {
        self.callback = callback
        DispatchQueue.main.async {
            guard !self.notificationProceed else {
                callback(true)
                return }
            let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CFNotificationCenterAddObserver(self.center,
                                            observer, { (_, observer, _, _, _) in
                                                if let observer = observer {
                                                    let mySelf = Unmanaged<NotificationService>.fromOpaque(observer).takeUnretainedValue()
                                                    // Call instance method:
                                                    mySelf.callback("")
                                                }
                                            },
                                            NotificationService.notificationToListen,
                                            nil,
                                            .deliverImmediately)
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(rawValue: NotificationService.notificationToPost), nil, nil, true)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
                guard !self.notificationProceed else { return }
                self.notificationProceed = true
                if let callback = self.callback {
                    callback(false)
                }
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler {
            contentHandler(UNNotificationContent())
        }
    }
}
