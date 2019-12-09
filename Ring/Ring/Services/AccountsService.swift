/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Authors: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *           Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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
import RealmSwift
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

    /**
     Used to register the service to daemon events, injected by constructor.
     */
    fileprivate let accountAdapter: AccountAdapter

    /**
     Fileprivate Accounts list.
     Can be used for all the operations, but won't be accessed from outside this file.

     - SeeAlso: `accounts`
     */
    fileprivate var accountList: [AccountModel]

    fileprivate let disposeBag = DisposeBag()

    /**
     PublishSubject forwarding AccountRxEvent events.
     This stream is used strictly inside this service.
     External observers should use the public shared responseStream.

     - SeeAlso: `ServiceEvent`
     - SeeAlso: `sharedResponseStream`
     */
    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    let dbManager: DBManager

    // MARK: - Public members
    /**
     Accounts list public interface.
     Can be used to access by constant the list of accounts.
     */
    var accounts: [AccountModel] {
        set {
            accountList = newValue
        }
        get {
            let lAccounts = accountList
            return lAccounts
        }
    }

    var accountsObservable = Variable<[AccountModel]>([AccountModel]())

    let currentAccountChanged = PublishSubject<AccountModel?>()

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
            //Get the current account from account list if already exists
            let currentAccount = self.accountList.filter({ account in
                return account == newValue
            }).first

            guard let newAccount = newValue else { return }

            //If current account already exists in the list, move it to the first index
            if let currentAccount = currentAccount,
                let index = self.accountList.firstIndex(of: currentAccount) {
                self.accountList.remove(at: index)
                self.accountList.insert(currentAccount, at: 0)
            } else {
                self.accountList.append(newAccount)
            }
            currentAccountChanged.onNext(currentAccount)
        }
    }

    init(withAccountAdapter accountAdapter: AccountAdapter, dbManager: DBManager) {
        self.accountList = []

        self.responseStream.disposed(by: disposeBag)

        //~ Create a shared stream based on the responseStream one.
        self.sharedResponseStream = responseStream.share()

        self.accountAdapter = accountAdapter
        self.dbManager = dbManager
        //~ Registering to the accountAdatpter with self as delegate in order to receive delegation
        //~ callbacks.
        AccountAdapter.delegate = self
    }

    fileprivate func loadAccountsFromDaemon() {
        let selectedAccount = self.currentAccount
        self.accountList.removeAll()
        for accountId in accountAdapter.getAccountList() {
            if  let id = accountId as? String {
                self.accountList.append(AccountModel(withAccountId: id))
            }
        }
        reloadAccounts()
        accountsObservable.value = self.accountList
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

    fileprivate func loadDatabases() -> Bool {
        for account in accountList {
            if dbManager.isNeedMigrationToAccountDB(accountId: account.id) {
                do {
                    if let jamiId = AccountModelHelper
                        .init(withAccount: account).ringId {
                        try dbManager.migrateToAccountDB(accountId: account.id,
                                                         jamiId: jamiId)
                    }
                } catch { return false}
            } else {
                do {
                    // return false if could not open database connection
                    if try !dbManager.createDatabaseForAccount(accountId: account.id) {
                        return false
                    }
                    //if tables already exist an exeption will be thrown
                } catch { }
            }
        }
        return true
    }

    func initialAccountsLoading() -> Completable {
        return Completable.create { [unowned self] completable in
            self.loadAccountsFromDaemon()
            if self.accountList.isEmpty {
                completable(.completed)
            }
            if self.loadDatabases() {
                completable(.completed)
            } else {
                completable(.error(DataAccessError.databaseError))
            }
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

    fileprivate func reloadAccounts() {
        for account in accountList {
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
    }

    func getAccountProfile(accountId: String) -> AccountProfile? {
        return self.dbManager.accountProfile(for: accountId)
    }

    /// Adds a new Ring account.
    ///
    /// - Parameters:
    ///   - username: an optional username for the new account
    ///   - password: the required password for the new account
    /// - Returns: an observable of an AccountModel: the created one
    func addRingAccount(username: String?, password: String, enable: Bool) -> Observable<AccountModel> {
        //~ Single asking the daemon to add a new account with the associated metadata
        var newAccountId = ""
        let createAccountSingle: Single<AccountModel> = Single.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.getRingInitialAccountDetails()
                if let username = username {
                    ringDetails.updateValue(username, forKey: ConfigKey.accountRegisteredName.rawValue)
                }
                if !password.isEmpty {
                    ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                }
                ringDetails.updateValue(enable.toString(), forKey: ConfigKey.proxyEnabled.rawValue)
                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AddAccountError.unknownError
                }
                newAccountId = accountId
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })

        //~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = self.sharedResponseStream
            .filter { (serviceEvent) -> Bool in
                if serviceEvent.getEventInput(ServiceEventInput.accountId) != newAccountId {return false}
                if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                    throw AccountCreationError.generic
                } else if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    throw AccountCreationError.network
                }
                let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType.registrationStateChanged
                let isRegistered = serviceEvent.getEventInput(ServiceEventInput.registrationState) == Registered
                let notRegistered = serviceEvent.getEventInput(ServiceEventInput.registrationState) == Unregistered
                return isRegistrationStateChanged && (isRegistered || notRegistered)
        }

        //~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(createAccountSingle.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, serviceEvent) -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId) else {
                    throw AddAccountError.unknownError
                }
                // create database for account and save account profile
                if try !self.dbManager.createDatabaseForAccount(accountId: accountModel.id) {
                    throw AddAccountError.unknownError
                }
                _ = self.dbManager.saveAccountProfile(alias: nil, photo: nil, accountId: accountModel.id)
                self.loadAccountsFromDaemon()
                return accountModel
            }.take(1)
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                self.currentAccount = accountModel
                UserDefaults.standard.set(accountModel.id, forKey: self.selectedAccountID)
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            })
    }

    func addSipAccount(userName: String,
                       password: String,
                       sipServer: String,
                       port: String) -> Bool {
        do {
            var accountDetails = try self.getInitialAccountDetails(accountType: AccountType.sip.rawValue)
            accountDetails.updateValue(userName, forKey: ConfigKey.accountUsername.rawValue)
            accountDetails.updateValue(sipServer, forKey: ConfigKey.accountHostname.rawValue)
            accountDetails.updateValue(password, forKey: ConfigKey.accountPassword.rawValue)
            if !port.isEmpty {
                accountDetails.updateValue(password, forKey: ConfigKey.localPort.rawValue)
            }
            guard let account = self.accountAdapter.addAccount(accountDetails) else {return false}
            _ = try self.dbManager.createDatabaseForAccount(accountId: account)
            _ = self.dbManager.saveAccountProfile(alias: nil, photo: nil, accountId: account)
            self.loadAccountsFromDaemon()
            let newAccount = self.getAccount(fromAccountId: account)
            self.currentAccount = newAccount
            UserDefaults.standard.set(account, forKey: self.selectedAccountID)
            return true
        } catch {
            return false
        }
    }

    func linkToRingAccount(withPin pin: String, password: String, enable: Bool) -> Observable<AccountModel> {
        var newAccountId = ""
        //~ Single asking the daemon to add a new account with the associated metadata
        let createAccountSingle: Single<AccountModel> = Single.create(subscribe: { (single) -> Disposable in
            do {
                var ringDetails = try self.getRingInitialAccountDetails()
                ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
                ringDetails.updateValue(pin, forKey: ConfigKey.archivePIN.rawValue)
                ringDetails.updateValue(enable.toString(), forKey: ConfigKey.proxyEnabled.rawValue)
                guard let accountId = self.accountAdapter.addAccount(ringDetails) else {
                    throw AddAccountError.unknownError
                }
                newAccountId = accountId
                let account = try self.buildAccountFromDaemon(accountId: accountId)
                single(.success(account))
            } catch {
                single(.error(error))
            }
            return Disposables.create {
            }
        })
        //~ Filter the daemon signals to isolate the "account created" one.
        let filteredDaemonSignals = self.sharedResponseStream.filter { (serviceEvent) -> Bool in
            if serviceEvent.getEventInput(ServiceEventInput.accountId) != newAccountId {return false}
            if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                throw AccountCreationError.linkError
            } else if serviceEvent.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                throw AccountCreationError.network
            }
            let isRegistrationStateChanged = serviceEvent.eventType == ServiceEventType.registrationStateChanged
            let isRegistered = serviceEvent.getEventInput(ServiceEventInput.registrationState) == Registered
            return isRegistrationStateChanged && isRegistered
        }
        //~ Make sure that we have the correct account added in the daemon, and return it.
        return Observable
            .combineLatest(createAccountSingle.asObservable(), filteredDaemonSignals.asObservable()) { (accountModel, serviceEvent) -> AccountModel in
                guard accountModel.id == serviceEvent.getEventInput(ServiceEventInput.accountId) else {
                    throw AddAccountError.unknownError
                }
                // create database for account and save account profile
                if try !self.dbManager.createDatabaseForAccount(accountId: accountModel.id) {
                    throw AddAccountError.unknownError
                }
                _ = self.dbManager.saveAccountProfile(alias: nil, photo: nil, accountId: accountModel.id)
                self.loadAccountsFromDaemon()
                return accountModel
            }.take(1)
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                self.currentAccount = accountModel
                UserDefaults.standard.set(accountModel.id, forKey: self.selectedAccountID)
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            })
    }

    func setDetails(forAccountId accountId: String) {
//        if let codecs = self.accountAdapter.getActiveCodecsList(accountId) as? [Int] {
//                   for codec in codecs {
//                    if let codecDetails = self.accountAdapter.getCodecDetails(accountId, codecID: codec as NSNumber) as? [String: String] {
//                        if let codecName = codecDetails[ConfigKey.codecName.rawValue], codecName == "H264" {
//                           self.accountAdapter.setActiveCodecsList(accountId, codecs: [codec])
//                       }
//                     //  case codecType = "CodecInfo.type"
//                      //   case codecName = "CodecInfo.name"
//                       print(codecDetails)
//                   }
//            }
//               }
        let details = self.getAccountDetails(fromAccountId: accountId)
        var filename = "default.wav"
        if #available(iOS 10.0, *) {
            filename = ""
        }
        if details
            .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.ringtonePath)) == filename &&
            details
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.dhtPeerDiscovery)) == "false" &&
            details
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountPeerDiscovery)) == "false" &&
            details
                .get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountPublish)) == "false" {
            return
        }
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.ringtonePath),
                 withValue: filename)
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.dhtPeerDiscovery),
                 withValue: "false")
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountPeerDiscovery),
                 withValue: "false")
        details
            .set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountPublish),
                 withValue: "false")
        setAccountDetails(forAccountId: accountId, withDetails: details)
    }

    /**
     Gets an account from the list of accounts handled by the application.

     - Parameter id: the id of the account to get.

     - Returns: the account if found, nil otherwise.
     */
    func getAccount(fromAccountId id: String) -> AccountModel? {
        for account in self.accountList {
            if id.compare(account.id) == ComparisonResult.orderedSame {
                return account
            }
        }
        return nil
    }

    /// Gets the account from the daemon responding to the given id.
    ///
    /// - Parameter id: the id of the account to get.
    /// - Returns: a single of an AccountModel
    func getAccountFromDaemon(fromAccountId id: String) -> Single<AccountModel> {
        return self.loadAccounts().map({ (accountModels) -> AccountModel in
            guard let account = accountModels.filter({ (accountModel) -> Bool in
                return id == accountModel.id
            }).first else {
                throw AddAccountError.noAccountFound
            }
            return account
        })
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

        let accountDetails = self.getAccountDetails(fromAccountId: id)
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

    /**
     Gathers all the initial default details contained by any accounts, Ring or SIP.

     - Returns the details.
     */
    fileprivate func getInitialAccountDetails(accountType: String) throws -> [String: String] {
        let details: NSMutableDictionary = accountAdapter.getAccountTemplate(accountType)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AddAccountError.templateNotConform
        }
        accountDetails!.updateValue("oversip", forKey: ConfigKey.accountDTMFType.rawValue)
        accountDetails!.updateValue("true", forKey: ConfigKey.videoEnabled.rawValue)
        accountDetails!.updateValue("default.wav", forKey: ConfigKey.ringtonePath.rawValue)
        accountDetails!.updateValue(accountType, forKey: ConfigKey.accountType.rawValue)
        accountDetails!.updateValue("true", forKey: ConfigKey.accountUpnpEnabled.rawValue)
        if accountType == AccountType.ring.rawValue {
            accountDetails!.updateValue("false", forKey: ConfigKey.dhtPeerDiscovery.rawValue)
            accountDetails!.updateValue("false", forKey: ConfigKey.accountPeerDiscovery.rawValue)
            accountDetails!.updateValue("false", forKey: ConfigKey.accountPublish.rawValue)
        }
        return accountDetails!
    }

    /**
     Gathers all the initial default details contained in a Ring accounts.

     - Returns the details.
     */
    fileprivate func getRingInitialAccountDetails() throws -> [String: String] {
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

    func removeAccount(id: String) {
        if self.getAccount(fromAccountId: id) == nil {return}
        self.accountAdapter.removeAccount(id)
        self.loadAccountsFromDaemon()
        if self.getAccount(fromAccountId: id) == nil {
            self.dbManager.removeDBForAccount(accountId: id)
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
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
        self.responseStream.onNext(event)
    }

    func registrationStateChanged(with response: RegistrationResponse) {
        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
        event.addEventInput(.accountId, value: response.accountId)
        self.responseStream.onNext(event)
        if let account = self.getAccount(fromAccountId: response.accountId) {
            account.volatileDetails = self.getVolatileAccountDetails(fromAccountId: response.accountId)
        }
    }

    func knownDevicesChanged(for account: String, devices: [String: String]) {
        reloadAccounts()
        var event = ServiceEvent(withEventType: .knownDevicesChanged)
        event.addEventInput(.accountId, value: account)
        self.responseStream.onNext(event)
    }

    func exportOnRing(withPassword password: String)
        -> Completable {
            return Completable.create { [unowned self] completable in
                let export =  self.accountAdapter.export(onRing: self.currentAccount?.id, password: password)
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

    func deviceRevocationEnded(for account: String, state: Int, deviceId: String) {
        var event = ServiceEvent(withEventType: .deviceRevocationEnded)
        event.addEventInput(.id, value: account)
        event.addEventInput(.state, value: state)
        event.addEventInput(.deviceId, value: deviceId)
        self.responseStream.onNext(event)
    }

    // MARK: Push Notifications

    func setPushNotificationToken(token: String) {
        self.accountAdapter.setPushNotificationToken(token)
    }

    func pushNotificationReceived(data: [AnyHashable: Any]) {
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

    func getCurrentProxyState(accountID: String) -> Bool {
        var proxyEnabled = false
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
            proxyEnabled = true
        }
        return proxyEnabled
    }

    func savePushToken(token: String) {
        for account in accounts {
            let accountDetails = self.getAccountDetails(fromAccountId: account.id)
            accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken), withValue: token)
            self.setAccountDetails(forAccountId: account.id, withDetails: accountDetails)
        }
    }

    func proxyEnabled(accountID: String) -> Variable<Bool> {
        let variable = Variable<Bool>(getCurrentProxyState(accountID: accountID))
        self.sharedResponseStream
            .filter({ event -> Bool in
                if let accountId: String = event.getEventInput(.accountId) {
                    return event.eventType == ServiceEventType.proxyEnabled
                        && accountId == accountID
                }
                return false
            }).subscribe(onNext: { (event) in
                if let state: Bool = event.getEventInput(.state) {
                    variable.value = state
                }
            }).disposed(by: self.disposeBag)
        return variable
    }

    func changeProxyStatus(accountID: String, enable: Bool) {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) != enable.toString() {
            accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled), withValue: enable.toString())
            self.setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
            var event = ServiceEvent(withEventType: .proxyEnabled)
            event.addEventInput(.state, value: enable)
            event.addEventInput(.accountId, value: accountID)
            self.responseStream.onNext(event)
        }
    }

    func proxyEnabled() -> Bool {
        for account in self.accounts {
            let accountDetails = self.getAccountDetails(fromAccountId: account.id)
            if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
                return true
            }
        }
        return false
    }

    func enableAccount(enable: Bool, accountId: String) {
        let accountDetails = self.getAccountDetails(fromAccountId: accountId)
        if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountEnable)) != enable.toString() {
            accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.accountEnable), withValue: enable.toString())
            self.setAccountDetails(forAccountId: accountId, withDetails: accountDetails)
        }
    }

    // MARK: - observable account data

    func devicesObservable(account: AccountModel) -> Observable<[DeviceModel]> {
        let accountDevices: Observable<[DeviceModel]> = Observable.just(account.devices)
        let newDevice: Observable<[DeviceModel]> = self
            .sharedResponseStream
            .filter({ (event) in
                return event.eventType == ServiceEventType.knownDevicesChanged &&
                    event.getEventInput(ServiceEventInput.accountId) == account.id
            }).map({ _ in
                return account.devices
            })
        return accountDevices.concat(newDevice)
    }
}

// MARK: - Private daemon wrappers
extension AccountsService {

    fileprivate func buildAccountFromDaemon(accountId id: String) throws -> AccountModel {
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
