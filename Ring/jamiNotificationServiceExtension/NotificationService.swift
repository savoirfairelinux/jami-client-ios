//
//  NotificationService.swift
//  jamiNotificationServiceExtension
//
//  Created by kateryna on 2021-06-08.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import UserNotifications
import CallKit

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    private var adapterService: AdapterService!

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        // configure data
        var notificationData = [String: String]()
        let data = request.content.userInfo
        for key in data.keys {
            if let value = data[key] {
                let valueString = String(describing: value)
                let keyString = String(describing: key)
                notificationData[keyString] = valueString
            }
        }
       // let group = DispatchGroup()
        adapterService = AdapterService(withAdapter: Adapter(), withEventHandler: {event in
            switch event {
            case .call:
                if #available(iOSApplicationExtension 14.5, *) {
                    CXProvider.reportNewIncomingVoIPPushPayload(data) { _ in

                    }
                } else {
                    // Fallback on earlier versions
                }
            case .message: break

            case .fileTransfer: break

            }
        })
        adapterService.startDaemon()
        self.adapterService.pushNotificationReceived(from: "", message: notificationData)

//        if let bestAttemptContent = bestAttemptContent {
//            // Modify the notification content here...
//            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
//
//            contentHandler(bestAttemptContent)
//        }
//        group.notify(queue: .main) {
//                // all data available, continue
//        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
