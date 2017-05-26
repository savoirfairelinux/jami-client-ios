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
class CreateRingAccountViewModel {
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
     The accountService instance injected in initializer.
     */
    fileprivate let accountService: AccountsService

    //MARK: - Rx Variables and Observers

    var username = Variable<String>("")
    var password = Variable<String>("")
    var repeatPassword = Variable<String>("")

    var usernameValid :Observable<Bool> {
        return username.asObservable().map({ username in
            return !username.isEmpty
        })
    }

    var passwordValid :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.username.asObservable(),
                                              self.password.asObservable(),
                                              self.repeatPassword.asObservable())
        { (username, password, repeatPassword) in
            return password.characters.count >= 6
        }
    }

    var passwordsEqual :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.password.asObservable(),
                                              self.repeatPassword.asObservable())
        { password, repeatPassword in
            return password == repeatPassword
        }
    }

    var canCreateAccount :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.registerUsername.asObservable(),
                                              self.usernameValid,
                                              self.passwordValid,
                                              self.passwordsEqual)
        { registerUsername, usernameValid, passwordValid, passwordsEquals in
            if registerUsername {
                return usernameValid && passwordValid && passwordsEquals
            } else {
                return passwordValid && passwordsEquals
            }
        }
    }

    var registerUsername = Variable<Bool>(true)

    //Observes if the field is not empty
    var hasNewPassword :Observable<Bool> {
        return self.password.asObservable().map({ password in
            return password.characters.count == 0
        })
    }

    //Observes if the password is valid and is not empty to show the error message
    var hidePasswordError :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.passwordValid, hasNewPassword)
        { isPasswordValid, hasNewPassword in
            return isPasswordValid || hasNewPassword
        }
    }

    //Observes if the password is valid and is not empty to show the error message
    var hideRepeatPasswordError :Observable<Bool> {
        return Observable<Bool>.combineLatest(self.passwordValid, self.passwordsEqual) { isPasswordValid,
            isPasswordsEquals in
            return !isPasswordValid || isPasswordsEquals
        }
    }

    /**
     Default constructor
     */
    init(withAccountService accountService: AccountsService) {
        self.account = nil
        self.accountService = accountService
    }

    /**
     Constructor with AccountModel.
     */
    init(withAccountService accountService: AccountsService,
         accountModel account: AccountModel?) {
        self.account = account
        self.accountService = accountService
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
                    self?.addAccountDisposable = self?.accountService
                        .sharedResponseStream
                        .subscribe(onNext:{ (event) in
                            if event.eventType == ServiceEventType.AccountAdded {
                                print("Account added.")
                            }
                            if event.eventType == ServiceEventType.AccountsChanged {
                                onSuccessCallback?()
                            }
                        }, onError: { error in
                            onErrorCallback?(error)
                        })
                    self?.addAccountDisposable?.addDisposableTo((self?.disposeBag)!)

                    //~ Launch the action.
                    do {
                        try self?.accountService.addRingAccount(withUsername: nil,
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

}
