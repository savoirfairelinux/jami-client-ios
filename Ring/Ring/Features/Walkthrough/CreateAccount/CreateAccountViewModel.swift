/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import RxSwift

enum PasswordValidationState {
    case validated
    case error (message: String)

    var isValidated: Bool {
        switch self {
        case .validated:
            return true
        default:
            return false
        }
    }

    var message: String {
        switch self {
        case .validated:
            return ""
        case .error(let message):
            return message
        }
    }
}

enum UsernameValidationState {
    case unknown
    case available
    case lookingForAvailibility(message: String)
    case invalid(message: String)
    case unavailable(message: String)

    var isAvailable: Bool {
        switch self {
        case .available, .unknown:
            return true
        default:
            return false
        }
    }

    var message: String {
        switch self {
        case .available, .unknown:
            return ""
        case .lookingForAvailibility(let message):
            return message
        case .invalid(let message):
            return message
        case .unavailable(let message):
            return message
        }
    }
}

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
            return L10n.Alerts.accountCannotBeFoundTitle.smartString
        case .network:
            return L10n.Alerts.accountNoNetworkTitle.smartString
        default:
            return L10n.Alerts.accountDefaultErrorTitle.smartString
        }
    }

    var message: String {
        switch self {
        case .generic:
            return L10n.Alerts.accountDefaultErrorMessage.smartString
        case .network:
            return L10n.Alerts.accountNoNetworkMessage.smartString
        default:
            return L10n.Alerts.accountDefaultErrorMessage.smartString
        }
    }
}

// swiftlint:disable opening_brace
class CreateAccountViewModel: Stateable {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()

    // MARK: L10n
    let createAccountTitle  = L10n.Createaccount.createAccountFormTitle.smartString
    let createAccountButton = L10n.Welcome.createAccount.smartString
    let usernameTitle = L10n.Createaccount.enterNewUsernamePlaceholder.smartString
    let passwordTitle = L10n.Createaccount.newPasswordPlaceholder.smartString
    let confirmPasswordTitle = L10n.Createaccount.repeatPasswordPlaceholder.smartString

    // MARK: - Low level services
    private let accountService: AccountsService
    private let nameService: NameService

    // MARK: - Rx Variables for UI binding
    let accountCreationState = PublishSubject<AccountCreationState>()
    let username = Variable<String>("")
    let password = Variable<String>("")
    let confirmPassword = Variable<String>("")
    let registerUsername = Variable<Bool>(true)
    lazy var passwordValidationState: Observable<PasswordValidationState> = {
        return Observable.combineLatest(self.password.asObservable(), self.confirmPassword.asObservable())
        { (password: String, confirmPassword: String) -> PasswordValidationState in
            if password.characters.count < 6 {
                return .error(message: L10n.Createaccount.passwordCharactersNumberError.smartString)
            }

            if password != confirmPassword {
                return .error(message: L10n.Createaccount.passwordNotMatchingError.smartString)
            }

            return .validated
        }
    }()
    lazy var usernameValidationState = Variable<UsernameValidationState>(.unknown)
    lazy var canAskForAccountCreation: Observable<Bool> = {
        return Observable.combineLatest(self.password.asObservable(),
                                        self.passwordValidationState.asObservable(),
                                        self.usernameValidationState.asObservable(),
                                        self.registerUsername.asObservable(),
                                        resultSelector:
            { (password: String, passwordValidationState: PasswordValidationState, usernameValidationState: UsernameValidationState, registerUsername: Bool) -> Bool in
                if registerUsername {
                    return usernameValidationState.isAvailable && passwordValidationState.isValidated
                }

                if !password.isEmpty {
                    return passwordValidationState.isValidated
                }

                return false
        })
    }()

    init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService

        //Loookup name request observer
        self.username.asObservable().subscribe(onNext: { [unowned self] username in
            self.nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }).disposed(by: disposeBag)

        self.nameService.usernameValidationStatus.asObservable().subscribe(onNext: { (status) in
            switch status {
            case .lookingUp:
                self.usernameValidationState.value = .lookingForAvailibility(message: L10n.Createaccount.lookingForUsernameAvailability.smartString)
                break
            case .invalid:
                self.usernameValidationState.value = .invalid(message: L10n.Createaccount.invalidUsername.smartString)
                break
            case .alreadyTaken:
                self.usernameValidationState.value = .unavailable(message: L10n.Createaccount.usernameAlreadyTaken.smartString)
                break
            default:
                self.usernameValidationState.value = .available
            }
        }).disposed(by: self.disposeBag)

        //Name registration observer
        self.accountService
            .sharedResponseStream
            .filter({ event in
                return event.eventType == ServiceEventType.registrationStateChanged &&
                    event.getEventInput(ServiceEventInput.registrationState) == Unregistered &&
                    self.registerUsername.value
            })
            .subscribe(onNext: { [unowned self] _ in

                //Launch the process of name registration
                if let currentAccountId = self.accountService.currentAccount?.id {
                    self.nameService.registerName(withAccount: currentAccountId,
                                                  password: self.password.value,
                                                  name: self.username.value)
                }
            })
            .disposed(by: disposeBag)

        //Account creation state observer
        self.accountService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] event in
                if event.getEventInput(ServiceEventInput.registrationState) == Unregistered {
                    self.accountCreationState.onNext(.success)
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                    self.accountCreationState.onError(AccountCreationError.generic)
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    self.accountCreationState.onError(AccountCreationError.network)
                }
                }, onError: { _ in
                    self.accountCreationState.onError(AccountCreationError.unknown)
            }).disposed(by: disposeBag)

    }

    func createAccount() {
        //        self.accountCreationState.onNext(.started)
        //        self.accountService.addRingAccount(withUsername: self.username.value,
        //                                           password: self.password.value)
    }
}
