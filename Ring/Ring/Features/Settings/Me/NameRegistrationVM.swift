/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import SwiftUI
import UIKit
import RxSwift

class NameRegistrationVM: ObservableObject {
    let nameService: NameService
    let account: AccountModel
    let disposeBag = DisposeBag()

    var nameRegisteredCb: (() -> Void)

    @Published var state: RegistrationState = .initial

    @Published var registerButtonAvailable: Bool = false
    @Published var name = "" {
        didSet {
            if !name.isEmpty && name != oldValue {
                self.nameService.lookupName(withAccount: account.id, nameserver: "", name: name)
            }
        }
    }
    @Published var password = "" {
        didSet {
            valideateRegisterButtonState()
        }
    }
    @Published var usernameValidationState: UsernameValidationState = .unknown {
        didSet {
            valideateRegisterButtonState()
        }
    }

    enum RegistrationState: Equatable {
        case initial
        case started
        case success
        case error(title: String, message: String)

        static func == (lhs: RegistrationState, rhs: RegistrationState) -> Bool {
            switch (lhs, rhs) {
            case (.started, .started):
                return true
            case (.initial, .initial):
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

    init(injectionBag: InjectionBag, account: AccountModel, nameRegisteredCb: @escaping (() -> Void)) {
        self.account = account
        self.nameService = injectionBag.nameService
        self.nameRegisteredCb = nameRegisteredCb
        self.subscribeForNameLookup()
    }

    func hasPassword() -> Bool {
        return AccountModelHelper(withAccount: account).hasPassword
    }

    func registerUsername() {
        self.state = .started
        self.nameService
            .registerNameObservable(accountId: self.account.id,
                                    password: self.password,
                                    name: self.name)
            .subscribe(onNext: { [weak self] registered in
                self?.handleRegistrationResult(registered: registered)
            }, onError: { [weak self] _ in
                self?.handleRegistrationResult(registered: false)
            })
            .disposed(by: self.disposeBag)
    }

    private func handleRegistrationResult(registered: Bool) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            if registered {
                self.state = .success
                self.nameRegisteredCb()
            } else {
                self.state = .error(
                    title: L10n.AccountPage.usernameRegistrationFailedTitle,
                    message: L10n.AccountPage.usernameRegistrationFailed
                )
            }
        }
    }

    func subscribeForNameLookup() {
        nameService.usernameValidationStatus.asObservable()
            .subscribe(onNext: {[weak self] (status) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch status {
                    case .lookingUp:
                        self.usernameValidationState = .lookingForAvailability(message: L10n.CreateAccount.lookingForUsernameAvailability)
                    case .invalid:
                        self.usernameValidationState = .invalid(message: L10n.CreateAccount.invalidUsername)
                    case .alreadyTaken:
                        self.usernameValidationState = .unavailable(message: L10n.CreateAccount.usernameAlreadyTaken)
                    case .valid:
                        self.usernameValidationState = .available(message: L10n.CreateAccount.usernameValid)
                    default:
                        self.usernameValidationState = .unknown
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    func valideateRegisterButtonState() {
        guard usernameValidationState.isAvailable else {
            registerButtonAvailable = false
            return
        }
        if self.hasPassword() {
            registerButtonAvailable = !self.password.isEmpty
        } else {
            registerButtonAvailable = true
        }
    }
}
