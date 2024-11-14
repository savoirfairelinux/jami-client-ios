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
    private(set) var accountList: [AccountModel]

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
            return self.accountList.first
        }

        set {
            if currentAccount != newValue {
                currentWillChange.onNext(currentAccount)
            }
            // Get the current account from account list if already exists
            let currentAccount = self.accountList.filter({ account in
                return account == newValue
            }).first

            guard let newAccount = newValue else { return }

            // If current account already exists in the list, move it to the first index
            if let currentAccount = currentAccount,
               let index = self.accountList.firstIndex(of: currentAccount) {
                if index != 0 {
                    self.accountList.remove(at: index)
                    self.accountList.insert(currentAccount, at: 0)
                }
                currentAccountChanged.onNext(currentAccount)
            } else {
                self.accountList.append(newAccount)
                currentAccountChanged.onNext(currentAccount)
            }
        }
    }

    var accountInfoToShare: [String]? {
        var info = [String]()
        guard let account = self.currentAccount else { return nil }
        var nameToContact = ""
        if account.type == .sip {
            guard let accountDetails = account.details,
                  let credentials = account.credentialDetails.first else { return nil }
            if AccountModelHelper.init(withAccount: account).isAccountRing() {
                return nil
            }
            let username = credentials.username
            let server = accountDetails.get(withConfigKeyModel: ConfigKeyModel.init(withKey: .accountHostname))
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
        self.accountList = []

        self.responseStream.disposed(by: disposeBag)

        // ~ Create a shared stream based on the responseStream one.
        self.sharedResponseStream = responseStream.share()

        self.accountAdapter = accountAdapter
        self.dbManager = dbManager
        // ~ Registering to the accountAdatpter with self as delegate in order to receive delegation
        // ~ callbacks.
        AccountAdapter.delegate = self
    }

    private func loadAccountsFromDaemon() {
        let selectedAccount = self.currentAccount
        self.accountList.removeAll()
        for accountId in accountAdapter.getAccountList() {
            if  let id = accountId as? String {
                self.accountList.append(AccountModel(withAccountId: id))
            }
        }
        self.reloadAccounts()
        if selectedAccount != nil {
            let currentAccount = self.accountList.filter({ account in
                return account == selectedAccount
            }).first
            if let currentAccount = currentAccount,
               let index = self.accountList.firstIndex(of: currentAccount) {
                self.accountList.remove(at: index)
                self.accountList.insert(currentAccount, at: 0)
            }
        }
    }

    func getAccountsId() -> [String]? {
        return self.accountAdapter.getAccountList() as? [String]
    }

    func initialAccountsLoading() -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create {} }
            self.loadAccountsFromDaemon()
            completable(.completed)
            return Disposables.create {}
        }
    }

    // MARK: - Methods
    func hasAccounts() -> Bool {
        return !accountList.isEmpty
    }

    private func reloadAccounts() {
        for account in accountList {
            self.updateAccountDetails(account: account)
        }
    }

    func updateCurrentAccount(account: AccountModel) {
        if self.currentAccount != account {
            self.currentAccount = account
        }
    }

    func getAccountProfile(accountId: String) -> Profile? {
        return self.dbManager.accountProfile(for: accountId)
    }

    /**
     Gets an account from the list of accounts handled by the application.

     - Parameter id: the id of the account to get.

     - Returns: the account if found, nil otherwise.
     */
    func getAccount(fromAccountId id: String) -> AccountModel? {
        for account in self.accountList
        where id.compare(account.id) == ComparisonResult.orderedSame {
            return account
        }
        return nil
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

        let accountDetails = self.getVolatileAccountDetails(fromAccountId: id)
        let currentDeviceId = accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountDeviceId))

        for key in knownRingDevices.allKeys {
            if let key = key as? String {
                devices.append(DeviceModel(withDeviceId: key,
                                           deviceName: knownRingDevices.value(forKey: key) as? String,
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

    func updateProfile(accountId: String, displayName: String, avatar: String) {
        accountAdapter.updateProfile(accountId, displayName: displayName, avatar: avatar)
    }

    /**
     Gathers all the initial default details contained by any accounts, Ring or SIP.

     - Returns the details.
     */
    private func getInitialAccountDetails(accountType: String) throws -> [String: String] {
        let details: NSMutableDictionary = accountAdapter.getAccountTemplate(accountType)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AccountCreationError.generic
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
            let defaultDetails = try getInitialAccountDetails(accountType: AccountType.ring.rawValue)
            return defaultDetails
        } catch {
            throw error
        }
    }

    func removeAccount(_ row: Int) {
        if row < accountList.count {
            self.accountAdapter.removeAccount(accountList[row].id)
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
            Single.create(subscribe: { (single) -> Disposable in
                let details = self.getAccountDetails(fromAccountId: accountId)
                details
                    .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.archivePassword),
                         withValue: password)
                self.setAccountDetails(forAccountId: accountId, withDetails: details)
                single(.success(true))
                return Disposables.create {
                }
            })
        let filteredDaemonSignals = self.sharedResponseStream
            .filter { (serviceEvent) -> Bool in
                return serviceEvent.getEventInput(ServiceEventInput.accountId) == accountId &&
                    serviceEvent.eventType == .migrationEnded
            }
        return Observable
            .combineLatest(saveAccount.asObservable(), filteredDaemonSignals.asObservable()) { (_, serviceEvent) -> Bool in
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
        guard let account = self.getAccount(fromAccountId: id) else { return }
        let shouldRemoveFolder = AccountModelHelper.init(withAccount: account).isAccountSip()
        self.dbManager.removeDBForAccount(accountId: id, removeFolder: shouldRemoveFolder)
        self.accountAdapter.removeAccount(id)
        if self.getAccount(fromAccountId: id) == nil {
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

    func removeAccountAndWaitForCompletion(id: String) -> Observable<Bool> {
        let initialAccountCount = self.accountList.count

        let removeAccount: Single<Bool> = Single.create { [weak self] single in
            self?.accountAdapter.removeAccount(id)
            single(.success(true))
            return Disposables.create()
        }

        let accountsChangedSignal = self.sharedResponseStream
            .filter { $0.eventType == .accountsChanged }

        return Observable
            .combineLatest(removeAccount.asObservable(), accountsChangedSignal.asObservable())
            .map { [weak self] _ in
                guard let self = self else { return true }
                let currentAccountCount = self.accountList.count
                return currentAccountCount < initialAccountCount
            }
    }

    func exportToFileWithPassword(accountId: String,
                                  destinationPath: String,
                                  password: String) -> Bool {
        self.accountAdapter.exportToFile(withAccountId: accountId,
                                         destinationPath: destinationPath,
                                         scheme: "password",
                                         password: password)
    }

    // MARK: - AccountAdapterDelegate

    func accountDetailsChanged(accountId: String, details: [String: String]) {
        guard let account = self.getAccount(fromAccountId: accountId) else { return }
        account.updateDetails(dictionary: details)
    }

    func accountVoaltileDetailsChanged(accountId: String, details: [String: String]) {
        guard let account = self.getAccount(fromAccountId: accountId) else { return }
        account.updateVolatileDetails(dictionary: details)
    }

    private let accountListLock = NSLock()

    func accountsChanged() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.handleAccountsChanged()
        }
    }

    func handleAccountsChanged() {
        log.debug("Accounts changed.")

        let currentAccounts = accountList.map { $0.id }

        guard let newAccounts = getAccountsId() else {
            updateAccountList(removedAccounts: currentAccounts, addedAccounts: [])
            notifyAccountsChanged()
            return
        }

        let removedAccounts = currentAccounts.filter { !newAccounts.contains($0) }
        let addedAccounts = newAccounts.filter { !currentAccounts.contains($0) }

        updateAccountList(removedAccounts: removedAccounts, addedAccounts: addedAccounts)
        notifyAccountsChanged()
    }

    private func updateAccountList(removedAccounts: [String], addedAccounts: [String]) {
        let newAccounts = createAndFetchNewAccounts(from: addedAccounts)
        accountListLock.lock()
        defer { accountListLock.unlock() }
        accountList.removeAll { removedAccounts.contains($0.id) }
        for newAccount in newAccounts where !accountList.contains(where: { $0.id == newAccount.id }) {
            accountList.append(newAccount)
        }
    }

    private func createAndFetchNewAccounts(from addedAccounts: [String]) -> [AccountModel] {
        return addedAccounts.map { accountId in
            let newAccount = AccountModel(withAccountId: accountId)
            updateAccountDetails(account: newAccount)
            return newAccount
        }
    }

    private func notifyAccountsChanged() {
        let event = ServiceEvent(withEventType: .accountsChanged)
        self.responseStream.onNext(event)
    }

    private func updateAccountDetails(account: AccountModel) {
        account.details = self.getAccountDetails(fromAccountId: account.id)
        account.volatileDetails = self.getVolatileAccountDetails(fromAccountId: account.id)
        account.devices = getKnownRingDevices(fromAccountId: account.id)
        do {
            let credentialDetails = try self.getAccountCredentials(fromAccountId: account.id)
            account.credentialDetails.removeAll()
            account.credentialDetails.append(contentsOf: credentialDetails)
        } catch {
            log.error("\(error)")
        }
    }

    func setAccountList(_ accounts: [AccountModel]) {
        self.accountList = accounts
    }

    func migrationEnded(for account: String, status: String) {
        var event = ServiceEvent(withEventType: .migrationEnded)
        event.addEventInput(.state, value: status)
        event.addEventInput(.accountId, value: account)
        self.responseStream.onNext(event)
    }

    func registrationStateChanged(for accountId: String, state: String) {
        if let account = self.getAccount(fromAccountId: accountId) {
            /*
             Detect when a new account is generated and keys are ready.
             During generation, an account gets the "INITIALIZING" status.
             When keys are generated, the status changes.
             */
            if let newState = AccountState(rawValue: state) {
                if account.status == .initializing && newState != .initializing {
                    self.updateAccountDetails(account: account)
                    if !newState.isError() {
                        var event = ServiceEvent(withEventType: .accountAdded)
                        event.addEventInput(.accountId, value: account.id)
                        self.responseStream.onNext(event)
                    }
                }
            }
        }
        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: state)
        event.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(event)
        // Check if need account migration.
        if let currentAccount = self.currentAccount,
           let newState = AccountState(rawValue: state),
           newState == .errorNeedMigration,
           accountId == currentAccount.id {
            needMigrateCurrentAccount.onNext(currentAccount.id)
        }
    }

    // MARK: Push Notifications

    func setPushNotificationToken(token: String) {
        self.accountAdapter.setPushNotificationToken(token)
        // Set account details to force the DHT update to use the token.
        for account in accounts {
            // Use details from the daemon, as the token may be set immediately after account creation,
            // meaning the client might not have the updated details.
            guard let accountDetailsDict = accountAdapter.getAccountDetails(account.id) as? [String: String] else { continue }
            let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
            let model = ConfigKeyModel(withKey: .proxyEnabled)
            if accountDetails.get(withConfigKeyModel: model) == "true" {
                self.setAccountDetails(forAccountId: account.id, withDetails: accountDetails)
            }
        }
    }

    func setPushNotificationTopic(topic: String) {
        self.accountAdapter.setPushNotificationTopic(topic)
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
        self.accountAdapter.pushNotificationReceived("", message: notificationData)
    }

    func setAccountsActive(active: Bool) {
        self.accountAdapter.setAccountsActive(active)
    }

    func setAccountActive(active: Bool, accountId: String) {
        self.accountAdapter.setAccountActive(accountId, active: active)
    }
}

// MARK: - Private daemon wrappers
extension AccountsService {
    private func buildAccountFromDaemon(accountId id: String) throws -> AccountModel {
        let accountModel = AccountModel(withAccountId: id)
        accountModel.details = self.getAccountDetails(fromAccountId: id)
        accountModel.volatileDetails = self.getVolatileAccountDetails(fromAccountId: id)
        accountModel.devices = self.getKnownRingDevices(fromAccountId: id)
        do {
            let credentialDetails = try self.getAccountCredentials(fromAccountId: id)
            accountModel.credentialDetails.removeAll()
            accountModel.credentialDetails.append(contentsOf: credentialDetails)
        } catch {
            throw error
        }
        return accountModel
    }
}

// MARK: - configurations settings
extension AccountsService {
    func changePassword(forAccount accountId: String, password: String, newPassword: String) -> Bool {
        return accountAdapter.changeAccountPassword(accountId, oldPassword: password, newPassword: newPassword)
    }

    func setDeviceName(accountId: String, deviceName: String) {
        let property = ConfigKeyModel(withKey: ConfigKey.accountDeviceName)
        self.setAccountProperty(property: property, value: deviceName, accountId: accountId)
    }

    func hasAccountWithProxyEnabled() -> Bool {
        for account in self.accounts {
            let accountDetails = self.getAccountDetails(fromAccountId: account.id)
            if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
                return true
            }
        }
        return false
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
        let details = self.getAccountDetails(fromAccountId: accountId)
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.dhtPublicIn),
                 withValue: (!enable).toString())
        setAccountDetails(forAccountId: accountId, withDetails: details)
        return true
    }

    func enableSRTP(enable: Bool, accountId: String) {
        let newValue = enable ? "sdes" : ""
        let property = ConfigKeyModel(withKey: ConfigKey.srtpKeyExchange)
        self.setAccountProperty(property: property, value: newValue, accountId: accountId)
    }

    func enableAccount(accountId: String, enable: Bool) {
        guard let account = self.getAccount(fromAccountId: accountId) else { return }
        /* The daemon does not send updates for account enable status.
         Therefore, we need to manually set the enable configuration.
         */
        account.setEnable(enable: enable)
        self.accountAdapter.enableAccount(accountId, active: enable)
    }

    func setTurnSettings(accountId: String, server: String, username: String, password: String, realm: String) {
        guard let account = self.getAccount(fromAccountId: accountId),
              let details = account.details else { return }

        let turnSettings: [ConfigKey: String] = [
            .turnServer: server,
            .turnUsername: username,
            .turnPassword: password,
            .turnRealm: realm
        ]

        var detailsToUpdate = [String: String]()

        for (key, value) in turnSettings {
            details.set(withConfigKeyModel: ConfigKeyModel(withKey: key), withValue: value)
            detailsToUpdate[key.rawValue] = value
        }

        let changed = AccountConfigModel(withDetails: detailsToUpdate)
        self.setAccountDetails(forAccountId: accountId, withDetails: changed)
    }

    func switchAccountPropertyTo(state: Bool, accountId: String, property: ConfigKeyModel) {
        guard let account = self.getAccount(fromAccountId: accountId),
              let accountDetails = account.details else { return }
        guard accountDetails.get(withConfigKeyModel: property) != state.toString() else { return }
        self.setAccountProperty(property: property, value: state.toString(), accountId: accountId)
    }

    func setAccountProperty(property: ConfigKeyModel, value: String, accountId: String) {
        guard let account = self.getAccount(fromAccountId: accountId),
              let accountDetails = account.details else { return }
        if accountDetails.get(withConfigKeyModel: property) == value { return }
        accountDetails.set(withConfigKeyModel: property, withValue: value)
        account.details = accountDetails
        let detailsToUpdate = [property.key.rawValue: value]
        let changed = AccountConfigModel(withDetails: detailsToUpdate)
        self.setAccountDetails(forAccountId: accountId, withDetails: changed)
    }
}

// MARK: - devices management
extension AccountsService {

    func knownDevicesChanged(for accountId: String, devices: [String: String]) {
        print("[account]: \(accountId) - knownDevicesChanged, devices count: \(devices.count)")
        guard let account = self.getAccount(fromAccountId: accountId) else { return }

        updateAccountDevices(account: account, devices: devices)

        var event = ServiceEvent(withEventType: .knownDevicesChanged)
        event.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(event)
    }

    private func updateAccountDevices(account: AccountModel, devices: [String: String]) {
        removeOldDevices(currentDevices: &account.devices, devices: devices)
        let currentDeviceId = AccountModelHelper(withAccount: account).getCurrentDevice()
        addOrUpdateDevices(currentDevices: &account.devices, devices: devices, currentDeviceId: currentDeviceId)
    }

    private func removeOldDevices(currentDevices: inout [DeviceModel], devices: [String: String]) {
        currentDevices.removeAll { device in
            !devices.keys.contains(device.deviceId)
        }
    }

    private func addOrUpdateDevices(currentDevices: inout [DeviceModel], devices: [String: String], currentDeviceId: String) {
        for (deviceId, deviceName) in devices {
            if let existingDevice = currentDevices.first(where: { $0.deviceId == deviceId }) {
                // Update device name if it has changed
                if existingDevice.deviceName != deviceName {
                    existingDevice.deviceName = deviceName
                }
            } else {
                // Add new device
                let newDevice = DeviceModel(withDeviceId: deviceId, deviceName: deviceName, isCurrent: deviceId == currentDeviceId)
                currentDevices.append(newDevice)
            }
        }
    }

    func exportOnRing(withPassword password: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(LinkNewDeviceError.unknownError))
                return Disposables.create {}
            }
            let export = self.accountAdapter.export(onRing: self.currentAccount?.id, password: password)
            if export {
                completable(.completed)
            } else {
                completable(.error(LinkNewDeviceError.unknownError))
            }
            return Disposables.create { }
        }
    }

    func exportOnRingEnded(for account: String, state: Int, pin: String) {
        var event = ServiceEvent(withEventType: .exportOnRingEnded)
        event.addEventInput(.id, value: account)
        event.addEventInput(.state, value: state)
        event.addEventInput(.pin, value: pin)
        self.responseStream.onNext(event)
    }

    func deviceRevocationEnded(for accountId: String, state: Int, deviceId: String) {
        guard let account = self.getAccount(fromAccountId: accountId) else { return }
        account.devices.removeAll { device in
            device.deviceId == deviceId
        }

        var event = ServiceEvent(withEventType: .deviceRevocationEnded)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.state, value: state)
        event.addEventInput(.deviceId, value: deviceId)
        self.responseStream.onNext(event)
    }

    func devicesObservable(account: AccountModel) -> Observable<[DeviceModel]> {
        let accountDevices: Observable<[DeviceModel]> = Observable.just(account.devices)
        let newDevice: Observable<[DeviceModel]> = self
            .sharedResponseStream
            .filter({ (event) in
                return event.eventType == ServiceEventType.knownDevicesChanged &&
                    event.getEventInput(ServiceEventInput.accountId) == account.id
            })
            .map({ _ in
                return account.devices
            })
        return accountDevices.concat(newDevice)
    }
}

// MARK: - account creation
extension AccountsService {
    /// Adds a new Jami account.
    ///
    /// - Parameters:
    ///   - username: an optional username for the new account
    ///   - password: optional password for the new account
    ///   - pin: pin to link another account
    ///   - profileName: optional profile name for the new account
    /// - Returns: an observable of an account id: the created one
    func addJamiAccount(username: String?,
                        password: String,
                        pin: String,
                        arhivePath: String,
                        profileName: String) -> Observable<String> {
        // Observable for initiating account creation
        let accountCreationObservable = createJamiAccount(username: username,
                                                          password: password,
                                                          pin: pin,
                                                          arhivePath: arhivePath,
                                                          profileName: profileName)

        return handleAccountCreation(isJams: false, createAccount: accountCreationObservable)
    }

    /// connect to jams server
    ///
    /// - Parameters
    ///   - username
    ///   - password
    ///   - serverUri
    /// - Returns: an observable of an account id: the created one

    func connectToAccountManager(username: String, password: String, serverUri: String) -> Observable<String> {
        // Observable for initiating account creation
        let accountCreationObservable = createJamsAccount(username: username,
                                                          password: password,
                                                          serverUri: serverUri)
        return handleAccountCreation(isJams: true, createAccount: accountCreationObservable)
    }

    func addSipAccount(userName: String,
                       password: String,
                       sipServer: String) -> Bool {
        do {
            var accountDetails = try self.getInitialAccountDetails(accountType: AccountType.sip.rawValue)
            accountDetails.updateValue(userName, forKey: ConfigKey.accountUsername.rawValue)
            accountDetails.updateValue(sipServer, forKey: ConfigKey.accountHostname.rawValue)
            accountDetails.updateValue(password, forKey: ConfigKey.accountPassword.rawValue)
            guard let account = self.accountAdapter.addAccount(accountDetails) else { return false }
            _ = try self.dbManager.createDatabaseForAccount(accountId: account, createFolder: true)
            guard let newAccount = self.getAccount(fromAccountId: account) else { return false }
            let accountUri = AccountModelHelper.init(withAccount: newAccount).uri ?? ""
            _ = self.dbManager.saveAccountProfile(alias: nil, photo: nil, accountId: account, accountURI: accountUri)
            self.currentAccount = newAccount
            UserDefaults.standard.set(account, forKey: self.selectedAccountID)
            return true
        } catch {
            return false
        }
    }

    private func handleAccountCreation(isJams: Bool,
                                       createAccount: Single<String>) -> Observable<String> {
        // Observable for receiving account state updates
        let creationStatus = accountCreationStatusObservable()

        return Observable
            .combineLatest(createAccount.asObservable(),
                           creationStatus.asObservable())
            .filter { accountId, creationStatus in
                accountId == creationStatus.accountId
            }
            .map { accountId, creationStatus in
                (accountId, creationStatus.errorCode)
            }
            .take(1)
            .flatMap { [weak self] (accountId, errorCode) -> Observable<String> in
                guard let self = self else {
                    return .error(AccountCreationError.unknown)
                }
                if let error = self.completeCreation(accountId: accountId,
                                                     isJams: isJams,
                                                     errorCode: errorCode) {
                    return .error(error)
                } else {
                    return Observable.just(accountId)
                }
            }
    }

    private func completeCreation(accountId: String,
                                  isJams: Bool,
                                  errorCode: String?) -> Error? {
        if let errorCode = errorCode, let status = AccountState(rawValue: errorCode) {
            if status.isNetworkError() {
                return AccountCreationError.network
            } else {
                let error = isJams ? AccountCreationError.wrongCredentials : AccountCreationError.unknown
                return error
            }
        }

        do {
            // Create a database for the new account
            guard try dbManager.createDatabaseForAccount(accountId: accountId) else {
                return AccountCreationError.unknown
            }
        } catch {
            return error
        }

        // Retrieve and set the current account
        if let account = getAccount(fromAccountId: accountId) {
            currentAccount = account
        }
        UserDefaults.standard.set(accountId, forKey: selectedAccountID)
        return nil
    }

    private func createJamiAccount(username: String?,
                                   password: String,
                                   pin: String,
                                   arhivePath: String,
                                   profileName: String) -> Single<String> {
        return Single.deferred {
            return Single.create { single in
                do {
                    var details = try self.getJamiInitialAccountDetails()
                    if let username = username {
                        details[ConfigKey.accountRegisteredName.rawValue] = username
                    }
                    if !password.isEmpty {
                        details[ConfigKey.archivePassword.rawValue] = password
                    }
                    if !pin.isEmpty {
                        details[ConfigKey.archivePIN.rawValue] = pin
                    }
                    if !arhivePath.isEmpty {
                        details[ConfigKey.archivePath.rawValue] = arhivePath
                    }
                    if !profileName.isEmpty {
                        details[ConfigKey.displayName.rawValue] = profileName
                    }
                    details[ConfigKey.proxyEnabled.rawValue] = "true"
                    if let testServer = TestEnvironment.shared.nameServerURI {
                        details[ConfigKey.ringNsURI.rawValue] = testServer
                    }
                    guard let accountId = self.accountAdapter.addAccount(details) else {
                        throw AccountCreationError.unknown
                    }
                    single(.success(accountId))
                } catch {
                    single(.failure(error))
                }
                return Disposables.create()
            }
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    private func createJamsAccount(username: String, password: String, serverUri: String) -> Single<String> {
        return Single.create { single in
            do {
                var details = try self.getJamiInitialAccountDetails()
                details.updateValue(username, forKey: ConfigKey.managerUsername.rawValue)
                details.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                details.updateValue("true", forKey: ConfigKey.proxyEnabled.rawValue)
                details.updateValue(serverUri, forKey: ConfigKey.managerUri.rawValue)
                guard let accountId = self.accountAdapter.addAccount(details) else {
                    throw AccountCreationError.wrongCredentials
                }
                single(.success(accountId))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }

    struct AccountCreationResult {
        var accountId: String
        var errorCode: String?
    }

    func accountCreationStatusObservable() -> Observable<AccountCreationResult> {
        // Check account added signal and errors.
        return self.sharedResponseStream
            .filter { serviceEvent in
                return serviceEvent.eventType == .accountAdded || serviceEvent.eventType == .registrationStateChanged
            }
            .compactMap { event -> AccountCreationResult? in
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId) else {
                    return nil
                }

                if event.eventType == .accountAdded {
                    return AccountCreationResult(accountId: accountId)
                }

                guard let stateStr: String = event.getEventInput(ServiceEventInput.registrationState),
                      let state = AccountState(rawValue: stateStr) else {
                    return nil
                }
                if state.isError() {
                    return AccountCreationResult(accountId: accountId, errorCode: stateStr)
                }
                return nil
            }
            .compactMap { response in
                return !response.accountId.isEmpty ? response : nil
            }
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }
}
