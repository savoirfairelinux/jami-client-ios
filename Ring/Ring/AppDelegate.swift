/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

// swiftlint:disable identifier_name

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    let dBManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper(),
                              dbConnections: DBContainer())
    private let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
    private let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
    private let presenceService = PresenceService(withPresenceAdapter: PresenceAdapter())
    private let videoService = VideoService(withVideoAdapter: VideoAdapter())
    private let audioService = AudioService(withAudioAdapter: AudioAdapter())
    private let networkService = NetworkService()
    private var conversationManager: ConversationsManager?
    private var interactionsManager: GeneratedInteractionsManager?
    private lazy var callService: CallsService = {
        CallsService(withCallsAdapter: CallsAdapter(), dbManager: self.dBManager)
    }()
    private lazy var accountService: AccountsService = {
        AccountsService(withAccountAdapter: AccountAdapter(), dbManager: self.dBManager)
    }()
    private lazy var contactsService: ContactsService = {
        ContactsService(withContactsAdapter: ContactsAdapter(), dbManager: self.dBManager)
    }()
    private lazy var profileService: ProfilesService = {
        ProfilesService(dbManager: self.dBManager)
    }()
    private lazy var dataTransferService: DataTransferService = {
        DataTransferService(withDataTransferAdapter: DataTransferAdapter(),
                            dbManager: self.dBManager)
    }()
    private lazy var conversationsService: ConversationsService = {
        ConversationsService(withMessageAdapter: MessagesAdapter(), dbManager: self.dBManager)
    }()

    private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)

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
                            withAudioService: self.audioService,
                            withDataTransferService: self.dataTransferService,
                            withProfileService: self.profileService)
    }()
    private lazy var appCoordinator: AppCoordinator = {
        return AppCoordinator(with: self.injectionBag)
    }()

    private let log = SwiftyBeaver.self

    fileprivate let disposeBag = DisposeBag()

    // swiftlint:disable function_body_length
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // ignore sigpipe
        // swiftlint:disable nesting
        typealias SigHandler = @convention(c) (Int32) -> Void
        let SIG_IGN = unsafeBitCast(OpaquePointer(bitPattern: 1), to: SigHandler.self)
        signal(SIGPIPE, SIG_IGN)
        // swiftlint:enable nesting

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

        // sets output device to whatever is currently available (either spk / headset)
        self.audioService.startAVAudioSession()

        // disables hardware decoding
        self.videoService.setDecodingAccelerated(withState: false)

        // requests permission to use the camera
        // will enumerate and add devices once permission has been granted
        self.videoService.setupInputs()

        // start monitoring for network changes
        self.networkService.monitorNetworkType()

        // Observe connectivity changes and reconnect DHT
        self.networkService.connectionStateObservable
            .subscribe(onNext: { _ in
                self.daemonService.connectivityChanged()
            })
            .disposed(by: self.disposeBag)

        // themetize the app
        Chameleon.setRingThemeUsingPrimaryColor(UIColor.jamiMain, withSecondaryColor: UIColor.jamiSecondary, andContentStyle: .light)

        self.interactionsManager = GeneratedInteractionsManager(accountService: self.accountService,
                                                                contactService: self.contactsService,
                                                                conversationService: self.conversationsService,
                                                                callService: self.callService)

        // load accounts during splashscreen
        // and ask the AppCoordinator to handle the first screen once loading is finished
        self.conversationManager = ConversationsManager(with: self.conversationsService,
                                                        accountsService: self.accountService,
                                                        nameService: self.nameService,
                                                        dataTransferService: self.dataTransferService,
                                                        callService: self.callService)

        self.accountService
            .sharedResponseStream
            .filter({ (event) in
                return event.eventType == ServiceEventType.registrationStateChanged &&
                    event.getEventInput(ServiceEventInput.registrationState) == Registered
            })
            .subscribe(onNext: { [unowned self] _ in
                if let currentAccount = self.accountService.currentAccount, !currentAccount.onBoarded {
                    currentAccount.onBoarded = true
                    // make sure video is enabled
                    let accountDetails = self.accountService.getAccountDetails(fromAccountId: currentAccount.id)
                    accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.videoEnabled), withValue: "true")

                    // set ringtone path
                    DispatchQueue.main.async { [unowned self] in
                        self.accountService.setRingtonePath(forAccountId: currentAccount.id)
                    }

                    // check if push notifications are enabled in the config
                    let notificationsEnabled = accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken)).isEmpty ? false : true
                    if notificationsEnabled {
                        self.registerVoipNotifications()
                    }
                    //in case if application was open when incoming call launched the push notifications
                    // reimit new call signal to show incoming call alert
                    self.callService.checkForIncomingCall()
                }
            })
            .disposed(by: disposeBag)

        self.window?.rootViewController = self.appCoordinator.rootViewController
        self.window?.makeKeyAndVisible()

        self.accountService.initialAccountsLoading().subscribe(onCompleted: {
            self.appCoordinator.start()
            guard let currentAccount = self.accountService.currentAccount else {
                self.log.error("Can't get current account!")
                return
            }
            self.contactsService.loadContacts(withAccount: currentAccount)
            self.contactsService.loadContactRequests(withAccount: currentAccount)
            self.presenceService.subscribeBuddies(withAccount: currentAccount,
                                                  withContacts: self.contactsService.contacts.value)
            if let ringID = AccountModelHelper(withAccount: currentAccount).ringId {
                self.conversationManager?
                    .prepareConversationsForAccount(accountId: currentAccount.id, accountUri: ringID)
            }
        }, onError: { _ in
            self.appCoordinator.start()
            let time = DispatchTime.now() + 1
            DispatchQueue.main.asyncAfter(deadline: time) {
                self.appCoordinator.showDatabaseError()
            }
        }).disposed(by: self.disposeBag)
        self.voipRegistry.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(registerVoipNotifications),
                                               name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(unregisterVoipNotifications),
                                               name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue),
                                               object: nil)
        self.clearBadgeNumber()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.log.warning("entering background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        self.log.warning("entering foreground")
        self.daemonService.connectivityChanged()
        self.updateNotificationAvailability()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.callService.checkForIncomingCall()
        self.clearBadgeNumber()
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

    // swiftlint:disable cyclomatic_complexity
    func updateNotificationAvailability() {
        let enabled = LocalNotificationsHelper.isEnabled()
        if #available(iOS 10.0, *) {
            let currentSettings = UNUserNotificationCenter.current()
            currentSettings.getNotificationSettings(completionHandler: { settings in
                switch settings.authorizationStatus {
                case .notDetermined:
                    break
                case .denied:
                    if enabled { LocalNotificationsHelper.setNotification(enable: false) }
                case .authorized:
                    if !enabled { LocalNotificationsHelper.setNotification(enable: true)}
                case .provisional:
                    if !enabled { LocalNotificationsHelper.setNotification(enable: true)}
                }
            })
        } else {
            if UIApplication.shared.isRegisteredForRemoteNotifications {
                if !enabled {LocalNotificationsHelper.setNotification(enable: true)}
            } else {
                if enabled {LocalNotificationsHelper.setNotification(enable: false)}
            }
        }
    }

    @objc private func registerVoipNotifications() {
        self.requestNotificationAuthorization()
        self.voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    @objc private func unregisterVoipNotifications() {
       self.voipRegistry.desiredPushTypes = nil
        self.accountService.setPushNotificationToken(token: "")
        self.accountService.updatePushTokenForCurrentAccount(token: "")
    }

    private func requestNotificationAuthorization() {
        let application = UIApplication.shared
        if #available(iOS 10.0, *) {
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().delegate = application.delegate as? UNUserNotificationCenterDelegate
                let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                UNUserNotificationCenter.current().requestAuthorization(options: authOptions, completionHandler: { (enable, _) in
                    if enable {
                        LocalNotificationsHelper.setNotification(enable: true)
                    } else {
                        LocalNotificationsHelper.setNotification(enable: false)
                    }
                })
            }
        } else {
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
    }

    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        let enabled = notificationSettings.types.contains(.alert)
        if enabled {
            LocalNotificationsHelper.setNotification(enable: true)
        } else {
            LocalNotificationsHelper.setNotification(enable: false)
        }
    }

    private func clearBadgeNumber() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
        } else {
            UIApplication.shared.cancelAllLocalNotifications()
        }
    }

    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let data = response.notification.request.content.userInfo
        self.handleNotificationActions(data: data, responseIdentifier: response.actionIdentifier)
        completionHandler()
    }

    func handleNotificationActions(data: [AnyHashable: Any], responseIdentifier: String) {
        // if notification contains messageContent this is message notification
        if let participantID = data[NotificationUserInfoKeys.participantID.rawValue] as? String {
            self.appCoordinator.openConversation(participantID: participantID)
            return
        }
        guard let callID = data[NotificationUserInfoKeys.callID.rawValue] as? String else {
            return
        }
        switch responseIdentifier {
        case CallAcition.accept.rawValue:
            NotificationCenter.default.post(name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue),
                                            object: nil,
                                            userInfo: data)
        case CallAcition.refuse.rawValue:
            self.callService.refuse(callId: callID)
                .subscribe({_ in
                    print("Call ignored")
                }).disposed(by: self.disposeBag)
        default:
            // automatically answer call when user tap the notifications
            NotificationCenter.default.post(name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue),
                                            object: nil,
                                            userInfo: data)
        }
    }

    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
        if let identifier = identifier, let data = notification.userInfo {
            self.handleNotificationActions(data: data, responseIdentifier: identifier)
        }
        completionHandler()
    }

    // handle notifications click before iOS 10.0
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        guard let info = notification.userInfo else {return}
        if (info[NotificationUserInfoKeys.callID.rawValue] as? String) != nil {
             handleNotificationActions(data: info, responseIdentifier: CallAcition.accept.rawValue)
        } else if (info[NotificationUserInfoKeys.messageContent.rawValue] as? String) != nil {
            handleNotificationActions(data: info, responseIdentifier: "messageReceived")
        }
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let rootViewController = self.topViewControllerWithRootViewController(rootViewController: window?.rootViewController) {
            if rootViewController.responds(to: #selector(CallViewController.canRotate)) {
                return .all
            }
        }
        return .portrait
    }

    private func topViewControllerWithRootViewController(rootViewController: UIViewController!) -> UIViewController? {
        if rootViewController == nil {
            return nil
        }
        if rootViewController.isKind(of: (UITabBarController).self) {
            return topViewControllerWithRootViewController(rootViewController: (rootViewController as? UITabBarController)?.selectedViewController)
        } else if rootViewController.isKind(of: (UINavigationController).self) {
            return topViewControllerWithRootViewController(rootViewController: (rootViewController as? UINavigationController)?.visibleViewController)
        } else if rootViewController.presentedViewController != nil {
            return topViewControllerWithRootViewController(rootViewController: rootViewController.presentedViewController)
        }
        return rootViewController
    }
}

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        self.accountService.setPushNotificationToken(token: "")
        self.accountService.updatePushTokenForCurrentAccount(token: "")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        self.accountService.pushNotificationReceived(data: payload.dictionaryPayload)
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == PKPushType.voIP {
            let deviceTokenString = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
            self.accountService.updatePushTokenForCurrentAccount(token: deviceTokenString)
            self.accountService.setPushNotificationToken(token: deviceTokenString)
        }
    }
}
