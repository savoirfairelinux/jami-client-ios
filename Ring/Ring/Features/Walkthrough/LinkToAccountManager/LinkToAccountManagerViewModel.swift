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

import RxSwift
import RxCocoa

class LinkToAccountManagerViewModel: Stateable, ViewModel {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    var userName = Variable<String>("")
    var password = Variable<String>("")
    var manager = Variable<String>("")
    fileprivate let accountsService: AccountsService
    fileprivate let disposeBag = DisposeBag()
    private let accountCreationState = Variable<AccountCreationState>(.unknown)
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()

    required init(with injectionBag: InjectionBag) {
        self.accountsService = injectionBag.accountService
    }

    func linkToAccountManager() {
        self.accountCreationState.value = .started
        self.accountsService
            .connectToAccountManager(username: userName.value,
                                     password: password.value,
                                     serverUri: manager.value)
            .subscribe(onNext: { [unowned self] (_) in
                self.accountCreationState.value = .success
                Observable<Int>.timer(Durations.alertFlashDuration.value,
                                      period: nil,
                                      scheduler: MainScheduler.instance)
                    .subscribe(onNext: { (_) in
                        self.stateSubject.onNext(WalkthroughState.accountCreated)
                    }).disposed(by: self.disposeBag)
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
