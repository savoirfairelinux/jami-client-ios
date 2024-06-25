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

import ContactsUI
import os
import PushKit
import RxSwift
import SwiftyBeaver
import UIKit

// swiftlint:disable identifier_name type_body_length
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
    private let systemService = SystemService(withSystemAdapter: SystemAdapter())
    private let networkService = NetworkService()
    private let callsProvider: CallsProviderService = .init(
        provider: CXProvider(configuration: CallsHelpers.providerConfiguration()),
        controller: CXCallController()
    )
    private var conversationManager: ConversationsManager?
    private var interactionsManager: GeneratedInteractionsManager?
    private var videoManager: VideoManager?
    private lazy var callService: CallsService = .init(
        withCallsAdapter: CallsAdapter(),
        dbManager: self.dBManager
    )

    private lazy var accountService: AccountsService = .init(
        withAccountAdapter: AccountAdapter(),
        dbManager: self.dBManager
    )

    private lazy var contactsService: ContactsService = .init(
        withContactsAdapter: ContactsAdapter(),
        dbManager: self.dBManager
    )

    private lazy var profileService: ProfilesService = .init(
        withProfilesAdapter: ProfilesAdapter(),
        dbManager: self.dBManager
    )

    private lazy var dataTransferService: DataTransferService = .init(
        withDataTransferAdapter: DataTransferAdapter(),
        dbManager: self.dBManager
    )

    private lazy var conversationsService: ConversationsService = .init(
        withConversationsAdapter: ConversationsAdapter(),
        dbManager: self.dBManager
    )

    private lazy var locationSharingService: LocationSharingService =
        .init(dbManager: self.dBManager)

    private lazy var requestsService: RequestsService = .init(
        withRequestsAdapter: RequestsAdapter(),
        dbManager: self.dBManager
    )

    private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    /*
     When the app is in the background, but the call screen is present, notifications
     should be handled by Jami.app and not by the notification extension.
     */
    private var presentingCallScreen = false

    lazy var injectionBag: InjectionBag = .init(withDaemonService: self.daemonService,
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
                                                withLocationSharingService: self
                                                    .locationSharingService,
                                                withRequestsService: self.requestsService,
                                                withSystemService: self.systemService)

    private lazy var appCoordinator: AppCoordinator = .init(with: self.injectionBag)

    private let log = SwiftyBeaver.self

    private let disposeBag = DisposeBag()

    private let center = CFNotificationCenterGetDarwinNotifyCenter()
    private static let shouldHandleNotification = NSNotification
        .Name("com.savoirfairelinux.jami.shouldHandleNotification")
    private let backgrounTaskQueue = DispatchQueue(label: "backgrounTaskQueue")

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // ignore sigpipe
        typealias SigHandler = @convention(c) (Int32) -> Void
        let SIG_IGN = unsafeBitCast(OpaquePointer(bitPattern: 1), to: SigHandler.self)
        signal(SIGPIPE, SIG_IGN)
        // swiftlint:enable nesting

        window = UIWindow(frame: UIScreen.main.bounds)

        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        if UserDefaults.standard.value(forKey: automaticDownloadFilesKey) == nil {
            UserDefaults.standard.set(true, forKey: automaticDownloadFilesKey)
        }
        UNUserNotificationCenter.current().delegate = self
        // initialize log format
        let console = ConsoleDestination()
        console.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
        #if DEBUG
        log.addDestination(console)
        #else
        log.removeAllDestinations()
        #endif

        // move files from the app container to the group container, so it could be accessed by
        // notification extension
        if !moveDataToGroupContainer() {
            window?.rootViewController = appCoordinator.rootViewController
            window?.makeKeyAndVisible()
            let alertController = UIAlertController(
                title: "There was an error starting Jami",
                message: "Please try again",
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: "Ok", style: UIAlertAction.Style.default)
            alertController.addAction(okAction)
            window?.rootViewController?.present(alertController, animated: true, completion: nil)
            return true
        }
        PreferenceManager.registerDonationsDefaults()

        addListenerForNotification()

        // starts the daemon
        startDaemon()

        // requests permission to use the camera
        // will enumerate and add devices once permission has been granted
        videoService.setupInputs()

        audioService.connectAudioSignal()

        // Observe connectivity changes and reconnect DHT
        networkService.connectionStateObservable
            .skip(1)
            .subscribe(onNext: { _ in
                self.daemonService.connectivityChanged()
            })
            .disposed(by: disposeBag)

        // start monitoring for network changes
        networkService.monitorNetworkType()

        interactionsManager = GeneratedInteractionsManager(accountService: accountService,
                                                           requestsService: requestsService,
                                                           conversationService: conversationsService,
                                                           callService: callService)

        // load accounts during splashscreen
        // and ask the AppCoordinator to handle the first screen once loading is finished
        conversationManager = ConversationsManager(with: conversationsService,
                                                   accountsService: accountService,
                                                   nameService: nameService,
                                                   dataTransferService: dataTransferService,
                                                   callService: callService,
                                                   locationSharingService: locationSharingService,
                                                   contactsService: contactsService,
                                                   callsProvider: callsProvider,
                                                   requestsService: requestsService,
                                                   profileService: profileService)
        videoManager = VideoManager(with: callService, videoService: videoService)
        window?.rootViewController = appCoordinator.rootViewController
        window?.makeKeyAndVisible()

        prepareVideoAcceleration()
        prepareAccounts()
        voipRegistry.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(registerNotifications),
                                               name: NSNotification
                                                .Name(rawValue: NotificationName
                                                        .enablePushNotifications.rawValue),
                                               object: nil)
        clearBadgeNumber()
        if let path = certificatePath() {
            setenv("CA_ROOT_FILE", path, 1)
        }
        window?.backgroundColor = UIColor.systemBackground
        return true
    }

    func moveDataToGroupContainer() -> Bool {
        let usingGroupConatinerKey = "usingGroupConatiner"
        if UserDefaults.standard.bool(forKey: usingGroupConatinerKey) {
            return true
        }
        guard let groupDocUrl = Constants.documentsPath,
              let groupCachesUrl = Constants.cachesPath,
              let appDocURL = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ),
              let appLibrURL = try? FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              )
        else {
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
        CFNotificationCenterAddObserver(center,
                                        nil, { _, _, _, _, _ in
                                            // emit signal so notification could be handeled by
                                            // daemon
                                            NotificationCenter.default.post(
                                                name: AppDelegate.shouldHandleNotification,
                                                object: nil,
                                                userInfo: nil
                                            )
                                        },
                                        Constants.notificationReceived,
                                        nil,
                                        .deliverImmediately)
    }

    func certificatePath() -> String? {
        let fileName = "cacert"
        let filExtension = "pem"
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let certPath = documentsURL.appendingPathComponent(fileName)
            .appendingPathExtension(filExtension)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: certPath.path) {
            return certPath.path
        }
        guard let certSource = Bundle.main.url(forResource: fileName, withExtension: filExtension)
        else {
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
        accountService
            .needMigrateCurrentAccount
            .subscribe(onNext: { account in
                DispatchQueue.main.async {
                    self.appCoordinator.migrateAccount(accountId: account)
                }
            })
            .disposed(by: disposeBag)
        accountService.initialAccountsLoading()
            .subscribe(onCompleted: {
                // set selected account if exists
                self.appCoordinator.start()
                if !self.accountService.hasAccounts() {
                    // Set default download transfer limit to 20MB.
                    let userDefaults = UserDefaults.standard
                    if userDefaults.object(forKey: acceptTransferLimitKey) == nil {
                        userDefaults.set(20, forKey: acceptTransferLimitKey)
                    }
                    if userDefaults.object(forKey: hardareAccelerationKey) == nil {
                        self.videoService.setHardwareAccelerated(withState: true)
                        UserDefaults.standard.set(true, forKey: hardareAccelerationKey)
                    }
                    if userDefaults.object(forKey: limitLocationSharingDurationKey) == nil {
                        UserDefaults.standard.set(true, forKey: limitLocationSharingDurationKey)
                    }
                    if userDefaults.object(forKey: locationSharingDurationKey) == nil {
                        UserDefaults.standard.set(15, forKey: locationSharingDurationKey)
                    }
                    return
                }
                if self.accountService.hasAccountWithProxyEnabled() {
                    self.registerNotifications()
                } else {
                    self.unregisterNotifications()
                }
                if let selectedAccountId = UserDefaults.standard
                    .string(forKey: self.accountService.selectedAccountID),
                   let account = self.accountService.getAccount(fromAccountId: selectedAccountId) {
                    self.accountService.currentAccount = account
                }
                guard let currentAccount = self.accountService.currentAccount else {
                    self.log.error("Can't get current account!")
                    return
                }
                DispatchQueue.global(qos: .background).async { [weak self] in
                    guard let self = self else { return }
                    self.reloadDataFor(account: currentAccount)
                }
            }, onError: { _ in
                self.appCoordinator.showInitialLoading()
                let time = DispatchTime.now() + 1
                DispatchQueue.main.asyncAfter(deadline: time) {
                    self.appCoordinator.showDatabaseError()
                }
            })
            .disposed(by: disposeBag)

        accountService.currentWillChange
            .subscribe(onNext: { account in
                guard let currentAccount = account else { return }
                self.conversationsService.clearConversationsData(accountId: currentAccount.id)
                self.presenceService.subscribeBuddies(
                    withAccount: currentAccount.id,
                    withContacts: self.contactsService.contacts.value,
                    subscribe: false
                )
            })
            .disposed(by: disposeBag)

        accountService.currentAccountChanged
            .subscribe(onNext: { account in
                guard let currentAccount = account else { return }
                self.reloadDataFor(account: currentAccount)
            })
            .disposed(by: disposeBag)
    }

    func updateCallScreenState(presenting: Bool) {
        presentingCallScreen = presenting
    }

    func reloadDataFor(account: AccountModel) {
        requestsService.loadRequests(withAccount: account.id, accountURI: account.jamiId)
        conversationManager?
            .prepareConversationsForAccount(accountId: account.id, accountURI: account.jamiId)
        contactsService.loadContacts(withAccount: account)
        presenceService.subscribeBuddies(
            withAccount: account.id,
            withContacts: contactsService.contacts.value,
            subscribe: true
        )
    }

    func applicationDidEnterBackground(_: UIApplication) {
        log.warning("entering background")
        guard let account = accountService.currentAccount else { return }
        presenceService.subscribeBuddies(
            withAccount: account.id,
            withContacts: contactsService.contacts.value,
            subscribe: false
        )
    }

    func applicationWillEnterForeground(_: UIApplication) {
        log.warning("entering foreground")
        updateNotificationAvailability()
        guard let account = accountService.currentAccount else { return }
        presenceService.subscribeBuddies(
            withAccount: account.id,
            withContacts: contactsService.contacts.value,
            subscribe: true
        )
    }

    func applicationWillTerminate(_: UIApplication) {
        callsProvider.stopAllUnhandeledCalls()
        stopDaemon()
    }

    func applicationDidBecomeActive(_: UIApplication) {
        clearBadgeNumber()
        guard let account = accountService.currentAccount else { return }
        presenceService.subscribeBuddies(
            withAccount: account.id,
            withContacts: contactsService.contacts.value,
            subscribe: true
        )
    }

    func applicationWillResignActive(_: UIApplication) {
        guard let account = accountService.currentAccount else { return }
        presenceService.subscribeBuddies(
            withAccount: account.id,
            withContacts: contactsService.contacts.value,
            subscribe: false
        )
    }

    func prepareVideoAcceleration() {
        // we want enable hardware acceleration by default so if key does not exists,
        // means it was not disabled by user
        let keyExists = UserDefaults.standard.object(forKey: hardareAccelerationKey) != nil
        let enable = keyExists ? UserDefaults.standard.bool(forKey: hardareAccelerationKey) : true
        videoService.setHardwareAccelerated(withState: enable)
    }

    // MARK: - Ring Daemon

    private func startDaemon() {
        do {
            try daemonService.startDaemon()
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
            try daemonService.stopDaemon()
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // If the app is running in the background and there are no waiting calls, the extension
            // should handle the notification.
            if UIApplication.shared.applicationState == .background && !self
                .presentingCallScreen && !self.callsProvider.hasActiveCalls() {
                return
            }
            // emit signal that app is active for notification extension
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(Constants.notificationAppIsActive),
                nil,
                nil,
                true
            )

            guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier),
                  let notificationData = userDefaults
                    .object(forKey: Constants.notificationData) as? [[String: String]]
            else {
                return
            }
            userDefaults.set([[String: String]](), forKey: Constants.notificationData)
            for data in notificationData {
                self.accountService.pushNotificationReceived(data: data)
            }
        }
    }

    @objc
    private func registerNotifications() {
        requestNotificationAuthorization()
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    private func unregisterNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.unregisterForRemoteNotifications()
        }
        voipRegistry.desiredPushTypes = nil
        accountService.setPushNotificationToken(token: "")
    }

    private func requestNotificationAuthorization() {
        let application = UIApplication.shared
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().delegate = application
                .delegate as? UNUserNotificationCenterDelegate
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { enable, _ in
                    if enable {
                        LocalNotificationsHelper.setNotification(enable: true)
                    } else {
                        LocalNotificationsHelper.setNotification(enable: false)
                    }
                }
            )
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
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let data = response.notification.request.content.userInfo
        handleNotificationActions(data: data)
        completionHandler()
    }

    func handleNotificationActions(data: [AnyHashable: Any]) {
        guard let accountId =
                data[Constants.NotificationUserInfoKeys.accountID.rawValue] as? String,
              let account = accountService.getAccount(fromAccountId: accountId) else { return }
        accountService.updateCurrentAccount(account: account)
        if let conversationId =
            data[Constants.NotificationUserInfoKeys.conversationID.rawValue] as? String {
            conversationsService.updateConversationMessages(conversationId: conversationId)
            appCoordinator.openConversation(conversationId: conversationId, accountId: accountId)
        } else if let participantID =
                    data[Constants.NotificationUserInfoKeys.participantID.rawValue] as? String {
            appCoordinator.openConversation(participantID: participantID)
        }
    }

    func findContactAndStartCall(hash: String, isVideo: Bool) {
        // if saved jami hash
        if hash.isSHA1() {
            let contactUri = JamiURI(schema: URIType.ring, infoHash: hash)
            findAccountAndStartCall(uri: contactUri, isVideo: isVideo, type: AccountType.ring)
            return
        }
        // if saved jami registered name
        nameService.usernameLookupStatus
            .observe(on: MainScheduler.instance)
            .filter { usernameLookupStatus in
                usernameLookupStatus.name == hash
            }
            .take(1)
            .subscribe(onNext: { usernameLookupStatus in
                if usernameLookupStatus.state == .found {
                    guard let address = usernameLookupStatus.address else { return }
                    let contactUri = JamiURI(schema: URIType.ring, infoHash: address)
                    self.findAccountAndStartCall(
                        uri: contactUri,
                        isVideo: isVideo,
                        type: AccountType.ring
                    )
                } else {
                    // if saved sip contact
                    let contactUri = JamiURI(schema: URIType.sip, infoHash: hash)
                    self.findAccountAndStartCall(
                        uri: contactUri,
                        isVideo: isVideo,
                        type: AccountType.sip
                    )
                }
            })
            .disposed(by: disposeBag)
        nameService.lookupName(withAccount: "", nameserver: "", name: hash)
    }

    func findAccountAndStartCall(uri: JamiURI, isVideo: Bool, type: AccountType) {
        guard let currentAccount = accountService
                .currentAccount else { return }
        var hash = uri.hash ?? ""
        var uriString = uri.uriString ?? ""
        for account in accountService.accounts where account.type == type {
            if type == AccountType.sip {
                let conatactUri = JamiURI(schema: URIType.sip,
                                          infoHash: hash,
                                          account: account)
                hash = conatactUri.hash ?? ""
                uriString = conatactUri.uriString ?? ""
            }
            if hash.isEmpty || uriString.isEmpty { return }
            self.contactsService
                .getProfileForUri(uri: uriString,
                                  accountId: account.id)
                .subscribe(onNext: { profile in
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

    func application(_: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if accountService.boothMode() {
            return false
        }
        /*
         This method could be called when activating camera from CallKit.
         In this case we will have existing call with CallKit.
         Othervise it was called from Contacts app.
         We need find contact and start a call
         */
        if callsProvider.hasActiveCalls() { return false }
        guard let handle = userActivity.startCallHandle else {
            return false
        }
        findContactAndStartCall(hash: handle.hash, isVideo: handle.isVideo)
        return true
    }
}

// MARK: user notifications

extension AppDelegate {
    func application(_: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print(deviceTokenString)
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            accountService.setPushNotificationTopic(topic: bundleIdentifier)
        }
        accountService.setPushNotificationToken(token: deviceTokenString)
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        var dictionary = [String: String]()
        for key in userInfo.keys {
            if let value = userInfo[key] {
                let keyString = String(describing: key)
                let valueString = String(describing: value)
                dictionary[keyString] = valueString
            }
        }
        accountService.pushNotificationReceived(data: dictionary)
        completionHandler(.newData)
    }
}

// MARK: PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_: PKPushRegistry, didUpdate _: PKPushCredentials, for _: PKPushType) {}

    func pushRegistry(
        _: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for _: PKPushType,
        completion: @escaping () -> Void
    ) {
        updateCallScreenState(presenting: true)
        let peerId: String = payload.dictionaryPayload["peerId"] as? String ?? ""
        let hasVideo = payload.dictionaryPayload["hasVideo"] as? String ?? "true"
        let displayName = payload.dictionaryPayload["displayName"] as? String ?? ""
        callsProvider.previewPendingCall(
            peerId: peerId,
            withVideo: hasVideo.boolValue,
            displayName: displayName
        ) { error in
            if error != nil {
                self.updateCallScreenState(presenting: false)
            }
            completion()
        }
    }
}
