/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

class CreateSipAccountViewModel: Stateable, ViewModel {
    // MARK: - Rx Stateable

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    var userName = BehaviorRelay<String>(value: "")
    var password = BehaviorRelay<String>(value: "")
    var sipServer = BehaviorRelay<String>(value: "")
    private let accountsService: AccountsService

    required init(with injectionBag: InjectionBag) {
        accountsService = injectionBag.accountService
    }

    func createSipaccount() {
        let created = accountsService.addSipAccount(userName: userName.value,
                                                    password: password.value,
                                                    sipServer: sipServer.value)
        if created {
            DispatchQueue.main.async {
                self.stateSubject.onNext(WalkthroughState.accountCreated)
            }
        }
    }
}
