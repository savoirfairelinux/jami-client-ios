/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

final class LinkDeviceViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let accountService: NewAccountsService
    private let accountCreationState = Variable<AccountCreationState>(.unknown)
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()

    lazy var linkButtonEnabledState: Observable<Bool>  = {
        return self.pin.asObservable().map({ pin in
            return !pin.isEmpty
        })
    }()

    let pin = Variable<String>("")
    let password = Variable<String>("")
    let disposeBag = DisposeBag()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.newAccountsService
    }

    func linkDevice () {
        self.accountCreationState.value = .started

        let pin = self.pin.value
        let password = self.password.value

        self.accountService
            .linkToRingAccount(withPin: pin, password: password)
            .subscribe(onNext: { [weak self] (_) in
                self?.accountCreationState.value = .success
                self?.stateSubject.onNext(WalkthroughState.deviceLinked)
            }, onError: { [weak self] (error) in
                if let error = error as? AccountCreationError {
                    self?.accountCreationState.value = .error(error: error)
                } else {
                    self?.accountCreationState.value = .error(error: AccountCreationError.unknown)
                }
            })
            .disposed(by: self.disposeBag)
    }

}
