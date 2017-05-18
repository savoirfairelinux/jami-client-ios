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

import UIKit
import RxSwift

class SmartlistViewModel {

    fileprivate let disposeBag = DisposeBag()

    //Services
    fileprivate let conversationsService: ConversationsService
    fileprivate let nameService: NameService
    fileprivate let accountsService: AccountsService

    let searchBarText = Variable<String>("")
    var isSearching :Observable<Bool>!
    var conversations :Observable<[ConversationSection]>!
    var searchResults :Observable<[ConversationSection]>!
    var hideNoConversationsMessage: Observable<Bool>!
    var searchStatus = PublishSubject<String>()

    fileprivate var filteredResults = Variable([ConversationViewModel]())
    fileprivate var contactFoundConversation = Variable<ConversationViewModel?>(nil)
    fileprivate var conversationViewModels = [ConversationViewModel]()

    init(withConversationsService conversationsService: ConversationsService, nameService: NameService, accountsService: AccountsService) {

        self.conversationsService = conversationsService
        self.nameService = nameService
        self.accountsService = accountsService

        //Create observable from sorted conversations and flatMap them to view models
        let conversationsObservable :Observable<[ConversationViewModel]> = self.conversationsService.conversations.asObservable().map({ conversations in
            return conversations.sorted(by: { conversation1, conversations2 in

                guard let lastMessage1 = conversation1.messages.last,
                let lastMessage2 = conversations2.messages.last else {
                    return true
                }

                return lastMessage1.receivedDate > lastMessage2.receivedDate
            }).flatMap({ conversationModel in

                var conversationViewModel: ConversationViewModel?

                //Get the current ConversationViewModel if exists or create it
                if let foundConversationViewModel = self.conversationViewModels.filter({ conversationViewModel in
                    return conversationViewModel.conversation === conversationModel
                }).first {
                    conversationViewModel = foundConversationViewModel
                } else {
                    conversationViewModel = ConversationViewModel(withConversation: conversationModel)
                    self.conversationViewModels.append(conversationViewModel!)
                }

                return conversationViewModel
            })
        })

        //Create observable from conversations viewModels to ConversationSection
        self.conversations = conversationsObservable.map({ conversationsViewModels in
            return [ConversationSection(header: "", items: conversationsViewModels)]
        }).observeOn(MainScheduler.instance)

        //Create observable from filtered conversatiosn and contact founds viewModels to ConversationSection
        self.searchResults = Observable<[ConversationSection]>.combineLatest(self.contactFoundConversation.asObservable(), self.filteredResults.asObservable(), resultSelector: { contactFoundConversation, filteredResults in

            var sections = [ConversationSection]()

            if filteredResults.count > 0 {
                let headerTitle = NSLocalizedString("Conversations", tableName: "Smartlist", comment: "")
                sections.append(ConversationSection(header: headerTitle, items: filteredResults))
            }

            if contactFoundConversation != nil {
                let headerTitle = NSLocalizedString("UserFound", tableName: "Smartlist", comment: "")
                sections.append(ConversationSection(header: headerTitle, items: [contactFoundConversation!]))
            }

            return sections
        }).observeOn(MainScheduler.instance)

        self.hideNoConversationsMessage = Observable
            .combineLatest( self.conversations, self.searchBarText.asObservable(), resultSelector: { conversations, searchBarText in
            return conversations.first!.items.count > 0 || searchBarText.characters.count > 0
        }).observeOn(MainScheduler.instance)

        //Observes if the user is searching
        self.isSearching = searchBarText.asObservable().map({ text in
            return text.characters.count > 0
        }).observeOn(MainScheduler.instance)

        //Observes search bar text
        searchBarText.asObservable().subscribe(onNext: { [unowned self] text in
            self.search(withText: text)
        }).addDisposableTo(disposeBag)

        //Observe username lookup
        self.nameService.usernameLookupStatus.subscribe(onNext: { usernameLookupStatus in
            if usernameLookupStatus.state == .found && (usernameLookupStatus.name == self.searchBarText.value ) {

                if let conversation = self.conversationViewModels.filter({ conversationViewModel in
                    conversationViewModel.conversation.recipient.userName == self.searchBarText.value
                }).first {
                    self.contactFoundConversation.value = conversation
                } else {
                    let contact = ContactModel(withRingId: usernameLookupStatus.address)
                    contact.userName = usernameLookupStatus.name

                    //Create new converation
                    let conversation = ConversationModel(withRecipient: contact, accountId: "")
                    let newConversation = ConversationViewModel(withConversation: conversation)

                    self.contactFoundConversation.value = newConversation
                }

                self.searchStatus.onNext("")
            } else {
                if self.filteredResults.value.count == 0 {
                    let searchStatusText = NSLocalizedString("NoResults", tableName: "Smartlist", comment: "")
                    self.searchStatus.onNext(searchStatusText)
                } else {
                    self.searchStatus.onNext("")
                }
            }
        }).addDisposableTo(disposeBag)
    }

    fileprivate func search(withText text: String) {

        self.contactFoundConversation.value = nil
        self.filteredResults.value.removeAll()
        self.searchStatus.onNext("")

        if text.characters.count > 0 {

            //Filter conversations by user name or RingId
            let filteredConversations = self.conversationViewModels.filter({ conversationViewModel in
                if let recipientUserName = conversationViewModel.conversation.recipient.userName {
                    return recipientUserName.contains(text)
                } else {
                    return false
                }
            })

            if filteredConversations.count > 0 {
                self.filteredResults.value = filteredConversations
            }

            self.nameService.lookupName(withAccount: "", nameserver: "", name: text)
            let searchStatusText = NSLocalizedString("Searching", tableName: "Smartlist", comment: "")
            self.searchStatus.onNext(searchStatusText)
        }
    }

    func selected(item selectedItem: ConversationViewModel) {

        if !self.conversationViewModels.contains(where: { viewModel in
            return viewModel === selectedItem
        }) {
            self.conversationsService.addConversation(conversation: selectedItem.conversation)
        }
    }
}
