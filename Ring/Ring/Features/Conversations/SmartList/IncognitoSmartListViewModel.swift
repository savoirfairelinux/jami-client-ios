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

class IncognitoSmartListViewModel: Stateable, ViewModel, FilterConversationDataSource {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    fileprivate let disposeBag = DisposeBag()

    //Services
    fileprivate let accountService: AccountsService
    fileprivate let networkService: NetworkService
    fileprivate let contactService: ContactsService
    let conversationService: ConversationsService

    lazy var currentAccount: AccountModel? = {
        return self.accountService.currentAccount
    }()

    fileprivate var lookupName = BehaviorRelay<String?>(value: "")

    var searching = PublishSubject<Bool>()

    var switchBoothModeState = PublishSubject<Bool>()

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
        self.injectionBag = injectionBag
        self.networkService.connectionStateObservable
            .subscribe(onNext: { [weak self] value in
                self?.connectionState.onNext(value)
            })
            .disposed(by: self.disposeBag)
    }

    func conversationFound(conversation: ConversationViewModel?, name: String) {
        contactFoundConversation.value = conversation
        lookupName.accept(name)
    }
    fileprivate var contactFoundConversation = Variable<ConversationViewModel?>(nil)

    func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
    }

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
        .getConversationsForAccount(accountId: accountId)
        .subscribe()
        .disposed(by: self.disposeBag)
        self.stateSubject.onNext(ConversationState.accountModeChanged)
        return true
    }

    func startCall(audioOnly: Bool) {
        guard let currentAccount = self.accountService.currentAccount,
            let conversation = self.contactFoundConversation.value?.conversation.value else {
                return
        }
        let username: String = lookupName.value ?? ""
        self.contactService
            .sendContactRequest(toContactRingId: self.contactFoundConversation.value!.conversation.value.hash,
                                withAccount: currentAccount)
            .subscribe(onCompleted: { [weak self, weak conversation] in
                guard let self = self, let conversation = conversation else {
                    return
                }
                if audioOnly {
                    self.stateSubject.onNext(ConversationState.startAudioCall(contactRingId: conversation.hash, userName: username))
                    return
                }
                self.stateSubject.onNext(ConversationState.startCall(contactRingId: conversation.hash, userName: username))
            }).disposed(by: self.disposeBag)
    }
}
