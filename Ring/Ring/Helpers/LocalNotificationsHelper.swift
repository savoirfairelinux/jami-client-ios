import Foundation
import RxSwift

class LocalNotificationsHelper {
     let callNotificationsIdentifier = "call_notifications_identifier"

     func presentMessageNotification(data: [String: String]) {

        let title = data ["title"]
        let body = data ["body"]

        if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            print("Create notification with message:", content)
            content.title = title!
            content.body = body!
            content.badge = UIApplication.shared.applicationIconBadgeNumber + 1 as NSNumber
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
            let identifier = Int64(arc4random_uniform(10000000))
            let notificationRequest = UNNotificationRequest(identifier: "\(identifier)", content: content, trigger: notificationTrigger)
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                }
            }
        } else {
            let notification = UILocalNotification()
            notification.alertTitle = title!
            notification.alertBody = body!
            notification.applicationIconBadgeNumber = UIApplication.shared.applicationIconBadgeNumber + 1
            UIApplication.shared.scheduleLocalNotification(notification)
        }
    }

     func createCallNotifications() {

    }

     func presentCallNotification(data: [String: String]) {

        let title = "Incomming call"
        let body = data ["body"] as! String

        let delegate = UIApplication.shared.delegate as! AppDelegate
        let callService = delegate.callService

        if #available(iOS 10.0, *) {
            let acceptAction = UNNotificationAction(identifier: "ACCEPT_ACTION", title: "ACCEPT", options: [.foreground])
            let refuseAction = UNNotificationAction(identifier: "REFUSE_ACTION", title: "REFUSE", options: [])

            let callCategory = UNNotificationCategory(identifier: "CALL_CATEGORY", actions: [acceptAction, refuseAction], intentIdentifiers: [], options: [])
            UNUserNotificationCenter.current().setNotificationCategories([callCategory])
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.userInfo = data
            content.categoryIdentifier = "CALL_CATEGORY"
            content.sound = UNNotificationSound.default()
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
            let notificationRequest = UNNotificationRequest(identifier: callNotificationsIdentifier, content: content, trigger: notificationTrigger)
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                }
            }
            let callID = data["callID"]
            callService.currentCall.filter({ call in
                return call.callId == callID && (call.state == .over || call.state == .failure)
            }).subscribe(onNext: { (call) in
                let content = UNMutableNotificationContent()
                content.title = "MissedCall"
                content.body = body
                let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
                let notificationRequest = UNNotificationRequest(identifier: self.callNotificationsIdentifier, content: content, trigger: notificationTrigger)
                UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                    if let error = error {
                        print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                    }
                }

            })

        } else {
            let notificationTypes: UIUserNotificationType = (UIApplication.shared.currentUserNotificationSettings?.types)!
            // accept action
            let acceptAction = UIMutableUserNotificationAction()
            acceptAction.identifier = "ACCEPT_ACTION"
            acceptAction.title = "ACCEPT"
            acceptAction.activationMode = UIUserNotificationActivationMode.foreground

            // refuse Action
            let refuseAction = UIMutableUserNotificationAction()
            refuseAction.identifier = "REFUSE_ACTION"
            refuseAction.title = "REFUSE"
            refuseAction.activationMode = UIUserNotificationActivationMode.background

            // Category
            let callCategory = UIMutableUserNotificationCategory()
            callCategory.identifier = "CALL_CATEGORY"

            // A. Set actions for the default context
            callCategory.setActions([acceptAction, refuseAction],
                                    for: UIUserNotificationActionContext.default)

            // B. Set actions for the minimal context
            callCategory.setActions([acceptAction, refuseAction],
                                    for: UIUserNotificationActionContext.minimal)

            let categoriesForSettings: Set<UIUserNotificationCategory> = NSSet(objects: callCategory) as! Set<UIUserNotificationCategory>
            let newNotificationSettings = UIUserNotificationSettings(types: notificationTypes, categories: categoriesForSettings)
            UIApplication.shared.registerUserNotificationSettings(newNotificationSettings)
            let notification = UILocalNotification()
            notification.userInfo = data
            notification.alertTitle = title
            notification.alertBody = body
            UIApplication.shared.scheduleLocalNotification(notification)
            notification.category = "CALL_CATEGORY"
            notification.applicationIconBadgeNumber = UIApplication.shared.applicationIconBadgeNumber + 1
            UIApplication.shared.scheduleLocalNotification(notification)

            let callID = data["callID"]
            callService.currentCall.filter({ call in
                return call.callId == callID && (call.state == .over || call.state == .failure)
            }).subscribe(onNext: { (call) in
                let notification = UILocalNotification()
                notification.userInfo = data
                notification.alertTitle = "Missed Call"
                notification.alertBody = body
                UIApplication.shared.scheduleLocalNotification(notification)
            })

        }
    }
}
