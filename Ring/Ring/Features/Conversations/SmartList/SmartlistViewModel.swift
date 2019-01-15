/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

class SmartlistViewModel: Stateable, ViewModel {

    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    fileprivate let disposeBag = DisposeBag()

    //Services
    fileprivate let conversationsService: ConversationsService
    fileprivate let nameService: NameService
    fileprivate let accountsService: AccountsService
    fileprivate let contactsService: ContactsService
    fileprivate let networkService: NetworkService

    let searchBarText = Variable<String>("")
    var isSearching: Observable<Bool>!
    var conversations: Observable<[ConversationSection]>!
    var searchResults: Observable<[ConversationSection]>!
    var hideNoConversationsMessage: Observable<Bool>!
    var searchStatus = PublishSubject<String>()
    var connectionState = PublishSubject<ConnectionType>()

    fileprivate var filteredResults = Variable([ConversationViewModel]())
    fileprivate var contactFoundConversation = Variable<ConversationViewModel?>(nil)
    fileprivate var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return self.networkService.connectionState.value
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    required init(with injectionBag: InjectionBag) {
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.networkService = injectionBag.networkService

        // Observe connectivity changes
        self.networkService.connectionStateObservable
            .subscribe(onNext: { value in
                self.connectionState.onNext(value)
            })
            .disposed(by: self.disposeBag)

        //Create observable from sorted conversations and flatMap them to view models
        let conversationsObservable: Observable<[ConversationViewModel]> = self.conversationsService.conversationsForCurrentAccount.map({ [weak self] conversations in
            return conversations
                .sorted(by: { conversation1, conversations2 in

                    guard let lastMessage1 = conversation1.messages.last,
                        let lastMessage2 = conversations2.messages.last else {
                            return true
                    }

                    return lastMessage1.receivedDate > lastMessage2.receivedDate
                })
                .filter({ self?.contactsService.contact(withRingId: $0.recipientRingId) != nil
                    || (!$0.messages.isEmpty && (self?.contactsService.contactRequest(withRingId: $0.recipientRingId) == nil))
                })
                .flatMap({ conversationModel in

                    var conversationViewModel: ConversationViewModel?

                    //Get the current ConversationViewModel if exists or create it
                    if let foundConversationViewModel = self?.conversationViewModels.filter({ conversationViewModel in
                        return conversationViewModel.conversation.value == conversationModel
                    }).first {
                        conversationViewModel = foundConversationViewModel
                    } else if let contactFound = self?.contactFoundConversation.value, contactFound.conversation.value == conversationModel {
                        conversationViewModel = contactFound
                        self?.conversationViewModels.append(contactFound)
                    } else {
                        conversationViewModel = ConversationViewModel(with: injectionBag)
                        conversationViewModel?.conversation = Variable<ConversationModel>(conversationModel)
                        self?.conversationViewModels.append(conversationViewModel!)
                    }

                    return conversationViewModel
                })
        })

        //Create observable from conversations viewModels to ConversationSection
        self.conversations = conversationsObservable.map({ conversationsViewModels in
            return [ConversationSection(header: "", items: conversationsViewModels)]
        }).observeOn(MainScheduler.instance)

        //Create observable from filtered conversatiosn and contact founds viewModels to ConversationSection
        self.searchResults = Observable<[ConversationSection]>.combineLatest(self.contactFoundConversation.asObservable(),
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

        self.hideNoConversationsMessage = Observable
            .combineLatest( self.conversations, self.searchBarText.asObservable(), resultSelector: { conversations, searchBarText in
            return !conversations.first!.items.isEmpty || !searchBarText.isEmpty
        }).observeOn(MainScheduler.instance)

        //Observes if the user is searching
        self.isSearching = searchBarText.asObservable().map({ text in
            return !text.isEmpty
        }).observeOn(MainScheduler.instance)

        //Observes search bar text
        searchBarText.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] text in
            self.search(withText: text)
        }).disposed(by: disposeBag)

        //Observe username lookup
        self.nameService.usernameLookupStatus.observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self, unowned injectionBag]  usernameLookupStatus in
            if usernameLookupStatus.state == .found && usernameLookupStatus.name == self.searchBarText.value {

                if let conversation = self.conversationViewModels.filter({ conversationViewModel in
                    conversationViewModel.conversation.value.recipientRingId == usernameLookupStatus.address
                }).first {
                    self.contactFoundConversation.value = conversation
                } else {
                    if self.contactFoundConversation.value?.conversation.value
                        .recipientRingId != usernameLookupStatus.address {

                        var ringId = ""
                        var accountId = ""
                        if let account = self.accountsService.currentAccount {
                            accountId = account.id
                            if let uri = AccountModelHelper(withAccount: account).ringId {
                            ringId = uri
                            }
                        }

                        //Create new converation
                        let conversation = ConversationModel(withRecipientRingId: usernameLookupStatus.address, accountId: accountId, accountUri: ringId)
                        let newConversation = ConversationViewModel(with: injectionBag)
                        newConversation.conversation = Variable<ConversationModel>(conversation)
                        self.contactFoundConversation.value = newConversation
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

        self.contactFoundConversation.value = nil
        self.filteredResults.value.removeAll()
        self.searchStatus.onNext("")

        if !text.isEmpty {

            //Filter conversations by user name or RingId
            let filteredConversations = self.conversationViewModels.filter({ [unowned self] conversationViewModel in

                let contact = self.contactsService.contact(withRingId: conversationViewModel.conversation.value.recipientRingId)

                if let recipientUserName = contact?.userName {
                    return recipientUserName.lowercased().hasPrefix(text.lowercased())
                } else {
                    return false
                }
            })

            if !filteredConversations.isEmpty {
                self.filteredResults.value = filteredConversations
            }

            self.nameService.lookupName(withAccount: "", nameserver: "", name: text)
            self.searchStatus.onNext(L10n.Smartlist.searching)
        }
    }

    func delete(conversationViewModel: ConversationViewModel) {

        if let index = self.conversationViewModels.index(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {

            self.conversationsService
                .deleteConversation(conversation: conversationViewModel.conversation.value,
                                    keepContactInteraction: true)
            self.conversationViewModels.remove(at: index)
        }
    }

    func blockConversationsContact(conversationViewModel: ConversationViewModel) {
        if let index = self.conversationViewModels.index(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {
            let contactRingId = conversationViewModel.conversation.value.recipientRingId
            let accountId = conversationViewModel.conversation.value.accountId
            let removeCompleted = self.contactsService.removeContact(withRingId: contactRingId,
                                                                     ban: true,
                                                                     withAccountId: accountId)
            removeCompleted.asObservable()
                .subscribe(onCompleted: { [weak self] in
                    self?.conversationsService
                        .deleteConversation(conversation: conversationViewModel.conversation.value,
                                            keepContactInteraction: false)
                    self?.conversationViewModels.remove(at: index)
                }).disposed(by: self.disposeBag)
        }
    }

    func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
        conversationViewModel))
    }

    func showQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode())
    }
}
