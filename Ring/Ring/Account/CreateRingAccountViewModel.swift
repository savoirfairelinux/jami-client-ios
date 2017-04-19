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

    /**
     The nameService instance injected in initializer.
     */
    fileprivate var nameService: NameService

    //MARK: - Rx Variables and Observers

    /**
     Bindings from the UI
     */
    var username = Variable<String>("")
    var password = Variable<String>("")
    var repeatPassword = Variable<String>("")
    var registerUsername = Variable<Bool>(true)

    /**
     Validates the passwords fields
     */
    var passwordValid :Observable<Bool>!
    var passwordsEqual :Observable<Bool>!

    /**
     Validates the ability to create an account
     */
    var canCreateAccount :Observable<Bool>!

    /**
     Message presented to the user in function of the status of the current username lookup request
     */
    var usernameValidationMessage :Observable<String>!

    //MARK: -

    /**
     Default constructor
     */
    init(withAccountService accountService: AccountsService, nameService: NameService) {
        self.account = nil
        self.accountService = accountService
        self.nameService = nameService
        self.initObservables()
        self.initObservers()
    }

    /**
     Constructor with AccountModel.
     */
    init(withAccountService accountService: AccountsService,
         accountModel account: AccountModel?, nameService: NameService) {
        self.account = account
        self.accountService = accountService
        self.nameService = nameService
        self.initObservables()
        self.initObservers()
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
                                      onErrorCallback: (((AccountRegistrationError?) -> Void)?)) {
        _ = observable
            .subscribe(
                onNext: { [weak self] in

                    guard let registerUsername = self?.registerUsername.value,
                        let username = self?.username.value,
                        let password = self?.password.value else {
                            onErrorCallback?(nil)
                            return
                    }

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

                            if event.eventType == ServiceEventType.RegistrationStateChanged {

                                if event.getEventInput(ServiceEventInput.RegistrationState) == Unregistered {

                                    onSuccessCallback?()

                                    //Register username if needs
                                    if registerUsername {
                                        if let currentAccountId = self?.accountService.currentAccount?.id {
                                            self?.nameService.registerName(withAccount: currentAccountId,
                                                              password: password,
                                                              name: username)
                                        }
                                    }
                                } else if event.getEventInput(ServiceEventInput.RegistrationState) == ErrorGeneric  {
                                    onErrorCallback?(AccountRegistrationError.generic)
                                } else if event.getEventInput(ServiceEventInput.RegistrationState) == ErrorNetwork {
                                    onErrorCallback?(AccountRegistrationError.network)
                                }
                            }
                        }, onError: { error in
                            onErrorCallback?(AccountRegistrationError.unknown)
                        })
                    self?.addAccountDisposable?.addDisposableTo((self?.disposeBag)!)

                    //~ Launch the action.
                    do {
                        //Add account
                        try self?.accountService.addRingAccount(withUsername: username,
                                                                password: password)
                        }
                    catch {
                        onErrorCallback?(AccountRegistrationError.unknown)
                    }
                },
                onError: { (error) in
                    onErrorCallback?(AccountRegistrationError.unknown)
            })
            .addDisposableTo(disposeBag)
    }

    /**
     Init obsevables needed to validate the user inputs for account creation
     */
    func initObservables() {

        self.passwordValid = password.asObservable().map { password in
            return password.characters.count >= 6
        }.shareReplay(1).observeOn(MainScheduler.instance)

        self.passwordsEqual = Observable<Bool>.combineLatest(self.password.asObservable(),
                                                             self.repeatPassword.asObservable()) { password,repeatPassword in
                return password == repeatPassword
        }.shareReplay(1).observeOn(MainScheduler.instance)

        self.canCreateAccount = Observable<Bool>.combineLatest(self.registerUsername.asObservable(),
                                                               self.nameService.usernameValidationStatus,
                                                               self.passwordValid,
                                                               self.passwordsEqual)
        { registerUsername, usernameValidationStatus, passwordValid, passwordsEquals in
            if registerUsername {
                return usernameValidationStatus == .valid && passwordValid && passwordsEquals
            } else {
                return passwordValid && passwordsEquals
            }
        }.shareReplay(1).observeOn(MainScheduler.instance)

        self.usernameValidationMessage = self.nameService.usernameValidationStatus
            .asObservable().map ({ status in
            switch status {
            case .lookingUp:
                return NSLocalizedString("LookingForUsernameAvailability",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            case .invalid:
                return NSLocalizedString("InvalidUsername",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            case .alreadyTaken:
                return NSLocalizedString("UsernameAlreadyTaken",
                                         tableName: LocalizedStringTableNames.walkthrough,
                                         comment: "")
            default:
                return ""
            }
        }).shareReplay(1).observeOn(MainScheduler.instance)

    }

    /**
     Init observers needed to validate the user inputs for account creation
     */
    func initObservers() {
        self.username.asObservable().subscribe(onNext: { [unowned self] username in
            self.nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }).addDisposableTo(disposeBag)
    }
}

//MARK: Errors

enum AccountRegistrationError: Error {
    case generic
    case network
    case unknown
}

extension AccountRegistrationError: LocalizedError {

    var title: String {
        switch self {
        case .generic:
            return NSLocalizedString("AccountCannotBeFoundTitle",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        case .network:
            return NSLocalizedString("AccountNoNetworkTitle",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        default:
            return NSLocalizedString("AccountDefaultErrorTitle",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        }
    }

    var message: String {
        switch self {
        case .generic:
            return NSLocalizedString("AcountCannotBeFoundMessage",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        case .network:
            return NSLocalizedString("AccountNoNetworkMessage",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        default:
            return NSLocalizedString("AccountDefaultErrorMessage",
                                     tableName: LocalizedStringTableNames.walkthrough,
                                     comment: "")
        }
    }
}
