/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import Contacts
import RxCocoa
import RxSwift
import SwiftyBeaver

class ContactRequestsViewModel: Stateable, ViewModel {
    // MARK: - Rx Stateable

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    let contactsService: ContactsService
    let accountsService: AccountsService
    let conversationService: ConversationsService
    let nameService: NameService
    let presenceService: PresenceService
    let profileService: ProfilesService
    let requestsService: RequestsService

    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    private let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        contactsService = injectionBag.contactsService
        accountsService = injectionBag.accountService
        conversationService = injectionBag.conversationsService
        nameService = injectionBag.nameService
        presenceService = injectionBag.presenceService
        profileService = injectionBag.profileService
        requestsService = injectionBag.requestsService

        self.injectionBag = injectionBag
    }

    lazy var contactRequestItemsNotFiltered: Observable<[RequestItem]> = self.requestsService
        .requests
        .asObservable()
        .map { [weak self] requests in
            guard let self = self else { return [] }
            // filter out existing conversations
            let conversationIds = self.conversationService.conversations.value
                .map { conversation in
                    conversation.id
                }
            return requests
                .filter { $0.accountId == self.accountsService.currentAccount?.id
                    && !conversationIds.contains($0.conversationId)
                }
                .sorted { $0.receivedDate > $1.receivedDate }
                .map { contactRequest in
                    let item = RequestItem(withRequest: contactRequest,
                                           profileService: self.profileService,
                                           contactService: self.contactsService)
                    self.lookupUserName(withItem: item)
                    return item
                }
        }

    let filter = BehaviorRelay(value: "")

    lazy var contactRequestItems: Observable<[RequestItem]> = Observable
        .combineLatest(contactRequestItemsNotFiltered,
                       filter.asObservable()) { requests, filter -> [RequestItem] in
            requests.filter { request in
                request.userName.value.contains(filter) || request.profileName.value
                    .contains(filter) || filter.isEmpty
            }
        }

    lazy var hasInvitations: Observable<Bool> = self.requestsService.requests
        .asObservable()
        .map { [weak self] requests -> Bool in
            guard let self = self,
                  let account = self.accountsService.currentAccount
            else {
                return false
            }
            // filter out existing conversations
            let conversationIds = self.conversationService.conversations.value
                .map { conversation in
                    conversation.id
                }
            return !requests
                .filter {
                    $0.accountId == account.id && !conversationIds.contains($0.conversationId)
                }
                .isEmpty
        }

    func accept(withItem item: RequestItem) -> Observable<Void> {
        guard let jamiId = item.request.participants.first?.jamiId
        else { return Observable.empty() }
        if item.request.type == .contact && contactsService.contact(withHash: jamiId) == nil {
            let acceptCompleted = requestsService.acceptContactRequest(
                jamiId: item.request.participants.first!.jamiId,
                withAccount: item.request.accountId
            )
            presenceService.subscribeBuddy(withAccountId: item.request.accountId,
                                           withUri: jamiId,
                                           withFlag: true)
            return acceptCompleted.asObservable()
        }
        return requestsService.acceptConverversationRequest(
            conversationId: item.request.conversationId,
            withAccount: item.request.accountId
        )
    }

    func discard(withItem item: RequestItem) -> Observable<Void> {
        guard let jamiId = item.request.participants.first?.jamiId
        else { return Observable.empty() }
        // for conversation we discard contact request if it one to one conversation and contact not
        // added yet
        if item.request
            .type == .contact ||
            (item.request.isDialog() && contactsService.contact(withHash: jamiId) == nil) {
            return requestsService.discardContactRequest(
                jamiId: jamiId,
                withAccount: item.request.accountId
            )
        }
        return requestsService.discardConverversationRequest(
            conversationId: item.request.conversationId,
            withAccount: item.request.accountId
        )
    }

    func ban(withItem item: RequestItem) -> Observable<Void> {
        guard let jamiId = item.request.participants.first?.jamiId
        else { return Observable.empty() }
        if item.request
            .type == .contact ||
            (item.request.isDialog() && contactsService.contact(withHash: jamiId) == nil) {
            let discardCompleted = requestsService.discardContactRequest(
                jamiId: jamiId,
                withAccount: item.request.accountId
            )
            let removeCompleted = contactsService.removeContact(withId: jamiId,
                                                                ban: true,
                                                                withAccountId: item.request
                                                                    .accountId)

            return Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
            }
        }
        return requestsService.discardConverversationRequest(
            conversationId: item.request.conversationId,
            withAccount: item.request.accountId
        )
    }

    func deleteRequest(item: RequestItem) {
        let accountId = item.request.accountId
        let conversationId = item.request.conversationId
        if item.request.isCoredialog(),
           let participantId = item.request.participants.first?.jamiId {
            contactsService
                .removeContact(withId: participantId,
                               ban: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self] in
                    guard let self = self else { return }
                    self.conversationService.removeConversation(
                        conversationId: conversationId,
                        accountId: accountId
                    )
                })
                .disposed(by: disposeBag)
        } else {
            conversationService.removeConversation(
                conversationId: conversationId,
                accountId: accountId
            )
        }
    }

    private func lookupUserName(withItem item: RequestItem) {
        guard let jamiId = item.request.participants.first?.jamiId else { return }

        nameService.usernameLookupStatus.asObservable()
            .filter { lookupNameResponse in
                lookupNameResponse.address == jamiId
            }
            .subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found, !lookupNameResponse.name.isEmpty {
                    item.userName.accept(lookupNameResponse.name)
                } else {
                    item.userName.accept(lookupNameResponse.address)
                }
            })
            .disposed(by: disposeBag)
        guard let currentAccount = accountsService.currentAccount else { return }

        nameService.lookupAddress(withAccount: currentAccount.id,
                                  nameserver: "",
                                  address: jamiId)
    }

    func showConversation(forItem item: RequestItem) {
        let conversationViewModel = ConversationViewModel(with: injectionBag)
        let conversation = ConversationModel(
            withId: item.request.conversationId,
            accountId: item.request.accountId
        )
        let name = item.profileName.value.isEmpty ? item.userName.value : item.profileName.value
        conversationViewModel.displayName.accept(name)
        conversationViewModel.profileImageData.accept(item.profileImageData.value)
        conversationViewModel.conversation = conversation
        stateSubject
            .onNext(ConversationState
                        .conversationDetail(conversationViewModel: conversationViewModel))
    }
}
