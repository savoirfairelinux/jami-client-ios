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

enum AddAccountError: Error {
    case TemplateNotConform
    case UnknownError
}

class AccountsService: AccountAdapterDelegate {
    // MARK: Private members
    /**
     AccountConfigurationManagerAdaptator instance.
     Used to register the service to daemon events.
     */
    fileprivate let confAdapter = AccountAdapter.sharedManager() as AccountAdapter

    /**
     Fileprivate Accounts list.
     Can be used for all the operations, but won't be accessed from outside this file.

     - SeeAlso: `accounts`
     */
    fileprivate var accountList: Array<AccountModel>

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
    fileprivate(set) var accounts: Array<AccountModel> {
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

    fileprivate(set) var currentAccount: AccountModel

    // MARK: - Singleton
    static let sharedInstance = AccountsService()

    fileprivate init() {
        self.accountList = []

        self.responseStream.addDisposableTo(disposeBag)

        //~ Create a shared stream based on the responseStream one.
        self.sharedResponseStream = responseStream.share()

        //~ Registering to the AccountConfigurationManagerAdaptator with self as delegate in order
        //~ to receive delegation callbacks.
        self.confAdapter.delegate = self
    }

    // MARK: - Methods
    func hasAccounts() -> Bool {
        return accountList.count > 0
    }

    func reload() {
        accountList.removeAll()
        //for account in confAdapter.getAccountList() {
        //let accountID = account as! String
        //accountList.append(AccountModel())
        //}
    }

    /**
     Entry point to create a brand-new Ring account.

     - Parameter username: the username chosen by the user, if any
     - Parameter password: the password chosen by the user

     - Throws: AddAccountError
     */
    func addRingAccount(withUsername username: String?, password: String) throws {
        do {
            var ringDetails = try self.getRingInitialAccountDetails()
            if username != nil {
                ringDetails.updateValue(username!, forKey: ConfigKey.AccountRegisteredName.rawValue)
            }
            ringDetails.updateValue(password, forKey: ConfigKey.ArchivePassword.rawValue)
            let accountId = self.confAdapter.addAccount(ringDetails)
            guard accountId != nil else {
                throw AddAccountError.UnknownError
            }

            let account = self.getAccount(fromAccountId: accountId!)

            if account == nil {
                let details = Dictionary<String, String>.init()
                let volatileDetails = Dictionary<String, String>.init()
                let credentials = Array<Dictionary<String, String>>.init()
                let devices = Dictionary<String, String>.init()

                let newAccount = AccountModel.init(withAccountId: accountId!,
                                                   details: details,
                                                   volatileDetails: volatileDetails,
                                                   credentials: credentials,
                                                   devices: devices)
                //TODO: set registration state as ready for a SIP account

                let accountViewModel = AccountViewModel.init(withAccountModel: newAccount)

                var accountAddedEvent = ServiceEvent.init(withEventType: .AccountAdded)
                accountAddedEvent.addEventInput(.Id, value: newAccount.id)
                accountAddedEvent.addEventInput(.State, value: accountViewModel.getRegistrationState())
                self.responseStream.onNext(accountAddedEvent)

                self.setCurrentAccount(newAccount)
            }
        }
        catch {
            throw error
        }
    }

    /**
     Entry point to create a brand-new SIP account.

     Not supported yet.
     */
    fileprivate func addSipAccount() {
        print("Not supported yet")
    }

    func setCurrentAccount(_ account: AccountModel) {
        self.currentAccount = account
        //TODO: handle the order of the list of accounts: current account must be first.
    }

    func getAccount(fromAccountId id: String) -> AccountModel? {
        for account in self.accountList {
            if id.compare(account.id) == ComparisonResult.orderedSame {
                return account
            }
        }
        return nil
    }



    /**
     Gathers all the initial default details contained by any accounts, Ring or SIP.

     - Returns the details.
     */
    fileprivate func getInitialAccountDetails() throws -> Dictionary<String, String> {
        let details: NSMutableDictionary = confAdapter.getAccountTemplate(AccountType.Ring.rawValue)
        var accountDetails = details as NSDictionary? as? Dictionary<String, String> ?? nil
        if accountDetails == nil {
            throw AddAccountError.TemplateNotConform
        }
        accountDetails!.updateValue("false", forKey: ConfigKey.VideoEnabled.rawValue)
        accountDetails!.updateValue("sipinfo", forKey: ConfigKey.AccountDTMFType.rawValue)
        return accountDetails!
    }

    /**
     Gathers all the initial default details contained in a Ring accounts.

     - Returns the details.
     */
    fileprivate func getRingInitialAccountDetails() throws -> Dictionary<String, String> {
        do {
            var defaultDetails = try getInitialAccountDetails()
            defaultDetails.updateValue("Ring", forKey: ConfigKey.AccountAlias.rawValue)
            defaultDetails.updateValue("bootstrap.ring.cx", forKey: ConfigKey.AccountHostname.rawValue)
            defaultDetails.updateValue("true", forKey: ConfigKey.AccountUpnpEnabled.rawValue)
            return defaultDetails
        } catch {
            throw error
        }
    }

    func removeAccount(_ row: Int) {
        if row < accountList.count {
            confAdapter.removeAccount(accountList[row].id)
        }
    }

    // MARK: - AccountAdapterDelegate
    func accountsChanged() {
        print("Accounts changed.")
        reload()

        let event = ServiceEvent.init(withEventType: .AccountsChanged)
        self.responseStream.onNext(event)
    }
}
