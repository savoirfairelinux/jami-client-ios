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

class SmartlistViewModel {

    fileprivate let disposeBag = DisposeBag()

    //Services
    fileprivate let messagesService: MessagesService
    fileprivate let nameService: NameService
    fileprivate let contactsService: ContactsService

    let conversations :Observable<[ConversationViewModel]>
    let searchResults :Observable<[ConversationViewModel]>
    let searchBarText = Variable<String>("")
    let isSearching :Observable<Bool>

    fileprivate var conversationViewModels :Variable<[ConversationViewModel]>
    fileprivate var searchResultsViewModels :Variable<[ConversationViewModel]>

    init(withMessagesService messagesService: MessagesService, nameService: NameService,
         contactsService: ContactsService) {

        self.messagesService = messagesService
        self.nameService = nameService
        self.contactsService = contactsService

        let conversationViewModels = Variable([ConversationViewModel]())
        self.conversationViewModels = conversationViewModels

        let searchResultsViewModels = Variable([ConversationViewModel]())
        self.searchResultsViewModels = searchResultsViewModels

        //Create observable from sorted conversations and flatMap them to view models
        self.conversations = self.messagesService.conversations.map({ conversations in
            return conversations.sorted(by: {
                return $0.lastMessageDate > $1.lastMessageDate
            }).flatMap({ conversationModel in

                var conversationViewModel: ConversationViewModel?

                //Get the current ConversationViewModel if exists or create it
                if let foundConversationViewModel = conversationViewModels.value.filter({ conversationViewModel in
                    return conversationViewModel.conversation.isEqual(conversationModel) 
                }).first {
                    conversationViewModel = foundConversationViewModel
                } else {
                    conversationViewModel = ConversationViewModel(withConversation: conversationModel)
                    conversationViewModels.value.append(conversationViewModel!)
                }

                return conversationViewModel
            })
        }).observeOn(MainScheduler.instance)

        self.searchResults = self.searchResultsViewModels.asObservable().observeOn(MainScheduler.instance)

        self.isSearching = searchBarText.asObservable().map({ text in
            return text.characters.count > 0
        }).observeOn(MainScheduler.instance)

        //Observes search bar text
        searchBarText.asObservable().observeOn(MainScheduler.instance).subscribe(onNext: { [unowned self] text in
            self.search(withText: text)
        }).addDisposableTo(disposeBag)

        //Observes contact search result
        self.contactsService.contactFound.observeOn(MainScheduler.instance).subscribe(onNext: { contact in
            let conversation = ConversationModel(withRecipient: contact)
            let newConversation = ConversationViewModel(withConversation: conversation)
            self.searchResultsViewModels.value = [newConversation]
        }).addDisposableTo(disposeBag)
    }

    func search(withText text: String) {
        self.searchResultsViewModels.value.removeAll()

        if text.characters.count > 0 {

            //Filter conversations by user name or RingId
            let filteredConversations = self.conversationViewModels.value.filter({ conversationViewModel in
                if conversationViewModel.conversation.isInvalidated {
                    return false
                }
                if let recipientUserName = conversationViewModel.conversation.recipient?.userName {
                    return recipientUserName.contains(text)
                } else {
                    return conversationViewModel.conversation.recipient!.ringId.contains(text)
                }
            })

            //Lookup the contact if no already in the smartlist
            if filteredConversations.count == 0 {
                self.contactsService.searchContact(withText: text)
            } else {
                self.searchResultsViewModels.value = filteredConversations
            }
        }
    }

    func delete(conversation: ConversationViewModel) {
        self.messagesService.deleteConversation(conversation: conversation.conversation)
    }
}
