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

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    private var adapterService: AdapterService!

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
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
        print(("Received notification in class: \(self), thread: \(Thread.current), pid: \(ProcessInfo.processInfo.processIdentifier)"))
        self.adapterService =
            AdapterService(withAdapter: Adapter(),
                           withEventHandler: {[weak self] event, eventData  in
                            guard let self = self else { return }
                            switch event {
                            case .call:
                                if #available(iOSApplicationExtension 14.5, *) {
                                    notificationData["callId"] = eventData.callId
                                    notificationData["accountId"] = eventData.accountId
                                    notificationData["jamiId"] = eventData.jamiId
                                    CXProvider.reportNewIncomingVoIPPushPayload(notificationData, completion: nil)
                                }
                                contentHandler(UNNotificationContent())
                            case .message:
                                self.bestAttemptContent?.title = "Incoming message"
                                self.bestAttemptContent?.subtitle = eventData.jamiId
                                self.bestAttemptContent?.body = eventData.content
                            case .fileTransfer:
                                self.bestAttemptContent?.title = "Incoming file transfer"
                            }
                            if let bestAttemptContent = self.bestAttemptContent {
                                contentHandler(bestAttemptContent)
                            }
                           })
        self.adapterService.startDaemon()
        self.adapterService.pushNotificationReceived(from: "", message: notificationData)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler {
            contentHandler(UNNotificationContent())
        }
    }
}
