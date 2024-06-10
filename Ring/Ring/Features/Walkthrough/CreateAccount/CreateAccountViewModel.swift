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
import RxRelay

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
    case available(message: String)
    case lookingForAvailibility(message: String)
    case invalid(message: String)
    case unavailable(message: String)

    var isAvailable: Bool {
        switch self {
        case .available:
            return true
        default:
            return false
        }
    }

    var isDefault: Bool {
        switch self {
        case .unknown:
            return true
        default:
            return false
        }
    }

    var isVerifying: Bool {
        switch self {
            case .lookingForAvailibility(_):
                return true
            default:
                return false
        }
    }

    var message: String {
        switch self {
        case .unknown:
            return ""
        case .available(let message):
            return message
        case .lookingForAvailibility(let message):
            return message
        case .invalid(let message):
            return message
        case .unavailable(let message):
            return message
        }
    }

    var textColor: UIColor {
        switch self {
            case .unknown:
                return .clear
            case .available(_):
                return .jamiSuccess
            case .lookingForAvailibility(_):
                return .clear
            case .invalid(_):
                return .jamiFailure
            case .unavailable(_):
                return .jamiFailure
        }
    }
}

enum AccountCreationState {
    case unknown
    case started
    case success
    case nameNotRegistered
    case timeOut
    case error(error: AccountCreationError)

    var isInProgress: Bool {
        switch self {
        case .started:
            return true
        default:
            return false
        }
    }

    var isCompleted: Bool {
        switch self {
        case .unknown, .started:
            return false
        default:
            return true
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

    static func == (lhs: AccountCreationState, rhs: AccountCreationState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case (.started, .started):
            return true
        case (.success, .success):
            return true
        case ( .error, .error):
            return true
        default:
            return false
        }
    }
}

enum AccountCreationError: Error {
    case generic
    case network
    case unknown
    case linkError
    case wrongCredentials
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
        case .wrongCredentials:
            return L10n.Alerts.errorWrongCredentials
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
        case .wrongCredentials:
            return ""
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

    var notCancelable = true

    // MARK: L10n
    let createAccountTitle = L10n.CreateAccount.createAccountFormTitle
    let createAccountButton = L10n.Welcome.createAccount
    let usernameTitle = L10n.Global.username
    let recommended = L10n.Global.recommended

    // MARK: - Low level services
    private let accountService: AccountsService
    private let nameService: NameService

    // MARK: - Rx Variables for UI binding
    private let accountCreationState = BehaviorRelay<AccountCreationState>(value: .unknown)
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()
    let username = BehaviorRelay<String>(value: "")
    let password = BehaviorRelay<String>(value: "")
    let confirmPassword = BehaviorRelay<String>(value: "")
    let notificationSwitch = BehaviorRelay<Bool>(value: true)
    let nameRegistrationTimeout: CGFloat = 30
    lazy var usernameValidationState = BehaviorRelay<UsernameValidationState>(value: .unknown)
    lazy var canAskForAccountCreation: Observable<Bool> = {
        return Observable.combineLatest(self.usernameValidationState.asObservable(),
                                        self.username.asObservable(),
                                        self.createState,
                                        resultSelector:
                                            { ( usernameValidationState: UsernameValidationState,
                                                username: String,
                                                creationState: AccountCreationState) -> Bool in

                                                var canAsk = true

                                                if !username.isEmpty {
                                                    canAsk = canAsk && usernameValidationState.isAvailable && !username.isEmpty
                                                }

                                                canAsk = canAsk && !creationState.isInProgress

                                                return canAsk
                                            })
    }()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService

        // Loookup name request observer
        self.username.asObservable()
            .subscribe(onNext: { [weak self] username in
                self?.nameService.lookupName(withAccount: "", nameserver: "", name: username)
            })
            .disposed(by: disposeBag)

        self.nameService.usernameValidationStatus.asObservable()
            .subscribe(onNext: { [weak self] (status) in
                switch status {
                case .lookingUp:
                    self?.usernameValidationState.accept(.lookingForAvailibility(message: L10n.CreateAccount.lookingForUsernameAvailability))
                case .invalid:
                    self?.usernameValidationState.accept(.invalid(message: L10n.CreateAccount.invalidUsername))
                case .alreadyTaken:
                    self?.usernameValidationState.accept(.unavailable(message: L10n.CreateAccount.usernameAlreadyTaken))
                case .valid:
                    self?.usernameValidationState.accept(.available(message: L10n.CreateAccount.usernameValid))
                default:
                    self?.usernameValidationState.accept(.unknown)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func createAccount() {
        self.accountCreationState.accept(.started)

        let username = self.username.value
        let password = self.password.value

        self.accountService
            .addJamiAccount(username: username,
                            password: password,
                            enable: self.notificationSwitch.value)
            .subscribe(onNext: { [weak self] (account) in
                guard let self = self else { return }
                if username.isEmpty {
                    self.accountCreationState.accept(.success)
                    DispatchQueue.main.async {
                        self.stateSubject.onNext(WalkthroughState.accountCreated)
                    }
                    return
                }
                let disposable = self.nameService.registerNameObservable(withAccount: account.id,
                                                                         password: password,
                                                                         name: username)
                    .subscribe(onNext: { registered in
                        if registered {
                            self.accountCreationState.accept(.success)
                            DispatchQueue.main.async {
                                self.stateSubject
                                    .onNext(WalkthroughState.accountCreated)
                            }
                        } else {
                            self.accountCreationState.accept(.nameNotRegistered)
                        }
                    }, onError: { _ in
                        self.accountCreationState.accept(.nameNotRegistered)
                    })
                DispatchQueue.main
                    .asyncAfter(deadline: .now() + self.nameRegistrationTimeout) {
                        disposable.dispose()
                        if self.accountCreationState.value.isCompleted {
                            return
                        }
                        self.accountCreationState.accept(.timeOut)
                    }
            }, onError: { [weak self] (error) in
                guard let self = self else { return }
                if let error = error as? AccountCreationError {
                    self.accountCreationState.accept(.error(error: error))
                } else {
                    self.accountCreationState.accept(.error(error: AccountCreationError.unknown))
                }
            })
            .disposed(by: self.disposeBag)
        self.enablePushNotifications(enable: self.notificationSwitch.value)
    }

    func finish() {
        self.stateSubject.onNext(WalkthroughState.accountCreated)
    }

    func enablePushNotifications(enable: Bool) {
        if !enable {
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
    }
}
