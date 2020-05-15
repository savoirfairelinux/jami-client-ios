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

import Foundation
import RxSwift
import RxCocoa

protocol FilterConversationDataSource {
    var conversationViewModels: [ConversationViewModel] { get set }
    func conversationFound(conversation: ConversationViewModel?, name: String)
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel)
}

class JamiSearchViewModel {

    //Services
    fileprivate let nameService: NameService
    fileprivate let accountsService: AccountsService
    fileprivate let injectionBag: InjectionBag

    fileprivate let disposeBag = DisposeBag()

    lazy var searchResults: Observable<[ConversationSection]> = {
        return Observable<[ConversationSection]>
            .combineLatest(self.contactFoundConversation
                .asObservable(),
                           self.filteredResults.asObservable(),
                           resultSelector: { contactFoundConversation, filteredResults in
                            var sections = [ConversationSection]()
                            if !filteredResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.conversations, items: filteredResults))
                            } else if contactFoundConversation != nil {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: [contactFoundConversation!]))
                            }
                            return sections
            }).observeOn(MainScheduler.instance)
    }()

    fileprivate var contactFoundConversation = BehaviorRelay<ConversationViewModel?>(value: nil)
    fileprivate var filteredResults = Variable([ConversationViewModel]())

    let searchBarText = Variable<String>("")
    var isSearching: Observable<Bool>!
    var searchStatus = PublishSubject<String>()
    let dataSource: FilterConversationDataSource

    init(with injectionBag: InjectionBag, source: FilterConversationDataSource) {
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
        dataSource = source

        //Observes if the user is searching
        self.isSearching = searchBarText.asObservable()
            .map({ text in
            return !text.isEmpty
        }).observeOn(MainScheduler.instance)

        //Observes search bar text
        searchBarText.asObservable()
            .observeOn(MainScheduler.instance)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] text in
            self?.search(withText: text)
        }).disposed(by: disposeBag)

        //Observe username lookup
        self.nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self, unowned injectionBag] usernameLookupStatus in
                if usernameLookupStatus.state == .found &&
                    (usernameLookupStatus.name == self.searchBarText.value
                        || usernameLookupStatus.address == self.searchBarText.value) {
                    if let conversation = self.dataSource.conversationViewModels.filter({ conversationViewModel in
                        conversationViewModel.conversation.value.participantUri == usernameLookupStatus.address || conversationViewModel.conversation.value.hash == usernameLookupStatus.address
                    }).first {
                        self.contactFoundConversation.accept(conversation)
                        self.dataSource.conversationFound(conversation: conversation, name: self.searchBarText.value)
                    } else {
                        if self.contactFoundConversation.value?.conversation.value
                            .participantUri != usernameLookupStatus.address && self.contactFoundConversation.value?.conversation.value
                                .hash != usernameLookupStatus.address {
                            if let account = self.accountsService.currentAccount {
                                let uri = JamiURI.init(schema: URIType.ring, infoHach: usernameLookupStatus.address)
                                //Create new converation
                                let conversation = ConversationModel(withParticipantUri: uri, accountId: account.id)
                                let newConversation = ConversationViewModel(with: injectionBag)
                                newConversation.conversation = Variable<ConversationModel>(conversation)
                                self.contactFoundConversation.accept(newConversation)
                                self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
                            }
                        }
                    }
                    self.searchStatus.onNext("")
                } else {
                    if self.filteredResults.value.isEmpty
                        && self.contactFoundConversation.value == nil {
                        self.searchStatus.onNext(L10n.Smartlist.noResults)
                    } else {
                        self.searchStatus.onNext("")
                    }
                }
            }).disposed(by: disposeBag)
    }

    fileprivate func search(withText text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }

        self.contactFoundConversation.accept(nil)
        self.dataSource.conversationFound(conversation: nil, name: "")
        self.filteredResults.value.removeAll()
        self.searchStatus.onNext("")

        if text.isEmpty {return}

        //Filter conversations
        let filteredConversations = self.dataSource.conversationViewModels
            .filter({conversationViewModel in
                conversationViewModel.conversation.value.participantUri == text
                || conversationViewModel.conversation.value.hash == text
            })

        if !filteredConversations.isEmpty {
            self.filteredResults.value = filteredConversations
        }

        if currentAccount.type == AccountType.sip {
            let uri = JamiURI.init(schema: URIType.sip, infoHach: text, account: currentAccount)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id,
                                                 hash: text)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = Variable<ConversationModel>(conversation)
            self.contactFoundConversation.accept(newConversation)
            self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
            return
        }

        if !text.isSHA1() {
            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
            self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        if self.contactFoundConversation.value?.conversation.value.participantUri != text && self.contactFoundConversation.value?.conversation.value.hash != text {
            let uri = JamiURI.init(schema: URIType.ring, infoHach: text)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = Variable<ConversationModel>(conversation)
            self.contactFoundConversation.accept(newConversation)
            self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
        }
    }

    func showConversation(conversation: ConversationViewModel) {
        dataSource.showConversation(withConversationViewModel: conversation)
    }
}
