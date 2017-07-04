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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    static let accountService = AccountsService(withAccountAdapter: AccountAdapter())
    static let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    static let conversationsService = ConversationsService(withMessageAdapter: MessagesAdapter())

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    // MARK: - Ring Daemon
    fileprivate func startDaemon() {

        do {
            try AppDelegate.daemonService.startDaemon()
            AppDelegate.accountService.loadAccounts()
        } catch StartDaemonError.initializationFailure {
            print("Daemon failed to initialize.")
        } catch StartDaemonError.startFailure {
            print("Daemon failed to start.")
        } catch StartDaemonError.daemonAlreadyRunning {
            print("Daemon already running.")
        } catch {
            print("Unknown error in Daemon start.")
        }
    }

    fileprivate func stopDaemon() {
        do {
            try AppDelegate.daemonService.stopDaemon()
        } catch StopDaemonError.daemonNotRunning {
            print("Daemon failed to stop because it was not already running.")
        } catch {
            print("Unknown error in Daemon stop.")
        }
    }
}
