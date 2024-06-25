/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
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

import RxCocoa
import RxSwift

class LinkToAccountManagerViewModel: Stateable, ViewModel {
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    var userName = BehaviorRelay<String>(value: "")
    var password = BehaviorRelay<String>(value: "")
    var manager = BehaviorRelay<String>(value: "")
    private let accountsService: AccountsService
    private let disposeBag = DisposeBag()
    private let accountCreationState = BehaviorRelay<AccountCreationState>(value: .unknown)
    lazy var createState: Observable<AccountCreationState> = self.accountCreationState
        .asObservable()

    lazy var canLink: Observable<Bool> = Observable
        .combineLatest(self.userName.asObservable(),
                       self.password.asObservable(),
                       self.manager.asObservable(),
                       self.createState) { (
            name: String,
            password: String,
            manager: String,
            state: AccountCreationState
        ) -> Bool in
            !name.isEmpty && !password.isEmpty && !manager.isEmpty && !state.isInProgress
        }

    required init(with injectionBag: InjectionBag) {
        accountsService = injectionBag.accountService
    }

    func linkToAccountManager() {
        accountCreationState.accept(.started)
        accountsService
            .connectToAccountManager(username: userName.value,
                                     password: password.value,
                                     serverUri: manager.value,
                                     emableNotifications: true)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.accountCreationState.accept(.success)
                self.enablePushNotifications(enable: true)
                DispatchQueue.main.async {
                    self.stateSubject.onNext(WalkthroughState.accountCreated)
                }
            }, onError: { [weak self] error in
                if let error = error as? AccountCreationError {
                    self?.accountCreationState.accept(.error(error: error))
                } else {
                    self?.accountCreationState
                        .accept(.error(error: AccountCreationError.wrongCredentials))
                }
            })
            .disposed(by: disposeBag)
    }

    func enablePushNotifications(enable: Bool) {
        if !enable {
            return
        }
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue),
            object: nil
        )
    }
}
