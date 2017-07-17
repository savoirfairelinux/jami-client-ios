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

class CreateAccountViewModel: Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let createAccountTitle  = Observable<String>.of(L10n.Createaccount.createAccountFormTitle.smartString)
    let createAccountButton = Observable<String>.of(L10n.Welcome.createAccount.smartString)

    let accountService: AccountsService

    init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
    }

    func createAccount() {

    }
}
