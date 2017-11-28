/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
    private let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    private let accountService = AccountsService(withAccountAdapter: AccountAdapter())
    private let newAccountsService = NewAccountsService(withAccountAdapter: AccountAdapter())
    private let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    private let conversationsService = ConversationsService(withMessageAdapter: MessagesAdapter())
    private let contactsService = ContactsService(withContactsAdapter: ContactsAdapter())
    private let presenceService = PresenceService(withPresenceAdapter: PresenceAdapter())
    private let networkService = NetworkService()

    public lazy var injectionBag: InjectionBag = {
        return InjectionBag(withDaemonService: self.daemonService,
                            withAccountService: self.accountService,
                            withNewAccountsService: self.newAccountsService,
                            withNameService: self.nameService,
                            withConversationService: self.conversationsService,
                            withContactsService: self.contactsService,
                            withPresenceService: self.presenceService,
                            withNetworkService: self.networkService,
                            withContactRequestsManager: self.contactRequestsManager
                            )
    }()

    private lazy var appCoordinator: AppCoordinator = {
        return AppCoordinator(with: self.injectionBag)
    }()

    private lazy var contactRequestsManager: ContactRequestsManager = {
        return ContactRequestsManager(with: self.newAccountsService,
                                      contactsService: self.contactsService,
                                      conversationsService: self.conversationsService,
                                      presenceService: self.presenceService)
    }()

    private let log = SwiftyBeaver.self

    private let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window = UIWindow(frame: UIScreen.main.bounds)

        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")

        // initialize log format
        let console = ConsoleDestination()
        console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
        log.addDestination(console)

        // starts the daemon
        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()

        self.networkService.monitorNetworkType()

        // themetize the app
        Chameleon.setGlobalThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)
        Chameleon.setRingThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)

        // load accounts during splashscreen
        // and ask the AppCoordinator to handle the first screen once loading is finished
        self.accountService.loadAccounts().subscribe { [unowned self] (_) in
            if let currentAccount = self.accountService.currentAccount {
                self.contactsService.loadContacts(withAccount: currentAccount)
                self.contactsService.loadContactRequests(withAccount: currentAccount)
                self.presenceService.subscribeBuddies(withAccount: currentAccount, withContacts: self.contactsService.contacts.value)
            }
        }.disposed(by: self.disposeBag)

        self.window?.rootViewController = self.appCoordinator.rootViewController
        self.window?.makeKeyAndVisible()
        self.appCoordinator.start()
        self.startDB()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    // MARK: - Ring Daemon
    private func startDaemon() {
        do {
            try self.daemonService.startDaemon()
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

    private func stopDaemon() {
        do {
            try self.daemonService.stopDaemon()
        } catch StopDaemonError.daemonNotRunning {
            log.error("Daemon failed to stop because it was not already running.")
        } catch {
            log.error("Unknown error in Daemon stop.")
        }
    }

    private func startDB() {
        do {
            let dbManager = DBManager(profileHepler: ProfileDataHelper(),
                                       conversationHelper: ConversationDataHelper(),
                                       interactionHepler: InteractionDataHelper())
            try dbManager.start()
        } catch {
            let time = DispatchTime.now() + 1
            DispatchQueue.main.asyncAfter(deadline: time) {
                self.appCoordinator.showDatabaseError()
            }
        }
    }
}
