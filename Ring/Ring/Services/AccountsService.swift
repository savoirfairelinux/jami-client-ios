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

    private let defaultProxyAddress = "dhtproxy.ring.cx:80"

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

            //If current account already exists in the list, move it to the first index
            if let currentAccount = currentAccount {
                let index = self.accountList.index(of: currentAccount)
                self.accountList.remove(at: index!)
                self.accountList.insert(currentAccount, at: 0)
            } else {
                self.accountList.append(newValue!)
            }
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
        for accountId in accountAdapter.getAccountList() {
            if  let id = accountId as? String {
                self.accountList.append(AccountModel(withAccountId: id))
            }
        }
        reloadAccounts()
    }

    fileprivate func loadDatabases() -> Bool {
        for account in accountList {
            if dbManager.isNeedMigrationToAccountDB(accountId: account.id) {
                do {
                    try dbManager.migrateToAccountDB(accountId: account.id,
                                                     jamiId: AccountModelHelper
                                                        .init(withAccount: account).ringId!)
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

    /// Adds a new Ring account.
    ///
    /// - Parameters:
    ///   - username: an optional username for the new account
    ///   - password: the required password for the new account
    /// - Returns: an observable of an AccountModel: the created one
    func addRingAccount(username: String?, password: String, enable: Bool) -> Observable<AccountModel> {
        //~ Single asking the daemon to add a new account with the associated metadata
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
                return accountModel
            }.take(1)
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            })
    }

    func linkToRingAccount(withPin pin: String, password: String, enable: Bool) -> Observable<AccountModel> {
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
                return accountModel
            }.take(1)
            .flatMap({ [unowned self] (accountModel) -> Observable<AccountModel> in
                return self.getAccountFromDaemon(fromAccountId: accountModel.id).asObservable()
            })
    }

    func setRingtonePath(forAccountId accountId: String) {
        let details = self.getAccountDetails(fromAccountId: accountId)
        let ringtonePath = Bundle.main.url(forResource: "default", withExtension: "wav")!
        details.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.ringtonePath), withValue: (ringtonePath.path))
        setAccountDetails(forAccountId: accountId, withDetails: details)
    }

    /**
     Entry point to create a brand-new SIP account.

     Not supported yet.
     */
    fileprivate func addSipAccount() {
        log.info("Not supported yet")
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
        let knownRingDevices = accountAdapter.getKnownRingDevices(id)! as NSDictionary

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
    fileprivate func getInitialAccountDetails() throws -> [String: String] {
        let details: NSMutableDictionary = accountAdapter.getAccountTemplate(AccountType.ring.rawValue)
        var accountDetails = details as NSDictionary? as? [String: String] ?? nil
        if accountDetails == nil {
            throw AddAccountError.templateNotConform
        }
        accountDetails!.updateValue("sipinfo", forKey: ConfigKey.accountDTMFType.rawValue)
        return accountDetails!
    }

    /**
     Gathers all the initial default details contained in a Ring accounts.

     - Returns the details.
     */
    fileprivate func getRingInitialAccountDetails() throws -> [String: String] {
        do {
            var defaultDetails = try getInitialAccountDetails()
            defaultDetails.updateValue("true", forKey: ConfigKey.accountUpnpEnabled.rawValue)
            defaultDetails.updateValue("true", forKey: ConfigKey.videoEnabled.rawValue)
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
    }

    func knownDevicesChanged(for account: String, devices: [String: String]) {
        reloadAccounts()
        let changedAccount = getAccount(fromAccountId: account)
        if let changedAccount = changedAccount {
            let accountHelper = AccountModelHelper(withAccount: changedAccount)
            if let  uri = accountHelper.ringId {
                var event = ServiceEvent(withEventType: .knownDevicesChanged)
                event.addEventInput(.uri, value: uri)
                self.responseStream.onNext(event)
            }
        }
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

    // MARK: DHT Proxy

    func enableProxy(accountID: String, enable: Bool, proxyAddress: String) {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled), withValue: enable.toString())
        if enable {
            accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyServer), withValue: proxyAddress)
        }
        self.setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
        var event = ServiceEvent(withEventType: .proxyEnabled)
        event.addEventInput(.state, value: enable)
        event.addEventInput(.accountId, value: accountID)
        if enable {
            event.addEventInput(.proxyAddress, value: proxyAddress)
        }
        self.responseStream.onNext(event)
    }

    func getCurrentProxyState(accountID: String) -> Bool {
        var proxyEnabled = false
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        if accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled)) == "true" {
            proxyEnabled = true
        }
        return proxyEnabled
    }

    func proxyAddress(accountID: String) -> Variable<String> {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        var proxyAddress = accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyServer))
        if proxyAddress.isEmpty {
            proxyAddress = defaultProxyAddress
        }
        let variable = Variable<String>(proxyAddress)
        self.sharedResponseStream
            .filter({ event -> Bool in
                if let accountId: String = event.getEventInput(.accountId) {
                    return event.eventType == ServiceEventType.proxyEnabled
                        && accountId == accountID
                }
                return false
            }).subscribe(onNext: { (event) in
                if let address: String = event.getEventInput(.proxyAddress) {
                    variable.value = address
                }
            }).disposed(by: self.disposeBag)
        return variable
    }

    func pushNotificationsEnabled(accountID: String) -> Variable<Bool> {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        let notificationsEnabled = accountDetails.get(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken)).isEmpty ? false : true
        let variable = Variable<Bool>(notificationsEnabled)
        self.sharedResponseStream
            .filter({ event -> Bool in
                if let accountId: String = event.getEventInput(.accountId) {
                    return event.eventType == ServiceEventType.notificationEnabled
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

    func changeProxyAvailability(accountID: String, enable: Bool, proxyAddress: String) {
        let proxyState = self.getCurrentProxyState(accountID: accountID)

        if proxyState == enable {
            return
        }
        self.enableProxy(accountID: accountID, enable: enable, proxyAddress: proxyAddress)

        //disable push notifications
        if !enable {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue), object: nil)
        }
    }

    func updateProxyAddress(address: String, accountID: String) {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyServer), withValue: address)
        self.setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
        var event = ServiceEvent(withEventType: .proxyEnabled)
        event.addEventInput(.accountId, value: accountID)
        event.addEventInput(.proxyAddress, value: address)
        self.responseStream.onNext(event)
    }

    func updatePushTokenForCurrentAccount(token: String) {
        guard let account = self.currentAccount else {
            return
        }
        let accountDetails = self.getAccountDetails(fromAccountId: account.id)
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken), withValue: token)
        self.setAccountDetails(forAccountId: account.id, withDetails: accountDetails)
        var event = ServiceEvent(withEventType: .notificationEnabled)
        let notificationsEnabled = token.isEmpty ? false : true
        event.addEventInput(.accountId, value: account.id)
        event.addEventInput(.state, value: notificationsEnabled)
        self.responseStream.onNext(event)
    }

    // MARK: - observable account data

    func devicesObservable(account: AccountModel) -> Observable<[DeviceModel]> {
        let accountHelper = AccountModelHelper(withAccount: account)
        let uri = accountHelper.ringId
        let accountDevices = Observable.from(optional: account.devices)
        let newDevice: Observable<[DeviceModel]> = self
            .sharedResponseStream
            .filter({ (event) in
                return event.eventType == ServiceEventType.knownDevicesChanged &&
                    event.getEventInput(ServiceEventInput.uri) == uri
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
