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

import RxCocoa
import RxSwift

/**
 Events that can be sent to the response stream

 - AddAccount: ask for the addAccount feature to run
 - AccountChanged: the accounts have been changed daemon-side
 */
enum AccountRxEvent {
    case AddAccount
    case AccountChanged
}

class AccountsService {
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
    fileprivate var accountList: Array<AccountModel> = []

    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    /**
     PublishSubject forwarding AccountRxEvent events.
     The service can observe this stream to know what has been done.
     
     - SeeAlso: `AccountRxEvent`
     */
    fileprivate var responseStream: PublishSubject<AccountRxEvent>?

    /**
     The disposable returned when adding an account.
     */
    fileprivate var addAccountStream: Disposable?

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

    // MARK: - Lifecycle
    init() {
        //~ Create the response stream and add it to the dispose bag.
        self.responseStream = PublishSubject<AccountRxEvent>()
        self.responseStream?.addDisposableTo(disposeBag)

        //~ Register to the objc bridge between the daemon and the app.
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(accountsChanged),
                         name: NSNotification.Name(rawValue: kNotificationAccountsChanged),
                         object: nil)

        reload()
    }

    deinit {
        //~ Unregister the bridge events.
        NotificationCenter
            .default
            .removeObserver(self,
                            name: NSNotification.Name(rawValue: kNotificationAccountsChanged),
                            object: nil)
    }

    // MARK: - Static Methods
    static func hasAccounts() -> Bool {
        return AccountAdapter.sharedManager().getAccountList().count > 0
    }

    // MARK: - Methods
    func addAccount(onSuccessCallback: ((() -> Void)?),
                    onErrorCallback: (((Error?) -> Void)?)) {

        //~ Dispose a currently undisposed stream to subscribe with new callbacks after that.
        if self.addAccountStream != nil {
            self.addAccountStream?.dispose()
        }

        self.addAccountStream = responseStream?
            .subscribe(
                onNext: { [weak self] (event) in
                    switch event {
                    case .AddAccount : self?.addAccount()
                        break
                    case .AccountChanged :
                        if onSuccessCallback != nil {
                            onSuccessCallback!()
                        }
                        break
                    }
            }, onError: { (error) in
                print(error)
                if onErrorCallback != nil {
                    onErrorCallback!(error)
                }
            })
        self.addAccountStream?.addDisposableTo(disposeBag)

        //~ Request the action
        self.responseStream?.onNext(.AddAccount)
    }

    func reload() {
        accountList.removeAll()
        for account in confAdapter.getAccountList() {
            let accountID = account as! String
            accountList.append(AccountModel(accountID: accountID))
        }
    }

    fileprivate func addAccount() {
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

    /**
     Callback received from Notification.
     */
    @objc func accountsChanged() {
        print("Accounts changed.")
        reload()
        self.responseStream?.onNext(.AccountChanged)
    }
}
