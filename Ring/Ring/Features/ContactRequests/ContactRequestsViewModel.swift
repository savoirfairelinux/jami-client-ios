/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import Contacts
import SwiftyBeaver

class ContactRequestsViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let contactsService: ContactsService
    let accountsService: AccountsService
    let conversationService: ConversationsService
    let nameService: NameService
    let presenceService: PresenceService
    let profileService: ProfilesService

    fileprivate let disposeBag = DisposeBag()
    fileprivate let log = SwiftyBeaver.self

    fileprivate let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.presenceService = injectionBag.presenceService
        self.profileService = injectionBag.profileService

        self.injectionBag = injectionBag
    }

    lazy var contactRequestItems: Observable<[ContactRequestItem]> = {
        return self.contactsService.contactRequests
            .asObservable()
            .map({ [unowned self] contactRequests in
                return contactRequests
                    .filter { $0.accountId == self.accountsService.currentAccount?.id }
                    .sorted { $0.receivedDate > $1.receivedDate }
                    .map { contactRequest in
                        let item = ContactRequestItem(withContactRequest: contactRequest,
                                                      profileService: self.profileService,
                                                      contactService: self.contactsService)
                        self.lookupUserName(withItem: item)
                        return item
                    }
            })
    }()

    lazy var hasInvitations: Observable<Bool> = {
        return self.contactsService.contactRequests
            .asObservable()
            .map({ items in
                return !items.isEmpty
            })
    }()

    func accept(withItem item: ContactRequestItem) -> Observable<Void> {
        let acceptCompleted = self.contactsService.accept(contactRequest: item.contactRequest, withAccount: self.accountsService.currentAccount!)
        self.presenceService.subscribeBuddy(withAccountId: (self.accountsService.currentAccount?.id)!,
                                            withUri: item.contactRequest.ringId,
                                            withFlag: true)
        return acceptCompleted.asObservable()
    }

    func discard(withItem item: ContactRequestItem) -> Observable<Void> {
        return self.contactsService.discard(contactRequest: item.contactRequest,
                                            withAccountId: item.contactRequest.accountId)
    }

    func ban(withItem item: ContactRequestItem) -> Observable<Void> {
        let discardCompleted = self.contactsService.discard(contactRequest: item.contactRequest,
                                                            withAccountId: item.contactRequest.accountId)
        let removeCompleted = self.contactsService.removeContact(withRingId: item.contactRequest.ringId,
                                                                 ban: true,
                                                                 withAccountId: item.contactRequest.accountId)

        return Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
            return
        }
    }

    fileprivate func lookupUserName(withItem item: ContactRequestItem) {

        self.nameService.usernameLookupStatus.asObservable()
            .filter({ lookupNameResponse in
                return lookupNameResponse.address == item.contactRequest.ringId
            })
            .subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
                    item.userName.value = lookupNameResponse.name
                } else {
                    item.userName.value = lookupNameResponse.address
                }
            })
            .disposed(by: self.disposeBag)

        self.nameService.lookupAddress(withAccount: (accountsService.currentAccount?.id)!,
                                              nameserver: "",
                                              address: item.contactRequest.ringId)
    }

    func showConversation (forRingId ringId: String) {
        let conversationViewModel = ConversationViewModel(with: self.injectionBag)
        guard let account = accountsService.currentAccount else {
            return
        }

        guard let conversation = self.conversationService.findConversation(withRingId: ringId, withAccountId: account.id) else {
            return
        }
        conversationViewModel.conversation = Variable<ConversationModel>(conversation)
        self.stateSubject.onNext(ConversationsState.conversationDetail(conversationViewModel: conversationViewModel))
    }
}
