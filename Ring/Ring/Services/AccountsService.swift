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

enum AddAccountError: Error {
    case templateNotConform
    case unknownError
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

    // MARK: - Public members
    /**
     Accounts list public interface.
     Can be used to access by constant the list of accounts.
     */
    fileprivate(set) var accounts: [AccountModel] {
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

    fileprivate(set) var currentAccount: AccountModel? {
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

    func loadAccounts() {
        for accountId in accountAdapter.getAccountList() {
            if  let id = accountId as? String {
                self.accountList.append(AccountModel(withAccountId: id))
            }
        }

        reloadAccounts()
    }

    // MARK: - Methods
    func hasAccounts() -> Bool {
        return !accountList.isEmpty
    }

    fileprivate func reloadAccounts() {
        for account in accountList {
            account.details = self.getAccountDetails(fromAccountId: account.id)
            account.volatileDetails = self.getVolatileAccountDetails(fromAccountId: account.id)
            account.devices.append(objectsIn: getKnownRingDevices(fromAccountId: account.id))

            do {
                let credentialDetails = try self.getAccountCredentials(fromAccountId: account.id)
                account.credentialDetails.removeAll()
                account.credentialDetails.append(objectsIn: credentialDetails)
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
                //TODO: set registration state as ready for a SIP account

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

     - Returns: the details of the accounts.
     */
    func getAccountDetails(fromAccountId id: String) -> AccountConfigModel {
        let details: NSDictionary = accountAdapter.getAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }

    /**
     Gets all the volatile details of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the volatile details of the accounts.
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
    func getAccountCredentials(fromAccountId id: String) throws -> List<AccountCredentialsModel> {
        let creds: NSArray = accountAdapter.getCredentials(id) as NSArray
        let rawCredentials = creds as NSArray? as? [[String: String]] ?? nil

        if let rawCredentials = rawCredentials {
            let credentialsList = List<AccountCredentialsModel>()
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
                devices.append(DeviceModel(withDeviceId: key))
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
        accountDetails!.updateValue("false", forKey: ConfigKey.videoEnabled.rawValue)
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

        var event = ServiceEvent(withEventType: .registrationStateChanged)
        event.addEventInput(.registrationState, value: response.state)
        self.responseStream.onNext(event)
    }

}
