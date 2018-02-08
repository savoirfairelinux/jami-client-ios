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
import SwiftyBeaver
import RxSwift
import Chameleon
import Contacts
import PushKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    private let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    private let accountService = AccountsService(withAccountAdapter: AccountAdapter())
    private let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    private let conversationsService = ConversationsService(withMessageAdapter: MessagesAdapter())
    private let contactsService = ContactsService(withContactsAdapter: ContactsAdapter())
    private let presenceService = PresenceService(withPresenceAdapter: PresenceAdapter())
     let callService = CallsService(withCallsAdapter: CallsAdapter())
    private let videoService = VideoService(withVideoAdapter: VideoAdapter())
    private let audioService = AudioService(withAudioAdapter: AudioAdapter())
    private let networkService = NetworkService()
    private var conversationManager: ConversationsManager?
    private var contactRequestManager: ContactRequestManager?
   // private let pushQueue = DispatchQueue(label: "push queue")

    var voipRegistry = PKPushRegistry(queue: DispatchQueue.main)

    public lazy var injectionBag: InjectionBag = {
        return InjectionBag(withDaemonService: self.daemonService,
                            withAccountService: self.accountService,
                            withNameService: self.nameService,
                            withConversationService: self.conversationsService,
                            withContactsService: self.contactsService,
                            withPresenceService: self.presenceService,
                            withNetworkService: self.networkService,
                            withCallService: self.callService,
                            withVideoService: self.videoService,
                            withAudioService: self.audioService)
    }()
    private lazy var appCoordinator: AppCoordinator = {
        return AppCoordinator(with: self.injectionBag)
    }()

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window = UIWindow(frame: UIScreen.main.bounds)

        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        // initialize log format
        let console = ConsoleDestination()
        console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
        log.addDestination(console)

        // starts the daemon
        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()

        // disables hardware decoding
        self.videoService.setDecodingAccelerated(withState: false)

        // requests permission to use the camera
        // will enumerate and add devices once permission has been granted
        self.videoService.setupInputs()

        // start monitoring for network changes
        self.networkService.monitorNetworkType()

        // set device to headset if present
        self.audioService.overrideAudioRoute(.override)

        // themetize the app
        Chameleon.setGlobalThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)
        Chameleon.setRingThemeUsingPrimaryColor(UIColor.ringMain, withSecondaryColor: UIColor.ringSecondary, andContentStyle: .light)

        self.contactRequestManager = ContactRequestManager(accountService: self.accountService, contactService: self.contactsService, conversationService: self.conversationsService)

        // load accounts during splashscreen
        // and ask the AppCoordinator to handle the first screen once loading is finished
        self.conversationManager = ConversationsManager(with: self.conversationsService, accountsService: self.accountService, nameService: self.nameService)
        self.startDB()
        self.accountService.loadAccounts().subscribe { [unowned self] (_) in
            guard let currentAccount = self.accountService.currentAccount else {
                self.log.error("Can't get current account!")
                return
            }
            self.contactsService.loadContacts(withAccount: currentAccount)
            self.contactsService.loadContactRequests(withAccount: currentAccount)
            self.presenceService.subscribeBuddies(withAccount: currentAccount, withContacts: self.contactsService.contacts.value)
            if let ringID = AccountModelHelper(withAccount: currentAccount).ringId {
                self.conversationManager?
                    .prepareConversationsForAccount(accountId: currentAccount.id, accountUri: ringID)
            }
            // make sure video is enabled
            let accountDetails = self.accountService.getAccountDetails(fromAccountId: currentAccount.id)
            accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.videoEnabled), withValue: "true")
            self.accountService.setAccountDetails(forAccountId: currentAccount.id, withDetails: accountDetails)
            if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
                self.voipRegistration()
            }
        }.disposed(by: self.disposeBag)

        self.window?.rootViewController = self.appCoordinator.rootViewController
        self.window?.makeKeyAndVisible()
        self.appCoordinator.start()
        self.requestNotificationAuthorization(application: application)
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    // MARK: - Ring Daemon
    fileprivate func startDaemon() {

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

    fileprivate func stopDaemon() {
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

    func voipRegistration() {
        self.voipRegistry.delegate = self
        self.voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    func voipUnregister() {
       self.voipRegistry.desiredPushTypes = nil
       self.accountService.setPushNotificationToken(token: "")
    }

    func requestNotificationAuthorization(application: UIApplication) {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = application.delegate as? UNUserNotificationCenterDelegate
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
    }

    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let data = response.notification.request.content.userInfo
        let callID = data["callID"] as! String
        switch response.actionIdentifier {
        case "ACCEPT_ACTION":
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "answerCallNotifications"), object: nil, userInfo: data)
        case "REFUSE_ACTION":
            self.callService.refuse(callId: callID)
                .subscribe({_ in
                    print("Call ignored")
                }).disposed(by: self.disposeBag)
            print("Unsubscribe Reader")
        default:
            print("Other Action")
        }

        completionHandler()
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {

        if let identifier = identifier {

            let data = notification.userInfo
            let callID = data!["callID"] as! String
            switch identifier {
            case "ACCEPT_ACTION":
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "answerCallNotifications"), object: nil, userInfo: data)
            case "REFUSE_ACTION":
                self.callService.refuse(callId: callID)
                    .subscribe({_ in
                        print("Call ignored")
                    }).disposed(by: self.disposeBag)
                print("Unsubscribe Reader")
            default:
                print("Other Action")
            }
            completionHandler()
        }
    }
}

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("pushRegistry didInvalidatePushTokenForType")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        self.accountService.pushNotificationReceived(data: payload.dictionaryPayload)
    }
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {

        if type == PKPushType.voIP {
            let deviceTokenString = pushCredentials.token.reduce("", {$0 + String(format: "%02x", $1)})
            if let account = self.accountService.currentAccount {
                let accountDetails = self.accountService.getAccountDetails(fromAccountId: account.id)
                accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken), withValue: deviceTokenString)
                self.accountService.setAccountDetails(forAccountId: account.id, withDetails: accountDetails)
            }
            self.accountService.setPushNotificationToken(token: deviceTokenString)
            print("voip token", deviceTokenString)
        }
    }
}
