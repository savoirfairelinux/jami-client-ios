/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import SwiftyBeaver

final class ChatTabBarItemViewModel: ViewModel, TabBarItemViewModel {

    private let log = SwiftyBeaver.self

    private let itemBadgeValue: Variable<String?> = Variable(nil)
    lazy var itemBadgeValueObservable: Observable<String?> = {
        return self.itemBadgeValue.asObservable()
    }()

    private let conversationsService: ConversationsService
    private let accountsService: NewAccountsService
    private let contactsService: ContactsService

    private let disposeBag = DisposeBag()

    required init(with injectionBag: InjectionBag) {
        self.conversationsService = injectionBag.conversationsService
        self.accountsService = injectionBag.newAccountsService
        self.contactsService = injectionBag.contactsService

        self.registerToConversations()
    }

    private func registerToConversations() {
        let currentAccountObservable = self.accountsService.currentAccount().asObservable()
        let conversationsObservable = self.conversationsService.conversations.asObservable()

        let unreadMessagesObservable = Observable.combineLatest(currentAccountObservable, conversationsObservable) { [weak self] (account, conversations) -> Int in
            return conversations.map({ (conversation) -> Int in
                guard let accountRingId = AccountModelHelper(withAccount: account).ringId else {
                    return 0
                }
                guard let contactsService = self?.contactsService else {
                    return 0
                }
                return ConversationModelHelper.getNumberOfUnreadMessages(for: conversation,
                                                                         currentAccountRingId: accountRingId,
                                                                         contactsService: contactsService)
            }).reduce(0, +)
        }

        unreadMessagesObservable.subscribe(onNext: { [weak self] (value) in
            let unreadMessages = value == 0 ? nil : String(value)
            self?.itemBadgeValue.value = unreadMessages
        }, onError: { [weak self] (error) in
            self?.itemBadgeValue.value = nil
            self?.log.debug("Empty chat badge: \(error.localizedDescription)")
        }).disposed(by: self.disposeBag)
    }

}
