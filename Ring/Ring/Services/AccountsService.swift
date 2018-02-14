/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Authors: Edric Ladent-Milaret <edric.ladent-milaret@savoirfairelinux.com>
 *           Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

enum AddAccountError: Error {
    case templateNotConform
    case unknownError
}

enum NotificationName: String {
    case enablePushNotifications
    case disablePushNotifications
    case answerCallFromNotifications
    case refuseCallFromNotifications
}

class AccountsService: AccountAdapterDelegate {
    // MARK: Private members

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

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
    let dbManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper())

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

    init(withAccountAdapter accountAdapter: AccountAdapter) {
        self.accountList = []

        self.responseStream.disposed(by: disposeBag)

        //~ Create a shared stream based on the responseStream one.
        self.sharedResponseStream = responseStream.share()

        self.accountAdapter = accountAdapter
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

    /**
     Entry point to create a brand-new Ring account.

     - Parameter username: the username chosen by the user, if any
     - Parameter password: the password chosen by the user

     */
    func addRingAccount(withUsername username: String?, password: String) {
        do {
            var ringDetails = try self.getRingInitialAccountDetails()
            if username != nil {
                ringDetails.updateValue(username!, forKey: ConfigKey.accountRegisteredName.rawValue)
            }
            ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
            let accountId = self.accountAdapter.addAccount(ringDetails)
            guard accountId != nil else {
                throw AddAccountError.unknownError
            }

            var account = self.getAccount(fromAccountId: accountId!)

            if account == nil {
                let details = self.getAccountDetails(fromAccountId: accountId!)
                let volatileDetails = self.getVolatileAccountDetails(fromAccountId: accountId!)
                let credentials = try self.getAccountCredentials(fromAccountId: accountId!)
                let devices = getKnownRingDevices(fromAccountId: accountId!)

                account = try AccountModel(withAccountId: accountId!,
                                           details: details,
                                           volatileDetails: volatileDetails,
                                           credentials: credentials,
                                           devices: devices)

                let accountModelHelper = AccountModelHelper(withAccount: account!)
                var accountAddedEvent = ServiceEvent(withEventType: .accountAdded)
                accountAddedEvent.addEventInput(.id, value: account?.id)
                accountAddedEvent.addEventInput(.state, value: accountModelHelper.getRegistrationState())
                self.responseStream.onNext(accountAddedEvent)
            }

            self.currentAccount = account
        } catch {
            self.responseStream.onError(error)
        }
    }

    func linkToRingAccount(withPin pin: String, password: String) {
        do {
            var ringDetails = try self.getRingInitialAccountDetails()
            ringDetails.updateValue(password, forKey: ConfigKey.archivePassword.rawValue)
            ringDetails.updateValue(pin, forKey: ConfigKey.archivePIN.rawValue)
            let accountId = self.accountAdapter.addAccount(ringDetails)
            guard accountId != nil else {
                throw AddAccountError.unknownError
            }

            var account = self.getAccount(fromAccountId: accountId!)

            if account == nil {
                let details = self.getAccountDetails(fromAccountId: accountId!)
                let volatileDetails = self.getVolatileAccountDetails(fromAccountId: accountId!)
                let credentials = try self.getAccountCredentials(fromAccountId: accountId!)
                let devices = getKnownRingDevices(fromAccountId: accountId!)

                account = try AccountModel(withAccountId: accountId!,
                                           details: details,
                                           volatileDetails: volatileDetails,
                                           credentials: credentials,
                                           devices: devices)

                let accountModelHelper = AccountModelHelper(withAccount: account!)
                var accountAddedEvent = ServiceEvent(withEventType: .accountAdded)
                accountAddedEvent.addEventInput(.id, value: account?.id)
                accountAddedEvent.addEventInput(.state, value: accountModelHelper.getRegistrationState())
                self.responseStream.onNext(accountAddedEvent)
            }
            self.currentAccount = account
        } catch {
            self.responseStream.onError(error)
        }
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

        for key in knownRingDevices.allKeys {
            if let key = key as? String {
                devices.append(DeviceModel(withDeviceId: key, deviceName: knownRingDevices.value(forKey: key) as? String))
            }
        }

        return devices
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
            defaultDetails.updateValue("Ring", forKey: ConfigKey.accountAlias.rawValue)
            defaultDetails.updateValue("bootstrap.ring.cx", forKey: ConfigKey.accountHostname.rawValue)
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
        log.debug("RegistrationStateChanged.")
        reloadAccounts()
        if let state = response.state, state == Registered {
            if let account = self.currentAccount {
                if let ringID = AccountModelHelper(withAccount: account).ringId {
                    dbManager.profileObservable(for: ringID, createIfNotExists: true)
                        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                        .subscribe()
                        .disposed(by: self.disposeBag)
                }
            }
        }
        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
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
        let changedAccount = getAccount(fromAccountId: account)
        if let changedAccount = changedAccount {
            let accountHelper = AccountModelHelper(withAccount: changedAccount)
            if let  uri = accountHelper.ringId {
                var event = ServiceEvent(withEventType: .exportOnRingEnded)
                event.addEventInput(.uri, value: uri)
                event.addEventInput(.state, value: state)
                event.addEventInput(.pin, value: pin)
                self.responseStream.onNext(event)
            }
        }
    }

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

    func enableProxy(accountID: String, enable: Bool) {
        let accountDetails = self.getAccountDetails(fromAccountId: accountID)
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyEnabled), withValue: enable.toString())
        let proxy = enable ? "192.168.51.6:8000" : ""
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.proxyServer), withValue: proxy)
        self.setAccountDetails(forAccountId: accountID, withDetails: accountDetails)
        var event = ServiceEvent(withEventType: .proxyEnabled)
        event.addEventInput(.state, value: enable)
        event.addEventInput(.accountId, value: accountID)
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

    func proxyEnabled(accountID: String) -> Observable<Bool> {
        let proxyChanged: Observable<Bool> = self.sharedResponseStream
            .filter({ event in
                if let accountId: String = event.getEventInput(.accountId) {
                    return event.eventType == ServiceEventType.proxyEnabled
                        && accountId == accountID
                }
                return false
            }).map({ event in
                if let state: Bool = event.getEventInput(.state) {
                    return state
                }
                return false
            })
            .asObservable()
        return proxyChanged
    }

    func changeProxyAvailability(accountID: String, enable: Bool) {
        let proxyState = self.getCurrentProxyState(accountID: accountID)

        if proxyState == enable {
            return
        }
        self.enableProxy(accountID: accountID, enable: enable)

        //enable push notifications
        if enable {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue), object: nil)
    }

    func updatePushTokenForCurrentAccount(token: String) {
        guard let account = self.currentAccount else {
            return
        }
        let accountDetails = self.getAccountDetails(fromAccountId: account.id)
        accountDetails.set(withConfigKeyModel: ConfigKeyModel(withKey: ConfigKey.devicePushToken), withValue: token)
        self.setAccountDetails(forAccountId: account.id, withDetails: accountDetails)
    }
}
