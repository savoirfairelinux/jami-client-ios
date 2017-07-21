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
import SwiftyBeaver
import RxSwift
import Chameleon

import Contacts

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    static let accountService = AccountsService(withAccountAdapter: AccountAdapter())
    static let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    static let conversationsService = ConversationsService(withMessageAdapter: MessagesAdapter())
    static let contactsService = ContactsService(withContactsAdapter: ContactsAdapter())
    static let callsService = CallsService(withCallsAdapter: CallsAdapter())

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window = UIWindow(frame: UIScreen.main.bounds)

        // initialize log format
        let console = ConsoleDestination()
        console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
        log.addDestination(console)

        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()

        Chameleon.setGlobalThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)
        Chameleon.setRingThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)

        self.loadAccounts()

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
        } catch StartDaemonError.initializationFailure {
            log.error("Daemon failed to initialize.")
        } catch StartDaemonError.startFailure {
            log.error("Daemon failed to start.")
        } catch StartDaemonError.daemonAlreadyRunning {
            log.error("Daemon already running.")
        } catch {
            log.error("Unknown error in Daemon start.")
        }
    }

    fileprivate func stopDaemon() {
        do {
            try AppDelegate.daemonService.stopDaemon()
        } catch StopDaemonError.daemonNotRunning {
            log.error("Daemon failed to stop because it was not already running.")
        } catch {
            log.error("Unknown error in Daemon stop.")
        }
    }

    fileprivate func loadAccounts() {
        AppDelegate.accountService.loadAccounts()
            .subscribe(onSuccess: { (accountList: [AccountModel]) in
                self.checkAccount(accountList: accountList)
            }, onError: { _ in
                self.presentWalkthrough()
            }).disposed(by: disposeBag)
    }

    fileprivate func checkAccount(accountList: [AccountModel]) {
        if accountList.isEmpty {
            self.presentWalkthrough()
        } else {
            AppDelegate.contactsService
                .setCurrentAccount(currentAccount: AppDelegate.accountService.currentAccount!)
            AppDelegate.contactsService
                .setAccounts(accounts: AppDelegate.accountService.accounts)

            self.presentMainTabBar()
        }
    }

    fileprivate func presentWalkthrough() {
        let storyboard = UIStoryboard(name: "WalkthroughStoryboard", bundle: nil)
        self.window?.rootViewController = storyboard.instantiateInitialViewController()
        self.window?.makeKeyAndVisible()
    }

    fileprivate func presentMainTabBar() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.window?.rootViewController = storyboard.instantiateInitialViewController()
        self.window?.makeKeyAndVisible()
    }
}
