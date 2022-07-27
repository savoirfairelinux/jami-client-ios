/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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
import Foundation
import RxSwift

enum NotificationCallTitle: String {
    case incomingCall = "Incoming Call"
    case missedCall = "Missed Call"
    func getString() -> String {
        switch self {
        case .incomingCall:
            return L10n.Notifications.incomingCall
        case .missedCall:
            return L10n.Notifications.missedCall
        }
    }
}

// L10n.Calls.connecting

enum CallAcition: String {
    case accept = "ACCEPT_ACTION"
    case refuse = "REFUSE_ACTION"

    func title() -> String {
        switch self {
        case .accept:
            return L10n.Notifications.acceptCall
        case .refuse:
            return L10n.Notifications.refuseCall
        }
    }
}

let enbleNotificationsKey = "EnableUserNotifications"

class LocalNotificationsHelper {
    let disposeBag = DisposeBag()
    let callCategory = "CALL_CATEGORY"
    var timer: Timer?

    init() {
        self.createCallCategory()
    }

    func presentMessageNotification(data: [String: String]) {
        guard let title = data [Constants.NotificationUserInfoKeys.name.rawValue],
              let body = data [Constants.NotificationUserInfoKeys.messageContent.rawValue] else {
                return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = data
        content.sound = UNNotificationSound.default
        content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber
        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let identifier = Int64(arc4random_uniform(10000000))
        let notificationRequest = UNNotificationRequest(identifier: "\(identifier)", content: content, trigger: notificationTrigger)
        UNUserNotificationCenter.current().add(notificationRequest) { (error) in
            if let error = error {
                print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
            }
        }
    }

    func createCallCategory() {
        let acceptAction = UNNotificationAction(identifier: CallAcition.accept.rawValue,
                                                title: CallAcition.accept.title(),
                                                options: [.foreground])
        let refuseAction = UNNotificationAction(identifier: CallAcition.refuse.rawValue,
                                                title: CallAcition.refuse.title(),
                                                options: [])

        let callCategory = UNNotificationCategory(identifier: self.callCategory,
                                                  actions: [acceptAction, refuseAction],
                                                  intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([callCategory])
    }

    @objc
    func cancelCall(timer: Timer) {
        guard let info = timer.userInfo as? [String: String],
              let callID = info[Constants.NotificationUserInfoKeys.callID.rawValue] else {
                self.timer?.invalidate()
                self.timer = nil
                return
        }
        var data = [String: String]()
        data[Constants.NotificationUserInfoKeys.callID.rawValue] = callID
        NotificationCenter.default.post(name: NSNotification.Name(NotificationName.refuseCallFromNotifications.rawValue), object: nil, userInfo: data)
        self.timer?.invalidate()
        self.timer = nil
    }

    class func isEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: enbleNotificationsKey)
    }

    class func setNotification (enable: Bool) {
        UserDefaults.standard.setValue(enable, forKey: enbleNotificationsKey)
    }
}
