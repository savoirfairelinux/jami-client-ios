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

    var username = Variable<String>("")
    var password = Variable<String>("")
    var repeatPassword = Variable<String>("")

    var passwordValid :Observable<Bool>!
    var passwordsEqual :Observable<Bool>!
    var canCreateAccount :Observable<Bool>!
    var registerUsername = Variable<Bool>(true)

    var hasNewPassword :Observable<Bool>!
    var hidePasswordError :Observable<Bool>!
    var hideRepeatPasswordError :Observable<Bool>!

    var accountCreationState = PublishSubject<AccountCreationState>()

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
     Start the process of account creation
     */
    func createAccount() {

        do {
            //Add account
            accountCreationState.onNext(.started)
            try self.accountService.addRingAccount(withUsername: self.username.value,
                                                   password: self.password.value)
        }
        catch {
            accountCreationState.onError(AccountCreationError.unknown)
        }
    }

    /**
     Init obsevables needed to validate the user inputs for account creation
     */
    fileprivate func initObservables() {

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

        hasNewPassword = self.password.asObservable().map({ password in
            return password.characters.count > 0
        })

        hidePasswordError = Observable<Bool>.combineLatest(self.passwordValid, hasNewPassword) { isPasswordValid, hasNewPassword in
            return isPasswordValid || !hasNewPassword
        }

        let hasRepeatPassword = self.repeatPassword.asObservable().map({ repeatPassword in
            return repeatPassword.characters.count > 0
        })

        hideRepeatPasswordError = Observable<Bool>.combineLatest(self.passwordValid,self.passwordsEqual, hasRepeatPassword) { isPasswordValid, isPasswordsEquals, hasRepeatPassword in
            return !isPasswordValid || isPasswordsEquals || !hasRepeatPassword
        }
    }

    /**
     Init observers for account creation
     */
    fileprivate func initObservers() {

        //Loookup name request observer
        self.username.asObservable().subscribe(onNext: { [unowned self] username in
            self.nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }).addDisposableTo(disposeBag)

        //Name registration observer
        self.accountService
            .sharedResponseStream
            .filter({ event in
                return event.eventType == ServiceEventType.RegistrationStateChanged &&
                    event.getEventInput(ServiceEventInput.RegistrationState) == Unregistered &&
                    self.registerUsername.value
            })
            .subscribe(onNext:{ [unowned self] event in

                //Launch the process of name registration
                if let currentAccountId = self.accountService.currentAccount?.id {
                    self.nameService.registerName(withAccount: currentAccountId,
                                                  password: self.password.value,
                                                  name: self.username.value)
                }
            })
            .addDisposableTo(disposeBag)

        //Account creation state observer
        self.accountService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] event in
                if event.getEventInput(ServiceEventInput.RegistrationState) == Unregistered {
                    self.accountCreationState.onNext(.success)
                } else if event.getEventInput(ServiceEventInput.RegistrationState) == ErrorGeneric {
                    self.accountCreationState.onError(AccountCreationError.generic)
                } else if event.getEventInput(ServiceEventInput.RegistrationState) == ErrorNetwork {
                    self.accountCreationState.onError(AccountCreationError.network)
                }
            })
            .addDisposableTo(disposeBag)
    }
}

//MARK: Account Creation state

enum AccountCreationState {
    case started
    case success
    case error(error: AccountCreationError)
}

enum AccountCreationError: Error {
    case generic
    case network
    case unknown
}

extension AccountCreationError: LocalizedError {

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
