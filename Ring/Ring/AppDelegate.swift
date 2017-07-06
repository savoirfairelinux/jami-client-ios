/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import UIKit
import RealmSwift
import Contacts

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    static let accountService = AccountsService(withAccountAdapter: AccountAdapter())
    static let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    static let conversationsService = ConversationsService(withMessageAdapter: MessagesAdapter())
    let contactsService = ContactsService(withContactsAdapter: ContactsAdapter())

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()

//        let contact = ContactModel(withRingId: "31c422cca4db649bedb9896bc39ab8c05f3f4a11")
//        let vCard = CNMutableContact()
//        vCard.setValue("Gainsbourg", forKey: CNContactFamilyNameKey)
//        vCard.setValue("Serge", forKey: CNContactGivenNameKey)
//        let image = UIImage(named: "logo-ring-beta2-blanc")
//        let imageData = UIImagePNGRepresentation(image!)
//        vCard.setValue(imageData, forKey: CNContactImageDataKey)
//        contactsService.sendTrustRequest(toContact: contact , vCard: vCard, withAccount: AppDelegate.accountService.currentAccount!)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    // MARK: - Ring Daemon
    fileprivate func startDaemon() {

        do {
            try AppDelegate.daemonService.startDaemon()
            AppDelegate.accountService.loadAccounts()
        } catch StartDaemonError.InitializationFailure {
            print("Daemon failed to initialize.")
        } catch StartDaemonError.StartFailure {
            print("Daemon failed to start.")
        } catch StartDaemonError.DaemonAlreadyRunning {
            print("Daemon already running.")
        } catch {
            print("Unknown error in Daemon start.")
        }
    }

    fileprivate func stopDaemon() {
        do {
            try AppDelegate.daemonService.stopDaemon()
        } catch StopDaemonError.DaemonNotRunning {
            print("Daemon failed to stop because it was not already running.")
        } catch {
            print("Unknown error in Daemon stop.")
        }
    }
}

