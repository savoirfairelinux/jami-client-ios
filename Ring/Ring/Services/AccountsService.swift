/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Authors: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *  Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import RxCocoa
import RxSwift
import SwiftyBeaver

enum LinkNewDeviceError: Error {
    case unknownError
}

enum DeviceRevocationState: Int {
    case success = 0
    case wrongPassword = 1
    case unknownDevice = 2
}

enum AddAccountError: Error {
    case templateNotConform
    case unknownError
    case noAccountFound
}

enum NotificationName: String {
    case enablePushNotifications
    case disablePushNotifications
    case answerCallFromNotifications
    case refuseCallFromNotifications
    case nameRegistered
    case restoreDefaultVideoDevice
}

enum MigrationState: String {
    case INVALID
    case SUCCESS
    case UNKOWN
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class AccountsService: AccountAdapterDelegate {
    // MARK: Private members

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    let selectedAccountID = "SELECTED_ACCOUNT_ID"
    let boothModeEnabled = "BOOTH_MODE_ENABLED"

    /**
     Used to register the service to daemon events, injected by constructor.
     */
    private let accountAdapter: AccountAdapter

    /**
     private Accounts list.
     Can be used for all the operations, but won't be accessed from outside this file.

     - SeeAlso: `accounts`
     */
    private var accountList: [AccountModel]

    private let disposeBag = DisposeBag()

    /**
     PublishSubject forwarding AccountRxEvent events.
     This stream is used strictly inside this service.
     External observers should use the public shared responseStream.

     - SeeAlso: `ServiceEvent`
     - SeeAlso: `sharedResponseStream`
     */
    private let responseStream = PublishSubject<ServiceEvent>()
    let dbManager: DBManager
    let needMigrateCurrentAccount = PublishSubject<String>()

    // MARK: - Public members

    /**
     Accounts list public interface.
     Can be used to access by constant the list of accounts.
     */
    var accounts: [AccountModel] {
        get {
            let lAccounts = accountList
            return lAccounts
        }
        set {
            accountList = newValue
        }
    }

    var accountsObservable = BehaviorRelay<[AccountModel]>(value: [AccountModel]())

    let currentAccountChanged = PublishSubject<AccountModel?>()
    let currentWillChange = PublishSubject<AccountModel?>()

    /**
     Public shared stream forwarding the events of the responseStream.
     External observers must subscribe to this stream to get results.

     - SeeAlso: `responseStream`
     - SeeAlso: `ServiceEvent`
     */
    var sharedResponseStream: Observable<ServiceEvent>

    /**
     Current account computed property

     This will reorganize the order of the accounts. The current account needs to be first.

     - Parameter account: the account to set as current.
     */

    var currentAccount: AccountModel? {
        get {
            return accountList.first
        }

        set {
            if currentAccount != newValue {
                currentWillChange.onNext(currentAccount)
            }
            // Get the current account from account list if already exists
            let currentAccount = accountList.filter { account in
                account == newValue
            }.first

            guard let newAccount = newValue else { return }

            // If current account already exists in the list, move it to the first index
            if let currentAccount = currentAccount,
               let index = accountList.firstIndex(of: currentAccount) {
                if index != 0 {
                    accountList.remove(at: index)
                    accountList.insert(currentAccount, at: 0)
                }
                currentAccountChanged.onNext(currentAccount)
            } else {
                accountList.append(newAccount)
                currentAccountChanged.onNext(currentAccount)
            }
        }
    }

    var accountInfoToShare: [String]? {
        var info = [String]()
        guard let account = currentAccount else { return nil }
        var nameToContact = ""
        if account.type == .sip {
            guard let accountDetails = account.details,
                  let credentials = account.credentialDetails.first else { return nil }
            if AccountModelHelper(withAccount: account).isAccountRing() {
                return nil
            }
            let username = credentials.username
            let server = accountDetails
                .get(withConfigKeyModel: ConfigKeyModel(withKey: .accountHostname))
            if username.isEmpty || server.isEmpty {
                return nil
            }
            nameToContact = username + "@" + server
        }
        if !account.registeredName.isEmpty {
            nameToContact = account.registeredName
        } else if let userNameData = UserDefaults.standard.dictionary(forKey: registeredNamesKey),
                  let accountName = userNameData[account.id] as? String,
                  !accountName.isEmpty {
            nameToContact = accountName
        }
        if nameToContact.isEmpty {
            nameToContact = account.jamiId
        }
        let title = L10n.AccountPage.contactMeOnJamiContant(nameToContact)
        info.append(title)
        return info
    }

    init(withAccountAdapter accountAdapter: AccountAdapter, dbManager: DBManager) {
        accountList = []

        responseStream.disposed(by: disposeBag)

        // ~ Create a shared stream based on the responseStream one.
        sharedResponseStream = responseStream.share()

        self.accountAdapter = accountAdapter
        self.dbManager = dbManager
        // ~ Registering to the accountAdatpter with self as delegate in order to receive delegation
        // ~ callbacks.
        AccountAdapter.delegate = self
    }

    private func loadAccountsFromDaemon() {
        let selectedAccount = currentAccount
        accountList.removeAll()
        for accountId in accountAdapter.getAccountList() {
            if let id = accountId as? String {
                accountList.append(AccountModel(withAccountId: id))
            }
        }
        reloadAccounts()
        accountsObservable.accept(accountList)
        if selectedAccount != nil {
            let currentAccount = accountList.filter { account in
                account == selectedAccount
            }.first
            if let currentAccount = currentAccount,
               let index = accountList.firstIndex(of: currentAccount) {
                accountList.remove(at: index)
                accountList.insert(currentAccount, at: 0)
            }
        }
    }

    func initialAccountsLoading() -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create {} }
            self.loadAccountsFromDaemon()
            completable(.completed)
            return Disposables.create {}
        }
    }

    func loadAccounts() -> Single<[AccountModel]> {
        return Single<[AccountModel]>.just({
            loadAccountsFromDaemon()
            return accountList
        }())
    }

    // MARK: - Methods

    func hasAccounts() -> Bool {
        return !accountList.isEmpty
    }

    private func reloadAccounts() {
        for account in accountList {
            account.details = getAccountDetails(fromAccountId: account.id)
            account.volatileDetails = getVolatileAccountDetails(fromAccountId: account.id)
            account.devices = getKnownRingDevices(fromAccountId: account.id)

            do {
                let credentialDetails = try getAccountCredentials(fromAccountId: account.id)
                account.credentialDetails.removeAll()
                account.credentialDetails.append(contentsOf: credentialDetails)
            } catch {
                log.error("\(error)")
            }
        }
    }

    func updateCurrentAccount(account: AccountModel) {
        if currentAccount != account {
            currentAccount = account
        }
    }

    func boothMode() -> Bool {
        return UserDefaults.standard.bool(forKey: boothModeEnabled)
    }

    func setBoothMode(forAccount accountId: String, enable: Bool, password: String) -> Bool {
        let enabled = UserDefaults.standard.bool(forKey: boothModeEnabled)
        if enabled == enable {
            return true
        }
        if !accountAdapter.passwordIsValid(accountId, password: password) {
            return false
        }
        UserDefaults.standard.set(enable, forKey: boothModeEnabled)
        let details = getAccountDetails(fromAccountId: accountId)
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.dhtPublicIn),
                 withValue: (!enable).toString())
        setAccountDetails(forAccountId: accountId, withDetails: details)
        return true
    }

    func changePassword(forAccount accountId: String, password: String,
                        newPassword: String) -> Bool {
        let result = accountAdapter.changeAccountPassword(
            accountId,
            oldPassword: password,
            newPassword: newPassword
        )
        if !result {
            return false
        }
        let details = getAccountDetails(fromAccountId: accountId)
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.archiveHasPassword),
                 withValue: (!newPassword.isEmpty).toString())
        setAccountDetails(forAccountId: accountId, withDetails: details)
        return true
    }

    func getAccountProfile(accountId: String) -> Profile? {
        return dbManager.accountProfile(for: accountId)
    }

    /// Adds a new Jami account.
    ///
    /// - Parameters:
    ///   - username: an optional username for the new account
    ///   - password: the required password for the new account
    /// - Returns: an observable of an AccountModel: the created one
    func addJamiAccount(username: String?, password: String,
                        enable: Bool) -> Observable<AccountModel> {
        // ~ Single asking the daemon to add a new account with the associated metadata
        var newAccountId = ""
        let createAccountSingle: Single<AccountModel> = Single
            .create(subscribe: { single -> Disposable in
                do {
                    var details = try self.getJamiInitialAccountDetails()
                    if let username = username {
                        details.updateValue(
                            username,
                            forKey: ConfigKey.accountRegisteredName.rawValue
                        )
                    }
                    if !password.isEmpty {
                        details.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                    }
                    details.updateValue(enable.toString(), forKey: ConfigKey.proxyEnabled.rawValue)
                    if let testServer = TestEnvironment.shared.nameServerURI {
                        details.updateValue(testServer, forKey: ConfigKey.ringNsURI.rawValue)
                    }

                    guard let accountId = self.accountAdapter.addAccount(details) else {
                        throw AddAccountError.unknownError
                    }
                    newAccountId = accountId
                    let account = try self.buildAccountFromDaemon(accountId: accountId)
                    single(.success(account))
                } catch {
                    single(.failure(error))
                }
                return Disposables.create {}
            })

        // ~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = sharedResponseStream
            .filter { serviceEvent -> Bool in
                if serviceEvent
                    .getEventInput(ServiceEventInput.accountId) != newAccountId { return false }
                if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                    throw AccountCreationError.generic
                } else if serviceEvent
                            .getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    throw AccountCreationError.network
                }
                let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType
                    .registrationStateChanged
                let isRegistered = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState) == Registered
                let notRegistered = serviceEvent
                    .getEventInput(ServiceEventInput.registrationState) == Unregistered
                return isRegistrationStateChanged && (isRegistered || notRegistered)
            }

        // ~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(
                createAccountSingle.asObservable(),
                filteredDaemonSignals.asObservable()
            ) { accountModel, serviceEvent -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId)
                else {
                    throw AddAccountError.unknownError
                }
                // create database for account
                if try !self.dbManager.createDatabaseForAccount(accountId: accountModel.id) {
                    throw AddAccountError.unknownError
                }
                self.loadAccountsFromDaemon()
                return accountModel
            }
            .take(1)
            .flatMap { [weak self] accountModel -> Observable<AccountModel> in
                guard let self = self else { return Observable.empty() }
                self.currentAccount = accountModel
                UserDefaults.standard.set(accountModel.id, forKey: self.selectedAccountID)
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            }
    }

    func addSipAccount(userName: String,
                       password: String,
                       sipServer: String) -> Bool {
        do {
            var accountDetails = try getInitialAccountDetails(accountType: AccountType.sip.rawValue)
            accountDetails.updateValue(userName, forKey: ConfigKey.accountUsername.rawValue)
            accountDetails.updateValue(sipServer, forKey: ConfigKey.accountHostname.rawValue)
            accountDetails.updateValue(password, forKey: ConfigKey.accountPassword.rawValue)
            guard let account = accountAdapter.addAccount(accountDetails) else { return false }
            _ = try dbManager.createDatabaseForAccount(accountId: account, createFolder: true)
            loadAccountsFromDaemon()
            guard let newAccount = getAccount(fromAccountId: account) else { return false }
            let accountUri = AccountModelHelper(withAccount: newAccount).uri ?? ""
            _ = dbManager.saveAccountProfile(
                alias: nil,
                photo: nil,
                accountId: account,
                accountURI: accountUri
            )
            currentAccount = newAccount
            UserDefaults.standard.set(account, forKey: selectedAccountID)
            return true
        } catch {
            return false
        }
    }

    func linkToJamiAccount(withPin pin: String, password: String,
                           enable: Bool) -> Observable<AccountModel> {
        var newAccountId = ""
        // ~ Single asking the daemon to add a new account with the associated metadata
        let createAccountSingle: Single<AccountModel> = Single
            .create(subscribe: { single -> Disposable in
                do {
                    var details = try self.getJamiInitialAccountDetails()
                    details.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                    details.updateValue(pin, forKey: ConfigKey.archivePIN.rawValue)
                    details.updateValue(enable.toString(), forKey: ConfigKey.proxyEnabled.rawValue)
                    guard let accountId = self.accountAdapter.addAccount(details) else {
                        throw AddAccountError.unknownError
                    }
                    newAccountId = accountId
                    let account = try self.buildAccountFromDaemon(accountId: accountId)
                    single(.success(account))
                } catch {
                    single(.failure(error))
                }
                return Disposables.create {}
            })
        // ~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = sharedResponseStream.filter { serviceEvent -> Bool in
            if serviceEvent
                .getEventInput(ServiceEventInput.accountId) != newAccountId { return false }
            if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                throw AccountCreationError.linkError
            } else if serviceEvent
                        .getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                throw AccountCreationError.network
            }
            let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType
                .registrationStateChanged
            let isRegistered = serviceEvent
                .getEventInput(ServiceEventInput.registrationState) == Registered
            return isRegistrationStateChanged && isRegistered
        }
        // ~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(
                createAccountSingle.asObservable(),
                filteredDaemonSignals.asObservable()
            ) { accountModel, serviceEvent -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId)
                else {
                    throw AddAccountError.unknownError
                }
                // create database for account
                if try !self.dbManager.createDatabaseForAccount(accountId: accountModel.id) {
                    throw AddAccountError.unknownError
                }
                self.loadAccountsFromDaemon()
                return accountModel
            }
            .take(1)
            .flatMap { [weak self] accountModel -> Observable<AccountModel> in
                guard let self = self else { return Observable.empty() }
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            }
    }

    enum ConnectAccountState: String {
        case initializinzg
        case created
        case error
        case networkError
    }

    func connectToAccountManager(
        username: String,
        password: String,
        serverUri: String,
        emableNotifications: Bool
    ) -> Observable<AccountModel> {
        let accountState = BehaviorRelay<ConnectAccountState>(value: ConnectAccountState
                                                                .initializinzg)
        let newAccountId = BehaviorRelay<String>(value: "")
        sharedResponseStream
            .subscribe(onNext: { event in
                if event.getEventInput(ServiceEventInput.registrationState) == Initializing {
                    return
                }
                if event.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    accountState.accept(ConnectAccountState.networkError)
                    newAccountId.accept("")
                } else if event.eventType == ServiceEventType.registrationStateChanged,
                          event.getEventInput(ServiceEventInput.registrationState) == Registered {
                    accountState.accept(ConnectAccountState.created)
                } else if event
                            .getEventInput(ServiceEventInput.registrationState) == ErrorGeneric ||
                            event.getEventInput(ServiceEventInput.registrationState) == ErrorAuth ||
                            event
                            .getEventInput(ServiceEventInput.registrationState) ==
                            ErrorNeedMigration {
                    accountState.accept(ConnectAccountState.error)
                    newAccountId.accept("")
                }
            }, onError: { _ in
            })
            .disposed(by: disposeBag)

        let result = Observable
            .combineLatest(accountState.asObservable()
                            .filter { state -> Bool in
                                state != ConnectAccountState.initializinzg
                            },
                           newAccountId.asObservable()) { accountState, accountId -> AccountModel in
                if accountState == ConnectAccountState.networkError {
                    throw AccountCreationError.network
                } else if accountState == ConnectAccountState.error {
                    throw AccountCreationError.wrongCredentials
                } else if !accountId.isEmpty && accountState == ConnectAccountState.created {
                    self.loadAccountsFromDaemon()
                    let account = try self.buildAccountFromDaemon(accountId: accountId)
                    return account
                } else {
                    throw AddAccountError.unknownError
                }
            }
            .take(1)
            .flatMap { [weak self] accountModel -> Observable<AccountModel> in
                guard let self = self else { return Observable.empty() }
                self.currentAccount = accountModel
                UserDefaults.standard.set(accountModel.id, forKey: self.selectedAccountID)
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do {
                var details = try self.getJamiInitialAccountDetails()
                details.updateValue(username, forKey: ConfigKey.managerUsername.rawValue)
                details.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                details.updateValue(
                    emableNotifications.toString(),
                    forKey: ConfigKey.proxyEnabled.rawValue
                )
                details.updateValue(serverUri, forKey: ConfigKey.managerUri.rawValue)
                guard let accountId = self.accountAdapter.addAccount(details) else {
                    throw AccountCreationError.wrongCredentials
                }
                newAccountId.accept(accountId)
            } catch {}
        }
        return result
    }

    /**
     Gets an account from the list of accounts handled by the application.

     - Parameter id: the id of the account to get.

     - Returns: the account if found, nil otherwise.
     */
    func getAccount(fromAccountId id: String) -> AccountModel? {
        for account in accountList
        where id.compare(account.id) == ComparisonResult.orderedSame {
            return account
        }
        return nil
    }

    /// Gets the account from the daemon responding to the given id.
    ///
    /// - Parameter id: the id of the account to get.
    /// - Returns: a single of an AccountModel
    func getAccountFromDaemon(fromAccountId id: String) -> Single<AccountModel> {
        return loadAccounts().map { accountModels -> AccountModel in
            guard let account = accountModels.filter({ accountModel -> Bool in
                id == accountModel.id
            }).first else {
                throw AddAccountError.noAccountFound
            }
            return account
        }
    }

    /**
     Gets all the details of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the details of the account.
     */
    func getAccountDetails(fromAccountId id: String) -> AccountConfigModel {
        let details: NSDictionary = accountAdapter.getAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }

    /**
     Sets all the details of an account in the daemon.
     - Parameter id: the id of the account.
     - Parameter newDetails: the new details to set for the account.
     */
    func setAccountDetails(forAccountId id: String, withDetails newDetails: AccountConfigModel) {
        let details = newDetails.toDetails()
        accountAdapter.setAccountDetails(id, details: details)
    }

    /**
     Sets credentials of an account in the daemon.
     - Parameter id: the id of the account.
     - Parameter crdentials: the new credentials to set for the account.
     */
    func setAccountCrdentials(forAccountId id: String,
                              crdentials: [[String: String]]) {
        accountAdapter.setAccountCredentials(id, credentials: crdentials)
    }

    /**
     Gets all the volatile details of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the volatile details of the account.
     */
    func getVolatileAccountDetails(fromAccountId id: String) -> AccountConfigModel {
        let details: NSDictionary = accountAdapter.getVolatileAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }

    /**
     Gets the credentials of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the list of credentials.
     */
    func getAccountCredentials(fromAccountId id: String) throws -> [AccountCredentialsModel] {
        let creds: NSArray = accountAdapter.getCredentials(id) as NSArray
        let rawCredentials = creds as NSArray? as? [[String: String]] ?? nil

        if let rawCredentials = rawCredentials {
            var credentialsList = [AccountCredentialsModel]()
            for rawCredentials in rawCredentials {
                do {
                    let credentials = try AccountCredentialsModel(withRawaData: rawCredentials)
                    credentialsList.append(credentials)
                } catch CredentialsError.notEnoughData {
                    log.error("Not enough data to build a credential object.")
                    throw CredentialsError.notEnoughData
                } catch {
                    log.error("Unexpected error.")
                    throw AccountModelError.unexpectedError
                }
            }
            return credentialsList
        } else {
            throw AccountModelError.unexpectedError
        }
    }

    /**
     Gets the known Ring devices of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the known Ring devices.
     */
    func getKnownRingDevices(fromAccountId id: String) -> [DeviceModel] {
        let knownRingDevices = accountAdapter.getKnownRingDevices(id) as NSDictionary

        var devices = [DeviceModel]()

        let accountDetails = getAccountDetails(fromAccountId: id)
        let currentDeviceId = accountDetails
            .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountDeviceId))

        for key in knownRingDevices.allKeys {
            if let key = key as? String {
                devices.append(DeviceModel(withDeviceId: key,
                                           deviceName: knownRingDevices
                                            .value(forKey: key) as? String,
                                           isCurrent: key == currentDeviceId))
            }
        }

        return devices
    }

    func revokeDevice(for account: String,
                      withPassword password: String,
                      deviceId: String) {
        accountAdapter.revokeDevice(account, password: password, deviceId: deviceId)
    }

    /**
     Gathers all the initial default details contained by any accounts, Ring or SIP.

     - Returns the details.
     */
    private func getInitialAccountDetails(accountType: String) throws -> [String: String] {
        let details: NSMutableDictionary = accountAdapter.getAccountTemplate(accountType)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AddAccountError.templateNotConform
        }
        accountDetails!.updateValue("oversip", forKey: ConfigKey.accountDTMFType.rawValue)
        accountDetails!.updateValue(accountType, forKey: ConfigKey.accountType.rawValue)
        accountDetails!.updateValue("false", forKey: ConfigKey.ringtoneEnabled.rawValue)
        return accountDetails!
    }

    /**
     Gathers all the initial default details contained in a Jami accounts.

     - Returns the details.
     */
    private func getJamiInitialAccountDetails() throws -> [String: String] {
        do {
            let defaultDetails = try getInitialAccountDetails(accountType: AccountType.ring
                                                                .rawValue)
            return defaultDetails
        } catch {
            throw error
        }
    }

    func removeAccount(_ row: Int) {
        if row < accountList.count {
            accountAdapter.removeAccount(accountList[row].id)
        }
    }

    func needAccountMigration(accountId: String) -> Bool {
        guard let account = getAccount(fromAccountId: accountId) else { return false }
        return account.status == .errorNeedMigration
    }

    func hasValidAccount() -> Bool {
        for account in accountList where account.status != .errorNeedMigration {
            return true
        }
        return false
    }

    func migrateAccount(account accountId: String, password: String) -> Observable<Bool> {
        let saveAccount: Single<Bool> =
            Single.create(subscribe: { single -> Disposable in
                let details = self.getAccountDetails(fromAccountId: accountId)
                details
                    .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.archivePassword),
                         withValue: password)
                self.setAccountDetails(forAccountId: accountId, withDetails: details)
                single(.success(true))
                return Disposables.create {}
            })
        let filteredDaemonSignals = sharedResponseStream
            .filter { serviceEvent -> Bool in
                serviceEvent.getEventInput(ServiceEventInput.accountId) == accountId &&
                    serviceEvent.eventType == .migrationEnded
            }
        return Observable
            .combineLatest(saveAccount.asObservable(),
                           filteredDaemonSignals.asObservable()) { _, serviceEvent -> Bool in
                guard let status: String = serviceEvent.getEventInput(ServiceEventInput.state),
                      let migrationStatus = MigrationState(rawValue: status)
                else { return false }
                switch migrationStatus {
                case .SUCCESS:
                    return true
                default:
                    return false
                }
            }
    }

    func removeAccount(id: String) {
        guard let account = getAccount(fromAccountId: id) else { return }
        let shouldRemoveFolder = AccountModelHelper(withAccount: account).isAccountSip()
        dbManager.removeDBForAccount(accountId: id, removeFolder: shouldRemoveFolder)
        accountAdapter.removeAccount(id)
        loadAccountsFromDaemon()
        if getAccount(fromAccountId: id) == nil {
            guard let documentsURL = Constants.documentsPath else {
                return
            }
            let downloadsURL = documentsURL.appendingPathComponent(Directories.downloads.rawValue)
                .appendingPathComponent(id)
            try? FileManager.default.removeItem(atPath: downloadsURL.path)
            let recordingsURL = documentsURL.appendingPathComponent(Directories.recorded.rawValue)
                .appendingPathComponent(id)
            try? FileManager.default.removeItem(atPath: recordingsURL.path)
        }
    }

    // MARK: - AccountAdapterDelegate

    func accountsChanged() {
        log.debug("Accounts changed.")
        reloadAccounts()

        let event = ServiceEvent(withEventType: .accountsChanged)
        responseStream.onNext(event)
    }

    func migrationEnded(for account: String, status: String) {
        var event = ServiceEvent(withEventType: .migrationEnded)
        event.addEventInput(.state, value: status)
        event.addEventInput(.accountId, value: account)
        responseStream.onNext(event)
    }

    func registrationStateChanged(with response: RegistrationResponse) {
        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
        event.addEventInput(.accountId, value: response.accountId)
        responseStream.onNext(event)
        if let account = getAccount(fromAccountId: response.accountId) {
            account.volatileDetails = getVolatileAccountDetails(fromAccountId: response.accountId)
        }
        if let currentAccount = currentAccount,
           response.state == ErrorNeedMigration,
           response.accountId == currentAccount.id {
            needMigrateCurrentAccount.onNext(currentAccount.id)
        }
    }

    func knownDevicesChanged(for account: String, devices _: [String: String]) {
        reloadAccounts()
        var event = ServiceEvent(withEventType: .knownDevicesChanged)
        event.addEventInput(.accountId, value: account)
        responseStream.onNext(event)
    }

    func exportOnRing(withPassword password: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(LinkNewDeviceError.unknownError))
                return Disposables.create {}
            }
            let export = self.accountAdapter.export(
                onRing: self.currentAccount?.id,
                password: password
            )
            if export {
                completable(.completed)
            } else {
                completable(.error(LinkNewDeviceError.unknownError))
            }
            return Disposables.create {}
        }
    }

    func exportOnRingEnded(for account: String, state: Int, pin: String) {
        var event = ServiceEvent(withEventType: .exportOnRingEnded)
        event.addEventInput(.id, value: account)
        event.addEventInput(.state, value: state)
        event.addEventInput(.pin, value: pin)
        responseStream.onNext(event)
    }

    func deviceRevocationEnded(for account: String, state: Int, deviceId: String) {
        var event = ServiceEvent(withEventType: .deviceRevocationEnded)
        event.addEventInput(.id, value: account)
        event.addEventInput(.state, value: state)
        event.addEventInput(.deviceId, value: deviceId)
        responseStream.onNext(event)
    }

    // MARK: Push Notifications

    func setPushNotificationToken(token: String) {
        accountAdapter.setPushNotificationToken(token)
    }

    func setPushNotificationTopic(topic: String) {
        accountAdapter.setPushNotificationTopic(topic)
    }

    func pushNotificationReceived(data: [String: Any]) {
        var notificationData = [String: String]()
        for key in data.keys {
            if let value = data[key] {
                let valueString = String(describing: value)
                let keyString = String(describing: key)
                notificationData[keyString] = valueString
            }
        }
        accountAdapter.pushNotificationReceived("", message: notificationData)
    }

    func getCurrentProxyState(accountID: String) -> Bool {
        var proxyEnabled = false
        let accountDetails = getAccountDetails(fromAccountId: accountID)
        if accountDetails
            .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
            proxyEnabled = true
        }
        return proxyEnabled
    }

    func proxyEnabled(accountID: String) -> BehaviorRelay<Bool> {
        let variable = BehaviorRelay<Bool>(value: getCurrentProxyState(accountID: accountID))
        sharedResponseStream
            .filter { event -> Bool in
                if let accountId: String = event.getEventInput(.accountId) {
                    return event.eventType == ServiceEventType.proxyEnabled
                        && accountId == accountID
                }
                return false
            }
            .subscribe(onNext: { event in
                if let state: Bool = event.getEventInput(.state) {
                    variable.accept(state)
                }
            })
            .disposed(by: disposeBag)
        return variable
    }

    func changeProxyStatus(accountID: String, enable: Bool) {
        let accountDetails = getAccountDetails(fromAccountId: accountID)
        if accountDetails
            .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) != enable
            .toString() {
            accountDetails.set(
                withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled),
                withValue: enable.toString()
            )
            setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
            var event = ServiceEvent(withEventType: .proxyEnabled)
            event.addEventInput(.state, value: enable)
            event.addEventInput(.accountId, value: accountID)
            responseStream.onNext(event)
        }
    }

    func setProxyAddress(accountID: String, proxy: String) {
        let accountDetails = getAccountDetails(fromAccountId: accountID)
        accountDetails.set(
            withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyServer),
            withValue: proxy
        )
        setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
    }

    func hasAccountWithProxyEnabled() -> Bool {
        for account in accounts {
            let accountDetails = getAccountDetails(fromAccountId: account.id)
            if accountDetails
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) ==
                "true" {
                return true
            }
        }
        return false
    }

    func proxyEnabled(for accountId: String) -> Bool {
        let accountDetails = getAccountDetails(fromAccountId: accountId)
        if accountDetails
            .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
            return true
        }
        return false
    }

    func isJams(for accountId: String) -> Bool {
        guard let account = getAccount(fromAccountId: accountId) else { return false }
        return account.isJams
    }

    func enableAccount(enable: Bool, accountId: String) {
        switchAccountPropertyTo(
            state: enable,
            accountId: accountId,
            property: ConfigKeyModel(withKey: ConfigKey.accountEnable)
        )
    }

    func enablePeerDiscovery(enable: Bool, accountId: String) {
        switchAccountPropertyTo(
            state: enable,
            accountId: accountId,
            property: ConfigKeyModel(withKey: ConfigKey.dhtPeerDiscovery)
        )
    }

    func enableTurn(enable: Bool, accountId: String) {
        switchAccountPropertyTo(
            state: enable,
            accountId: accountId,
            property: ConfigKeyModel(withKey: ConfigKey.turnEnable)
        )
    }

    func enableUpnp(enable: Bool, accountId: String) {
        switchAccountPropertyTo(
            state: enable,
            accountId: accountId,
            property: ConfigKeyModel(withKey: ConfigKey.accountUpnpEnabled)
        )
    }

    func enableSRTP(enable: Bool, accountId: String) {
        let newValue = enable ? "sdes" : ""
        let accountDetails = getAccountDetails(fromAccountId: accountId)
        let property = ConfigKeyModel(withKey: ConfigKey.srtpKeyExchange)
        guard accountDetails.get(withConfigKeyModel: property) != newValue else { return }
        accountDetails.set(withConfigKeyModel: property, withValue: newValue)
        setAccountDetails(forAccountId: accountId, withDetails: accountDetails)
    }

    func setTurnSettings(
        accountId: String,
        server: String,
        username: String,
        password: String,
        realm: String
    ) {
        let details = getAccountDetails(fromAccountId: accountId)
        details.set(
            withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.turnServer),
            withValue: server
        )
        details.set(
            withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.turnUsername),
            withValue: username
        )
        details.set(
            withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.turnPassword),
            withValue: password
        )
        details.set(
            withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.turnRealm),
            withValue: realm
        )
        setAccountDetails(forAccountId: accountId, withDetails: details)
    }

    func enableKeepAlive(enable: Bool, accountId: String) {
        switchAccountPropertyTo(
            state: enable,
            accountId: accountId,
            property: ConfigKeyModel(withKey: ConfigKey.keepAliveEnabled)
        )
    }

    func switchAccountPropertyTo(state: Bool, accountId: String, property: ConfigKeyModel) {
        let accountDetails = getAccountDetails(fromAccountId: accountId)
        guard accountDetails.get(withConfigKeyModel: property) != state.toString() else { return }
        accountDetails.set(withConfigKeyModel: property, withValue: state.toString())
        setAccountDetails(forAccountId: accountId, withDetails: accountDetails)
    }

    func setAccountsActive(active: Bool) {
        accountAdapter.setAccountsActive(active)
    }

    func setAccountActive(active: Bool, accountId: String) {
        accountAdapter.setAccountActive(accountId, active: active)
    }

    // MARK: - observable account data

    func devicesObservable(account: AccountModel) -> Observable<[DeviceModel]> {
        let accountDevices: Observable<[DeviceModel]> = Observable.just(account.devices)
        let newDevice: Observable<[DeviceModel]> = sharedResponseStream
            .filter { event in
                event.eventType == ServiceEventType.knownDevicesChanged &&
                    event.getEventInput(ServiceEventInput.accountId) == account.id
            }
            .map { _ in
                account.devices
            }
        return accountDevices.concat(newDevice)
    }
}

// MARK: - Private daemon wrappers

extension AccountsService {
    private func buildAccountFromDaemon(accountId id: String) throws -> AccountModel {
        let accountModel = AccountModel(withAccountId: id)
        accountModel.details = getAccountDetails(fromAccountId: id)
        accountModel.volatileDetails = getVolatileAccountDetails(fromAccountId: id)
        accountModel.devices = getKnownRingDevices(fromAccountId: id)
        do {
            let credentialDetails = try getAccountCredentials(fromAccountId: id)
            accountModel.credentialDetails.removeAll()
            accountModel.credentialDetails.append(contentsOf: credentialDetails)
        } catch {
            throw error
        }
        return accountModel
    }
}
