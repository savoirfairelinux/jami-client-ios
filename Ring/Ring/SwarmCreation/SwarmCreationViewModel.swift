/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Binal Ahiya <binal.ahiya@savoirfairelinux.com>
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

import UIKit
import RxSwift
import RxCocoa

class SwarmCreationViewModel: ViewModel, Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    let disposeBag = DisposeBag()
    let injectionBag: InjectionBag

    private let accountsService: AccountsService
    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    required init(with injectionBag: InjectionBag) {
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
    }

    func showConversation(withConversationId conversationId: String, andWithAccountId accountId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.stateSubject.onNext(ConversationState.openConversationForConversationId(conversationId: conversationId, accountId: accountId, shouldOpenSmarList: false))
        }
    }
}
