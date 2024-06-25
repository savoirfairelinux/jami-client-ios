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

class IncognitoSmartListViewModel: Stateable, ViewModel, FilterConversationDataSource {
    // MARK: - Rx Stateable

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    private let disposeBag = DisposeBag()

    // Services
    private let accountService: AccountsService
    private let networkService: NetworkService
    private let contactService: ContactsService
    private let requestsService: RequestsService
    let conversationService: ConversationsService

    lazy var currentAccount: AccountModel? = self.accountService.currentAccount

    var searching = PublishSubject<Bool>()

    var connectionState = PublishSubject<ConnectionType>()
    var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return networkService.connectionState.value
    }

    let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        accountService = injectionBag.accountService
        networkService = injectionBag.networkService
        contactService = injectionBag.contactsService
        conversationService = injectionBag.conversationsService
        requestsService = injectionBag.requestsService
        self.injectionBag = injectionBag
        networkService.connectionStateObservable
            .subscribe(onNext: { [weak self] value in
                self?.connectionState.onNext(value)
            })
            .disposed(by: disposeBag)
    }

    private var temporaryConversation =
        BehaviorRelay<ConversationViewModel?>(value: nil) // created when searching for a new
    // contact

    func enableBoothMode(enable: Bool, password: String) -> Bool {
        guard let accountId = accountService.currentAccount?.id else {
            return false
        }
        let result = accountService.setBoothMode(
            forAccount: accountId,
            enable: enable,
            password: password
        )
        if !result {
            return false
        }
        contactService.removeAllContacts(for: accountId)
        conversationService
            .getConversationsForAccount(accountId: accountId, accountURI: "")
        stateSubject.onNext(ConversationState.accountModeChanged)
        return true
    }

    func startCall(audioOnly: Bool) {
        guard let conversation = temporaryConversation.value?.conversation,
              let participantId = conversation.getParticipants().first?.jamiId,
              let username = temporaryConversation.value?.userName.value
        else {
            return
        }
        if audioOnly {
            stateSubject.onNext(ConversationState.startAudioCall(
                contactRingId: participantId,
                userName: username
            ))
            return
        }
        stateSubject.onNext(ConversationState.startCall(
            contactRingId: participantId,
            userName: username
        ))
    }
}

extension IncognitoSmartListViewModel: FilterConversationDelegate {
    func temporaryConversationCreated(conversation: ConversationViewModel?) {
        temporaryConversation.accept(conversation)
    }

    func showConversation(withConversationViewModel _: ConversationViewModel) {}
}
