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
    fileprivate let messagesService: MessagesService
    fileprivate let nameService: NameService
    fileprivate let contactsService: ContactsService

    fileprivate let conversations = Variable([ConversationModel]())
    fileprivate let searchResults = Variable([ConversationModel]())

    let conversationsViewModels :Observable<[ConversationViewModel]>
    let searchResultsViewModels :Observable<[ConversationViewModel]>
    let searchBarText = Variable<String>("")
    let isSearching :Observable<Bool>

    init(withMessagesService messagesService: MessagesService, nameService: NameService,
         contactsService: ContactsService) {

        self.messagesService = messagesService
        self.nameService = nameService
        self.contactsService = contactsService

        //Sort Conversations and map them to ConversationViewModels
        let sortedViewModels: (([ConversationModel]) -> [ConversationViewModel]) = { conversations in
            return conversations.sorted(by: {
                //TODO: Sort by status
                return $0.lastMessageDate > $1.lastMessageDate
            }).flatMap({ conversationModel in
                return ConversationViewModel(withConversation: conversationModel)
            })
        }

        //Create observable from sorted conversations and flatMap them to view models
        self.conversationsViewModels = self.conversations.asObservable().map(sortedViewModels).observeOn(MainScheduler.instance)

        //Create observable from sorted conversations and flatMap them to view models
        self.searchResultsViewModels = self.searchResults.asObservable().map(sortedViewModels).observeOn(MainScheduler.instance)

        self.isSearching = searchBarText.asObservable().map({ text in
            return text.characters.count > 0
        })

        //Update new conversations
        self.messagesService.conversations.asObservable().subscribe(onNext: { [unowned self] newValue in
            self.conversations.value = newValue
        }).addDisposableTo(disposeBag)

        //Observes search bar text
        searchBarText.asObservable().subscribe(onNext: { [unowned self] text in
            self.search(withText: text)
        }).addDisposableTo(disposeBag)

        //Observes contact search result
        self.contactsService.contactFound.subscribe(onNext: { contact in
            let newConversation = ConversationModel(withRecipient: contact)
            self.searchResults.value.removeAll()
            self.searchResults.value.append(newConversation)
        }).addDisposableTo(disposeBag)
    }

    func search(withText text: String) {

        self.searchResults.value.removeAll()

        if text.characters.count > 0 {
            //Filter conversations by user name or RingId
            let filteredConversations = self.conversations.value.filter({ conversation in
                if let recipientUserName = conversation.recipient.userName {
                    return recipientUserName.contains(text)
                } else {
                    return conversation.recipient.ringId.contains(text)
                }
            })

            //Lookup the contact if no already in the smartlist
            if filteredConversations.count == 0 {
                self.contactsService.searchContact(withText: text)
            } else {
                self.searchResults.value.append(contentsOf: filteredConversations)
            }
        }
    }
}
