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
import SwiftUI

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
    case lookingForAvailability(message: String)
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
        case .lookingForAvailability:
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
        case .lookingForAvailability(let message):
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
        case .available:
            return .jamiSuccess
        case .lookingForAvailability:
            return .clear
        case .invalid:
            return .jamiFailure
        case .unavailable:
            return .jamiFailure
        }
    }
}

enum AccountCreationState {
    case initial
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

class CreateAccountViewModel: ObservableObject, ViewModel {
    @Published var isJoinButtonDisabled = false
    @Published var usernameValidationState: UsernameValidationState = .unknown
    @Published var username: String = ""

    private let disposeBag = DisposeBag()
    private let nameService: NameService

    required init(with injectionBag: InjectionBag) {
        self.nameService = injectionBag.nameService
        bindUsernameValidationStatus()
    }

    private func bindUsernameValidationStatus() {
        nameService.usernameValidationStatus.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                self.updateValidationState(with: status)
                self.updateJoinButtonAvailability()
            })
            .disposed(by: disposeBag)
    }

    private func updateValidationState(with status: UsernameValidationStatus) {
        if username.isEmpty {
            usernameValidationState = .unknown
            return
        }
        switch status {
            case .lookingUp:
                usernameValidationState = .lookingForAvailability(message: L10n.CreateAccount.lookingForUsernameAvailability)
            case .invalid:
                usernameValidationState = .invalid(message: L10n.CreateAccount.invalidUsername)
            case .alreadyTaken:
                usernameValidationState = .unavailable(message: L10n.CreateAccount.usernameAlreadyTaken)
            case .valid:
                usernameValidationState = .available(message: L10n.CreateAccount.usernameValid)
            default:
                usernameValidationState = .unknown
        }
    }

    deinit {
        print("*******create account view destroyed")
    }

    private func updateJoinButtonAvailability() {
        isJoinButtonDisabled = !username.isEmpty && !usernameValidationState.isAvailable
    }

    func usernameUpdated(to newUsername: String) {
        guard username != newUsername else { return }
        username = newUsername
        if username.isEmpty {
            self.usernameValidationState = .unknown
            self.updateJoinButtonAvailability()
        } else {
            nameService.lookupName(withAccount: "", nameserver: "", name: username)
        }
    }
}
