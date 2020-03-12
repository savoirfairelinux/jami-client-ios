/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import PushKit
import ContactsUI

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
    private let callsProvider: CallsProviderDelegate = CallsProviderDelegate()
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
    private lazy var locationSharingService: LocationSharingService = {
        LocationSharingService(dbManager: self.dBManager)
    }()

    private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)

    lazy var injectionBag: InjectionBag = {
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
                            withProfileService: self.profileService,
                            withCallsProvider: self.callsProvider,
                            withLocationSharingService: self.locationSharingService)
    }()
    private lazy var appCoordinator: AppCoordinator = {
        return AppCoordinator(with: self.injectionBag)
    }()

    private let log = SwiftyBeaver.self

    private let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // ignore sigpipe
        // swiftlint:disable nesting
        typealias SigHandler = @convention(c) (Int32) -> Void
        let SIG_IGN = unsafeBitCast(OpaquePointer(bitPattern: 1), to: SigHandler.self)
        signal(SIGPIPE, SIG_IGN)
        // swiftlint:enable nesting

        self.window = UIWindow(frame: UIScreen.main.bounds)

        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        UNUserNotificationCenter.current().delegate = self
        // initialize log format
        let console = ConsoleDestination()
        console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
    #if DEBUG
        log.addDestination(console)
    #else
        log.removeAllDestinations()
    #endif

        // starts the daemon
        SystemAdapter().registerConfigurationHandler()
        self.startDaemon()

        // requests permission to use the camera
        // will enumerate and add devices once permission has been granted
        self.videoService.setupInputs()

        self.audioService.connectAudioSignal()

        // start monitoring for network changes
        self.networkService.monitorNetworkType()

        // Observe connectivity changes and reconnect DHT
        self.networkService.connectionStateObservable
            .subscribe(onNext: { _ in
                self.daemonService.connectivityChanged()
            })
            .disposed(by: self.disposeBag)

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
                                                        callService: self.callService,
                                                        locationSharingService: self.locationSharingService)
        self.window?.rootViewController = self.appCoordinator.rootViewController
        self.window?.makeKeyAndVisible()

        prepareVideoAcceleration()
        prepareAccounts()
        self.voipRegistry.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(registerVoipNotifications),
                                               name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
                                               object: nil)
        self.clearBadgeNumber()
        return true
    }

    func prepareAccounts() {
        self.accountService
            .needMigrateCurrentAccount
            .subscribe(onNext: { account in
                DispatchQueue.main.async {
                    self.appCoordinator.migrateAccount(accountId: account)
                }
            })
            .disposed(by: self.disposeBag)
        self.accountService.initialAccountsLoading()
            .subscribe(onCompleted: {
                //set selected account if exists
                self.appCoordinator.start()
                if self.accountService.hasAccountWithProxyEnabled() {
                    self.registerVoipNotifications()
                } else {
                    self.unregisterVoipNotifications()
                }
                if let selectedAccountId = UserDefaults.standard.string(forKey: self.accountService.selectedAccountID),
                    let account = self.accountService.getAccount(fromAccountId: selectedAccountId) {
                    self.accountService.currentAccount = account
                }
                guard let currentAccount = self.accountService.currentAccount else {
                    self.log.error("Can't get current account!")
                    //if we don't have any account means it is first run, so enable hardware acceleration
                    self.videoService.setHardwareAccelerated(withState: true)
                    UserDefaults.standard.set(true, forKey: hardareAccelerationKey)
                    return
                }
                self.reloadDataFor(account: currentAccount)
            }, onError: { _ in
                self.appCoordinator.showInitialLoading()
                let time = DispatchTime.now() + 1
                DispatchQueue.main.asyncAfter(deadline: time) {
                    self.appCoordinator.showDatabaseError()
                }
            })
            .disposed(by: self.disposeBag)

        self.accountService.currentWillChange
            .subscribe(onNext: { account in
                guard let currentAccount = account else { return }
                self.presenceService.subscribeBuddies(withAccount: currentAccount.id, withContacts: self.contactsService.contacts.value, subscribe: false)
            })
            .disposed(by: self.disposeBag)

        self.accountService.currentAccountChanged
            .subscribe(onNext: { account in
                guard let currentAccount = account else { return }
                self.reloadDataFor(account: currentAccount)
            })
            .disposed(by: self.disposeBag)
    }

    func reloadDataFor(account: AccountModel) {
        self.contactsService.loadContacts(withAccount: account)
        self.contactsService.loadContactRequests(withAccount: account.id)
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: true)
        self.conversationManager?
                .prepareConversationsForAccount(accountId: account.id)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.log.warning("entering background")
        self.callService.muteCurrentCallVideoVideo( mute: true)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        self.log.warning("entering foreground")
        self.daemonService.connectivityChanged()
        self.updateNotificationAvailability()
        self.callService.muteCurrentCallVideoVideo( mute: false)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.clearBadgeNumber()
    }

    func prepareVideoAcceleration() {
        // we want enable hardware acceleration by default so if key does not exists,
        // means it was not disabled by user
        let keyExists = UserDefaults.standard.object(forKey: hardareAccelerationKey) != nil
        let enable = keyExists ? UserDefaults.standard.bool(forKey: hardareAccelerationKey) : true
        self.videoService.setHardwareAccelerated(withState: enable)
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

    func updateNotificationAvailability() {
        let enabled = LocalNotificationsHelper.isEnabled()
        let currentSettings = UNUserNotificationCenter.current()
        currentSettings.getNotificationSettings(completionHandler: { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                break
            case .denied:
                if enabled { LocalNotificationsHelper.setNotification(enable: false) }
            case .authorized:
                if !enabled { LocalNotificationsHelper.setNotification(enable: true) }
            case .provisional:
                if !enabled { LocalNotificationsHelper.setNotification(enable: true) }
            @unknown default:
                break
            }
        })
    }

    @objc
    private func registerVoipNotifications() {
        self.requestNotificationAuthorization()
        self.voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    private func unregisterVoipNotifications() {
        self.voipRegistry.desiredPushTypes = nil
        self.accountService.setPushNotificationToken(token: "")
    }

    private func requestNotificationAuthorization() {
        let application = UIApplication.shared
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
    }

    private func clearBadgeNumber() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let data = response.notification.request.content.userInfo
        self.handleNotificationActions(data: data, responseIdentifier: response.actionIdentifier)
        completionHandler()
    }

    func handleNotificationActions(data: [AnyHashable: Any], responseIdentifier: String) {
        guard let currentAccount = self.accountService
            .currentAccount,
            let accountId = data[NotificationUserInfoKeys.accountID.rawValue] as? String,
            let account = self.accountService.getAccount(fromAccountId: accountId) else { return }
        if currentAccount.id != accountId && responseIdentifier != CallAcition.refuse.rawValue {
            self.accountService.currentAccount = account
        }
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
                })
                .disposed(by: self.disposeBag)
        default:
            // automatically answer call when user tap the notifications
            NotificationCenter.default.post(name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue),
                                            object: nil,
                                            userInfo: data)
        }
    }

    func findContactAndStartCall(hash: String, isVideo: Bool) {
        //if saved jami hash
        if hash.isSHA1() {
            let contactUri = JamiURI(schema: URIType.ring, infoHach: hash)
            self.findAccountAndStartCall(uri: contactUri, isVideo: isVideo, type: AccountType.ring)
            return
        }
        //if saved jami registered name
        self.nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .filter({ usernameLookupStatus in
                usernameLookupStatus.name == hash
            })
            .take(1)
            .subscribe(onNext: { usernameLookupStatus in
                if usernameLookupStatus.state == .found {
                    guard let address = usernameLookupStatus.address else { return }
                    let contactUri = JamiURI(schema: URIType.ring, infoHach: address)
                    self.findAccountAndStartCall(uri: contactUri, isVideo: isVideo, type: AccountType.ring)
                } else {
                    //if saved sip contact
                    let contactUri = JamiURI(schema: URIType.sip, infoHach: hash)
                    self.findAccountAndStartCall(uri: contactUri, isVideo: isVideo, type: AccountType.sip)
                }
            })
            .disposed(by: self.disposeBag)
        self.nameService.lookupName(withAccount: "", nameserver: "", name: hash)
    }

    func findAccountAndStartCall(uri: JamiURI, isVideo: Bool, type: AccountType) {
        guard let currentAccount = self.accountService
            .currentAccount else { return }
        var hash = uri.hash ?? ""
        var uriString = uri.uriString ?? ""
        for account in self.accountService.accounts where account.type == type {
            if type == AccountType.sip {
                let conatactUri = JamiURI(schema: URIType.sip,
                                          infoHach: hash,
                                          account: account)
                hash = conatactUri.hash ?? ""
                uriString = conatactUri.uriString ?? ""
            }
            if hash.isEmpty || uriString.isEmpty { return }
            self.contactsService
                .getProfileForUri(uri: uriString,
                                  accountId: account.id)
                .subscribe(onNext: { (profile) in
                    if currentAccount != account {
                        self.accountService.currentAccount = account
                    }
                    self.appCoordinator
                        .startCall(participant: hash,
                                   name: profile.alias ?? "",
                                   isVideo: isVideo)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if self.accountService.boothMode() {
            return false
        }
        guard let handle = userActivity.startCallHandle else {
            return false
        }
        self.findContactAndStartCall(hash: handle.hash, isVideo: handle.isVideo)
        return true
    }
}

extension AppDelegate: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        self.accountService.setPushNotificationToken(token: "")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        self.accountService.pushNotificationReceived(data: payload.dictionaryPayload)
    }

    @available(iOS 11.0, *)
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        self.accountService.pushNotificationReceived(data: payload.dictionaryPayload)
        completion()
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == PKPushType.voIP {
            let deviceTokenString = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
            self.accountService.setPushNotificationToken(token: deviceTokenString)
        }
    }
}
