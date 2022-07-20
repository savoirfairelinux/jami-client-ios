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
import os

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
    private var videoManager: VideoManager?
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
        ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: self.dBManager)
    }()
    private lazy var dataTransferService: DataTransferService = {
        DataTransferService(withDataTransferAdapter: DataTransferAdapter(),
                            dbManager: self.dBManager)
    }()
    private lazy var conversationsService: ConversationsService = {
        ConversationsService(withConversationsAdapter: ConversationsAdapter(), dbManager: self.dBManager)
    }()
    private lazy var locationSharingService: LocationSharingService = {
        LocationSharingService(dbManager: self.dBManager)
    }()
    private lazy var requestsService: RequestsService = {
        RequestsService(withRequestsAdapter: RequestsAdapter(), dbManager: self.dBManager)
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
                            withLocationSharingService: self.locationSharingService,
                            withRequestsService: self.requestsService)
    }()
    private lazy var appCoordinator: AppCoordinator = {
        return AppCoordinator(with: self.injectionBag)
    }()

    private let log = SwiftyBeaver.self

    private let disposeBag = DisposeBag()

    private let center = CFNotificationCenterGetDarwinNotifyCenter()
    private static let shouldHandleNotification = NSNotification.Name("com.savoirfairelinux.jami.shouldHandleNotification")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // ignore sigpipe
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

        /// move files from the app container to the group container, so it could be accessed by notification extension
        if !self.moveDataToGroupContainer() {
            self.window?.rootViewController = self.appCoordinator.rootViewController
            self.window?.makeKeyAndVisible()
            let alertController = UIAlertController(title: "There was an error starting Jami", message: "Please try again", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default)
            alertController.addAction(okAction)
            self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
            return true
        }

        self.addListenerForNotification()

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
                                                                requestsService: self.requestsService,
                                                                conversationService: self.conversationsService,
                                                                callService: self.callService)

        // load accounts during splashscreen
        // and ask the AppCoordinator to handle the first screen once loading is finished
        self.conversationManager = ConversationsManager(with: self.conversationsService,
                                                        accountsService: self.accountService,
                                                        nameService: self.nameService,
                                                        dataTransferService: self.dataTransferService,
                                                        callService: self.callService,
                                                        locationSharingService: self.locationSharingService, contactsService: self.contactsService,
                                                        callsProvider: self.callsProvider, requestsService: self.requestsService)
        self.videoManager = VideoManager(with: self.callService, videoService: self.videoService)
        self.window?.rootViewController = self.appCoordinator.rootViewController
        self.window?.makeKeyAndVisible()

        prepareVideoAcceleration()
        prepareAccounts()
        self.voipRegistry.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(registerNotifications),
                                               name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
                                               object: nil)
        self.clearBadgeNumber()
        if let path = self.certificatePath() {
            setenv("CA_ROOT_FILE", path, 1)
        }
        os_log("&&&&&&&didFinishLaunchingWithOptions")
        return true
    }

    func moveDataToGroupContainer() -> Bool {
        let usingGroupConatinerKey = "usingGroupConatiner"
        if UserDefaults.standard.bool(forKey: usingGroupConatinerKey) {
            return true
        }
        guard let groupDocUrl = Constants.documentsPath,
              let groupCachesUrl = Constants.cachesPath,
              let appDocURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
              let appLibrURL = try? FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return false
        }
        if FileManager.default.fileExists(atPath: groupDocUrl.path) {
            try? FileManager.default.removeItem(atPath: groupDocUrl.path)
        }
        if FileManager.default.fileExists(atPath: groupCachesUrl.path) {
            try? FileManager.default.removeItem(atPath: groupCachesUrl.path)
        }
        let appCacheDir = appLibrURL.appendingPathComponent("Caches")
        do {
            try FileManager.default.copyItem(at: appDocURL, to: groupDocUrl)
            try FileManager.default.copyItem(at: appCacheDir, to: groupCachesUrl)
        } catch {
            print(error.localizedDescription)
            try? FileManager.default.removeItem(atPath: groupDocUrl.path)
            try? FileManager.default.removeItem(atPath: groupCachesUrl.path)
            return false
        }
        if let fileURLs = try? FileManager.default.contentsOfDirectory(at: appDocURL,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: .skipsHiddenFiles) {
            for fileURL in fileURLs {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        UserDefaults.standard.setValue(true, forKey: usingGroupConatinerKey)
        return UserDefaults.standard.bool(forKey: usingGroupConatinerKey)
    }

    func addListenerForNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification),
                                               name: AppDelegate.shouldHandleNotification,
                                               object: nil)
        CFNotificationCenterAddObserver(self.center,
                                        nil, { (_, _, _, _, _) in
                                            /// emit signal so notification could be handeled by daemon
                                            NotificationCenter.default.post(name: AppDelegate.shouldHandleNotification, object: nil, userInfo: nil)
                                            /// emit signal that app is active for notification extension
                                            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(Constants.notificationAppIsActive), nil, nil, true)
                                        },
                                        Constants.notificationReceived,
                                        nil,
                                        .deliverImmediately)
    }

    func certificatePath() -> String? {
        let fileName = "cacert"
        let filExtension = "pem"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let certPath = documentsURL.appendingPathComponent(fileName).appendingPathExtension(filExtension)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: certPath.path) {
            return certPath.path
        }
        guard let certSource = Bundle.main.url(forResource: fileName, withExtension: filExtension) else {
            return nil
        }
        do {
            try fileManager.copyItem(at: certSource, to: certPath)
            return certPath.path
        } catch {
            return nil
        }
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
                // set selected account if exists
                self.appCoordinator.start()
                if !self.accountService.hasAccounts() {
                    return
                }
                if self.accountService.hasAccountWithProxyEnabled() {
                    self.registerNotifications()
                } else {
                    self.unregisterNotifications()
                }
                if let selectedAccountId = UserDefaults.standard.string(forKey: self.accountService.selectedAccountID),
                    let account = self.accountService.getAccount(fromAccountId: selectedAccountId) {
                    self.accountService.currentAccount = account
                }
                guard let currentAccount = self.accountService.currentAccount else {
                    self.log.error("Can't get current account!")
                    // if we don't have any account means it is first run, so enable hardware acceleration
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
        self.requestsService.loadRequests(withAccount: account.id, accountURI: account.jamiId)
        self.conversationManager?
            .prepareConversationsForAccount(accountId: account.id, accountURI: account.jamiId)
        self.contactsService.loadContacts(withAccount: account)
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: true)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        self.log.warning("entering background")
        self.accountService.setAccountsActive(active: false)
        self.callService.muteCurrentCallVideoVideo( mute: true)
        guard let account = self.accountService.currentAccount else { return }
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: false)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        self.log.warning("entering foreground")
        self.accountService.setAccountsActive(active: true)
        self.daemonService.connectivityChanged()
        self.updateNotificationAvailability()
        self.callService.muteCurrentCallVideoVideo( mute: false)
        guard let account = self.accountService.currentAccount else { return }
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: true)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        self.stopDaemon()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.clearBadgeNumber()
        guard let account = self.accountService.currentAccount else { return }
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: true)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        guard let account = self.accountService.currentAccount else { return }
        self.presenceService.subscribeBuddies(withAccount: account.id, withContacts: self.contactsService.contacts.value, subscribe: false)
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
        self.callsProvider.stop()
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
            case .ephemeral:
                if enabled { LocalNotificationsHelper.setNotification(enable: false) }
            @unknown default:
                break
            }
        })
    }

    @objc
    private func handleNotification() {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier),
              let notificationData = userDefaults.object(forKey: Constants.notificationData) as? [[String: String]] else {
            return
        }
        userDefaults.set([[String: String]](), forKey: Constants.notificationData)
        for data in notificationData {
            self.accountService.pushNotificationReceived(data: data)
        }
    }

    @objc
    private func registerNotifications() {
        self.requestNotificationAuthorization()
        if #available(iOS 14.5, *) {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        self.voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    private func unregisterNotifications() {
        if #available(iOS 14.5, *) {
            DispatchQueue.main.async {
                UIApplication.shared.unregisterForRemoteNotifications()
            }
        }
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
        if let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) {
            userDefaults.set(0, forKey: Constants.notificationsCount)
        }

        UIApplication.shared.applicationIconBadgeNumber = 0
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }

}

// MARK: notification actions
extension AppDelegate {

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
        // if saved jami hash
        if hash.isSHA1() {
            let contactUri = JamiURI(schema: URIType.ring, infoHach: hash)
            self.findAccountAndStartCall(uri: contactUri, isVideo: isVideo, type: AccountType.ring)
            return
        }
        // if saved jami registered name
        self.nameService.usernameLookupStatus
            .observe(on: MainScheduler.instance)
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
                    // if saved sip contact
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

// MARK: user notifications (ios 14.5 +)
extension AppDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken
                        deviceToken: Data) {
        if #available(iOS 14.5, *) {
            let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            print(deviceTokenString)
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                self.accountService.setPushNotificationTopic(topic: bundleIdentifier)
            }
            self.accountService.setPushNotificationToken(token: deviceTokenString)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        var dictionary = [String: String]()
        for key in userInfo.keys {
            /// "aps" is a field added for alert notification type, so it could be received in the extension. This field is not needed by dht
            if String(describing: key) == "content-available" {
                continue
            }
            if let value = userInfo[key] {
                let keyString = String(describing: key)
                let valueString = String(describing: value)
                dictionary[keyString] = valueString
            }
        }
        var state = UIApplication.shared.applicationState
        if state == .background {
            self.accountService.setAccountsActive(active: true)
        }
        self.accountService.pushNotificationReceived(data: dictionary)
        sleep(5)
        state = UIApplication.shared.applicationState
        if state == .background {
            self.accountService.setAccountsActive(active: false)
        }
        completionHandler(.newData)
    }
}

// MARK: PKPushRegistryDelegate
extension AppDelegate: PKPushRegistryDelegate {

    /// Used only for ios before 14.5
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard #available(iOS 14.5, *) else {
            self.accountService.setPushNotificationToken(token: "")
            return
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard #available(iOS 14.5, *) else {
            if type == PKPushType.voIP {
                let deviceTokenString = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
                if let bundleIdentifier = Bundle.main.bundleIdentifier {
                    self.accountService.setPushNotificationTopic(topic: bundleIdentifier + ".voip")
                }
                self.accountService.setPushNotificationToken(token: deviceTokenString)
            }
            return
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        /// before ios 14.5 this function is called by Apple, we should notify daemon. After ios 14.5 it called from notification extension. We must present Call screen
        if #available(iOS 14.5, *) {
            /// called from the notification extension. Account is not active at this point
            self.accountService.setAccountsActive(active: true)
            if let data = payload.dictionaryPayload as? [String: Any] {
                self.accountService.pushNotificationReceived(data: data)
            }
            /// if we present call kit early, there are will be no call from the daemon. And if a user answer fast there will be a time gap before call screen could be presented
            /// sleep for 2 second to give time for the daemon to receive a call.
            sleep(2)
            let peerId: String = payload.dictionaryPayload["peerId"] as? String ?? ""
            let hasVideo = payload.dictionaryPayload["hasVideo"] as? String ?? "true"
            callsProvider.previewCall(peerId: peerId, withVideo: hasVideo.boolValue) { _ in
                completion()
            }
        } else if let data = payload.dictionaryPayload as? [String: Any] {
            self.accountService.pushNotificationReceived(data: data)
        }
    }
}
