/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

    // MARK: - Singleton
    static let sharedInstance = AccountsService()

    fileprivate init() {
        accountList = []

        //~ Registering to the AccountConfigurationManagerAdaptator with self as delegate in order
        //~ to receive delegation callbacks.
        confAdapter.delegate = self
    }

    // MARK: - Methods
    func hasAccounts() -> Bool {
        return accountList.count > 0
    }

    func reload() {
        accountList.removeAll()
        for account in confAdapter.getAccountList() {
            let accountID = account as! String
            accountList.append(AccountModel(accountID: accountID))
        }
    }

    func addAccount() {
        // TODO: This need work for all account type
        let details:NSMutableDictionary? = confAdapter.getAccountTemplate("RING")
        if details == nil {
            print("Error retrieving Ring account template, can not continue");
            return;
        }
        details!.setValue("iOS", forKey: "Account.alias")
        details!.setValue("iOS", forKey: "Account.displayName")
        let convertedDetails = details as NSDictionary? as? [AnyHashable: Any] ?? [:]
        let addResult:String! = confAdapter.addAccount(convertedDetails)
        print(addResult);
    }

    func removeAccount(_ row: Int) {
        if row < accountList.count {
            confAdapter.removeAccount(accountList[row].id)
        }
    }

    // MARK: - AccountAdapterDelegate
    func accountsChanged() {
        print("Accounts changed.")
    }
}
