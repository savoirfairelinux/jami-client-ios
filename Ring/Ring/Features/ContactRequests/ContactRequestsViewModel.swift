/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import Contacts
import SwiftyBeaver

final class ContactRequestsViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let contactsService: ContactsService
    private let accountsService: NewAccountsService
    private let conversationService: ConversationsService
    fileprivate let nameService: NameService
    private let presenceService: PresenceService
    private let contactRequestsManager: ContactRequestsManager

    fileprivate let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    private let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.newAccountsService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.presenceService = injectionBag.presenceService
        self.contactRequestsManager = injectionBag.contactRequestsManager

        self.injectionBag = injectionBag
    }

    lazy var contactRequestItems: Observable<[ContactRequestItem]> = {
        let contactRequestsObs = self.contactsService.contactRequests.asObservable()
        let currentAccountObs = self.accountsService.currentAccount().asObservable()

        return Observable.combineLatest(contactRequestsObs, currentAccountObs, resultSelector: { (requests, account) -> [ContactRequestItem] in
            return requests
                .filter { $0.accountId == account.id }
                .sorted { $0.receivedDate > $1.receivedDate }
                .map { contactRequest in
                    let item = ContactRequestItem(withContactRequest: contactRequest)
                    //TODO: Lookup username
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

    func accept(withItem item: ContactRequestItem) -> Completable {
        return self.accountsService.currentAccount().asObservable()
            .flatMap { [unowned self] (account) -> Completable in
                return self.contactRequestsManager.accept(contactRequest: item.contactRequest,
                                                          account: account)
            }.asCompletable()
    }

    func discard(withItem item: ContactRequestItem) -> Completable {
        return self.accountsService.currentAccount().asObservable()
            .flatMap { [unowned self] (account) -> Completable in
                return self.contactRequestsManager.discard(contactRequest: item.contactRequest,
                                                           account: account)
            }.asCompletable()
    }

    func ban(withItem item: ContactRequestItem) -> Completable {
        return self.accountsService.currentAccount().asObservable()
            .flatMap { [unowned self] (account) -> Completable in
                return self.contactRequestsManager.ban(contactRequest: item.contactRequest,
                                                       account: account)
            }.asCompletable()
    }

    func showConversation (forRingId ringId: String) {
        self.accountsService.currentAccount().subscribe(onSuccess: { [unowned self] (account) in
            let conversationViewModel = ConversationViewModel(with: self.injectionBag)
            let conversation = self.conversationService.findConversation(withRingId: ringId,
                                                                         withAccountId: account.id)
            conversationViewModel.conversation = conversation
            self.stateSubject.onNext(ConversationsState.conversationDetail(conversationViewModel: conversationViewModel))
        }, onError: { [unowned self] (error) in
            self.log.error("No account available")
        }).disposed(by: self.disposeBag)
    }
}

//extension ContactRequestsViewModel {
//
//    fileprivate func lookupUserName(withItem item: ContactRequestItem) {
//        self.nameService.usernameLookupStatus.asObservable()
//            .filter({ lookupNameResponse in
//                return lookupNameResponse.address == item.contactRequest.ringId
//            })
//            .subscribe(onNext: { lookupNameResponse in
//                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
//                    item.userName.value = lookupNameResponse.name
//                } else {
//                    item.userName.value = lookupNameResponse.address
//                }
//            })
//            .disposed(by: self.disposeBag)
//
//                self.nameService.lookupAddress(withAccount: (accountsService.currentAccount?.id)!,
//                                                      nameserver: "",
//                                                      address: item.contactRequest.ringId)
//    }
//
//}
