/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
    case unknown
    case started
    case success
    case error(error: AccountCreationError)

    var isInProgress: Bool {
        switch self {
        case .started:
            return true
        default:
            return false
        }
    }

    var message: String {
        switch self {
        case .error(let error):
            return error.localizedDescription
        default:
            return ""
        }
    }
}

enum AccountCreationError: Error {
    case generic
    case network
    case unknown
    case linkError
}

extension AccountCreationError: LocalizedError {

    var title: String {
        switch self {
        case .generic:
            return L10n.Alerts.accountCannotBeFoundTitle
        case .network:
            return L10n.Alerts.accountNoNetworkTitle
        case .linkError:
            return L10n.Alerts.accountCannotBeFoundTitle
        default:
            return L10n.Alerts.accountDefaultErrorTitle
        }
    }

    var message: String {
        switch self {
        case .generic:
            return L10n.Alerts.accountDefaultErrorMessage
        case .network:
            return L10n.Alerts.accountNoNetworkMessage
        case .linkError:
            return L10n.Alerts.accountCannotBeFoundMessage
        default:
            return L10n.Alerts.accountDefaultErrorMessage
        }
    }
}

// swiftlint:disable opening_brace
// swiftlint:disable closure_parameter_position
class CreateAccountViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()

    // MARK: L10n
    let createAccountTitle  = L10n.CreateAccount.createAccountFormTitle
    let createAccountButton = L10n.Welcome.createAccount
    let usernameTitle = L10n.CreateAccount.enterNewUsernamePlaceholder
    let passwordTitle = L10n.CreateAccount.newPasswordPlaceholder
    let confirmPasswordTitle = L10n.CreateAccount.repeatPasswordPlaceholder
    let registerAUserNameTitle = L10n.CreateAccount.registerAUsername
    let chooseAPasswordTitle = L10n.CreateAccount.chooseAPassword
    let passwordInfoTitle = L10n.CreateAccount.passwordInformation
    let enableNotificationsTitle = L10n.CreateAccount.enableNotifications
    let recommendedTitle = L10n.CreateAccount.recommended

    // MARK: - Low level services
    private let accountService: AccountsService
    private let nameService: NameService

    // MARK: - Rx Variables for UI binding
    private let accountCreationState = Variable<AccountCreationState>(.unknown)
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()
    let username = Variable<String>("")
    let password = Variable<String>("")
    let confirmPassword = Variable<String>("")
    let registerUsername = Variable<Bool>(true)
    let notificationSwitch = Variable<Bool>(true)
    lazy var passwordValidationState: Observable<PasswordValidationState> = {
        return Observable.combineLatest(self.password.asObservable(), self.confirmPassword.asObservable())
        { (password: String, confirmPassword: String) -> PasswordValidationState in
            if password.isEmpty && confirmPassword.isEmpty {
                return .validated
            }

            if password.characters.count < 6 {
                return .error(message: L10n.CreateAccount.passwordCharactersNumberError)
            }

            if password != confirmPassword {
                return .error(message: L10n.CreateAccount.passwordNotMatchingError)
            }

            return .validated
        }
    }()
    lazy var usernameValidationState = Variable<UsernameValidationState>(.unknown)
    lazy var canAskForAccountCreation: Observable<Bool> = {
        return Observable.combineLatest(self.passwordValidationState.asObservable(),
                                        self.usernameValidationState.asObservable(),
                                        self.registerUsername.asObservable(),
                                        self.username.asObservable(),
                                        self.createState,
                                        resultSelector:
            { ( passwordValidationState: PasswordValidationState,
                usernameValidationState: UsernameValidationState,
                registerUsername: Bool,
                username: String,
                creationState: AccountCreationState) -> Bool in

                var canAsk = true

                if registerUsername {
                    canAsk = canAsk && usernameValidationState.isAvailable && !username.isEmpty
                }

                canAsk = canAsk && passwordValidationState.isValidated

                canAsk = canAsk && !creationState.isInProgress

                return canAsk
        })
    }()

    required init (with injectionBag: InjectionBag) {
        var isPageDisplayed = false
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService

        //Loookup name request observer
        self.username.asObservable().subscribe(onNext: { [unowned self] username in
            self.nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }).disposed(by: disposeBag)

        self.nameService.usernameValidationStatus.asObservable().subscribe(onNext: { [weak self] (status) in
            switch status {
            case .lookingUp:
                self?.usernameValidationState.value = .lookingForAvailibility(message: L10n.CreateAccount.lookingForUsernameAvailability)
            case .invalid:
                self?.usernameValidationState.value = .invalid(message: L10n.CreateAccount.invalidUsername)
            case .alreadyTaken:
                self?.usernameValidationState.value = .unavailable(message: L10n.CreateAccount.usernameAlreadyTaken)
            default:
                self?.usernameValidationState.value = .available
            }
        }).disposed(by: self.disposeBag)

        //Name registration observer
        self.accountService
            .sharedResponseStream
            .filter({ [unowned self] (event) in
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
                    self.accountCreationState.value = .success
                    if !isPageDisplayed {
                        DispatchQueue.main.async {
                            self.stateSubject.onNext(WalkthroughState.accountCreated)
                        }
                        isPageDisplayed = true
                    }
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                    self.accountCreationState.value = .error(error: AccountCreationError.generic)
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    self.accountCreationState.value = .error(error: AccountCreationError.network)
                }
                }, onError: { [unowned self] _ in
                    self.accountCreationState.value = .error(error: AccountCreationError.unknown)
            }).disposed(by: disposeBag)

    }

    func createAccount() {
        self.accountCreationState.value = .started
        self.accountService.addRingAccount(withUsername: self.username.value,
                                           password: self.password.value, enable: self.notificationSwitch.value)
        self.enablePushNotifications(enable: self.notificationSwitch.value)
    }

    func enablePushNotifications(enable: Bool) {
        if enable {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.disablePushNotifications.rawValue), object: nil)
    }
}
