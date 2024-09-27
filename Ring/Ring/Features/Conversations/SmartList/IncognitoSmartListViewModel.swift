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

class IncognitoSmartListViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()

    // Services
    private let accountService: AccountsService
    private let networkService: NetworkService
    private let contactService: ContactsService
    private let requestsService: RequestsService
    let conversationService: ConversationsService

    lazy var currentAccount: AccountModel? = {
        return self.accountService.currentAccount
    }()

    var searching = PublishSubject<Bool>()

    var connectionState = PublishSubject<ConnectionType>()
    var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return self.networkService.connectionState.value
    }

    let injectionBag: InjectionBag

    required init(with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.networkService = injectionBag.networkService
        self.contactService = injectionBag.contactsService
        self.conversationService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.injectionBag = injectionBag
        self.networkService.connectionStateObservable
            .subscribe(onNext: { [weak self] value in
                self?.connectionState.onNext(value)
            })
            .disposed(by: self.disposeBag)
    }

    private var temporaryConversation = BehaviorRelay<ConversationViewModel?>(value: nil) // created when searching for a new contact

    func enableBoothMode(enable: Bool, password: String) -> Bool {
        guard let accountId = self.accountService.currentAccount?.id else {
            return false
        }
        let result = self.accountService.setBoothMode(forAccount: accountId, enable: enable, password: password)
        if !result {
            return false
        }
        self.contactService.removeAllContacts(for: accountId)
        self.conversationService
            .getConversationsForAccount(accountId: accountId, accountURI: "")
        self.stateSubject.onNext(ConversationState.accountModeChanged)
        return true
    }

    func startCall(audioOnly: Bool) {
        guard let conversation = self.temporaryConversation.value?.conversation,
              let participantId = conversation.getParticipants().first?.jamiId,
              let username = self.temporaryConversation.value?.userName.value else {
            return
        }
        if audioOnly {
            self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: participantId, userName: username))
            return
        }
        self.stateSubject.onNext(ConversationState.startCall(contactRingId: participantId, userName: username))
    }
}

extension IncognitoSmartListViewModel: FilterConversationDelegate {
    func temporaryConversationCreated(conversation: ConversationViewModel?) {
        self.temporaryConversation.accept(conversation)
    }
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {

    }
}
