/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

import RxSwift

/**
 A class representing the ViewModel (MVVM) of the accounts managed by Ring.
 Its responsabilities:
 - expose to the Views a public API for its interactions concerning the Accounts,
 - react to the Views user events concerning the Accounts (add an account...)
 */
class AccountViewModel {
    /**
     Dispose bag that contains the Disposable objects of the ViewModel, and managing their disposes.
     */
    fileprivate let disposeBag = DisposeBag()

    /**
     Retains the currently active stream adding an account.
     Useful to dispose it before starting a new one.
     */
    fileprivate var addAccountDisposable: Disposable?

    /**
     The account under this ViewModel.
     */
    fileprivate var account: AccountModel?

    /**
     Default constructor
     */
    init() {
        self.account = nil
    }

    /**
     Constructor with AccountModel.
     */
    init(withAccountModel account: AccountModel?) {
        self.account = account
    }

    /**
     Create the observers to the streams passed in parameters.
     It will allow this ViewModel to react to other entities' events.

     - Parameter observable: An observable stream to subscribe on.
     Any observed event on this stream will trigger the action of creating an account.
     - Parameter onStartCallback: Closure that will be triggered when the action will begin.
     - Parameter onSuccessCallback: Closure that will be triggered when the action will succeed.
     - Parameter onErrorCallback: Closure that will be triggered in case of error.
     */
    func configureAddAccountObservers(observable: Observable<Void>,
                                      onStartCallback: ((() -> Void)?),
                                      onSuccessCallback: ((() -> Void)?),
                                      onErrorCallback: (((Error?) -> Void)?)) {
        _ = observable
            .subscribe(
                onNext: { [weak self] in
                    //~ Let the caller know that the action has just begun.
                    onStartCallback?()

                    //~ Dispose any previously running stream. There is only one add account action
                    //~ simultaneously authorized.
                    self?.addAccountDisposable?.dispose()
                    //~ Subscribe on the AccountsService responseStream to get results.
                    self?.addAccountDisposable = AccountsService.sharedInstance
                        .sharedResponseStream
                        .subscribe(onNext:{ (event) in
                            if event.eventType == ServiceEventType.AccountsChanged {
                                onSuccessCallback?()
                            }
                        }, onError: { error in
                            onErrorCallback?(error)
                        })
                    self?.addAccountDisposable?.addDisposableTo((self?.disposeBag)!)

                    //~ Launch the action.
                    do {
                        try AccountsService.sharedInstance.addRingAccount(withUsername: nil,
                                                                          password: "coucou")
                    }
                    catch {
                        onErrorCallback?(error)
                    }
                },
                onError: { (error) in
                    onErrorCallback?(error)
            })
            .addDisposableTo(disposeBag)
    }

    func isAccountSip() -> Bool {
        let sipString = AccountType.SIP.rawValue
        let accountType = self.account?.details
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountType))
        return sipString.compare(accountType!) == ComparisonResult.orderedSame
    }

    func isAccountRing() -> Bool {
        let ringString = AccountType.Ring.rawValue
        let accountType = self.account?.details
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountType))
        return ringString.compare(accountType!) == ComparisonResult.orderedSame
    }

    func getRegistrationState() -> String {
        return (self.account?.volatileDetails
            .get(withConfigKeyModel: ConfigKeyModel.init(withKey: .AccountRegistrationStatus)))!
    }

    func isEnabled() -> Bool {
        return (self.account?.details
            .getBool(forConfigKeyModel: ConfigKeyModel.init(withKey: .AccountEnable)))!
    }

    func isInError() -> Bool {
        let state = self.getRegistrationState()
        return (state.compare(AccountState.Error.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorAuth.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorConfStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorExistStun.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorGeneric.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorHost.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorNetwork.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorNotAcceptable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorServiceUnavailable.rawValue) == ComparisonResult.orderedSame) ||
            (state.compare(AccountState.ErrorRequestTimeout.rawValue) == ComparisonResult.orderedSame)
    }

    func setCredentials(_ credentials: Array<Dictionary<String, String>>?) {
        self.account?.credentialDetails.removeAll()
        if credentials != nil {
            for (credential) in credentials! {
                let accountCredentialModel = AccountCredentialsModel(withRawaData: credential)
                self.account?.credentialDetails.append(accountCredentialModel)
            }
        }
    }
}
