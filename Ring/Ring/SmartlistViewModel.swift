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

class SmartlistViewModel: NSObject {

    fileprivate let conversationsService: ConversationsService
    fileprivate var conversationViewModels :[ConversationViewModel]

    let conversationsObservable :Observable<[ConversationViewModel]>

    init(withConversationsService conversationsService: ConversationsService) {
        self.conversationsService = conversationsService

        var conversationViewModels = [ConversationViewModel]()
        self.conversationViewModels = conversationViewModels

        //Create observable from sorted conversations and flatMap them to view models
        self.conversationsObservable = self.conversationsService.conversations.asObservable().map({ conversations in
            return conversations.sorted(by: { conversation1, conversations2 in

                guard let lastMessage1 = conversation1.messages.last,
                let lastMessage2 = conversations2.messages.last else {
                    return true
                }

                return lastMessage1.receivedDate > lastMessage2.receivedDate
            }).flatMap({ conversationModel in

                var conversationViewModel: ConversationViewModel?

                //Get the current ConversationViewModel if exists or create it
                if let foundConversationViewModel = conversationViewModels.filter({ conversationViewModel in
                    return conversationViewModel.conversation === conversationModel
                }).first {
                    conversationViewModel = foundConversationViewModel
                } else {
                    conversationViewModel = ConversationViewModel(withConversation: conversationModel)
                    conversationViewModels.append(conversationViewModel!)
                }

                return conversationViewModel
            })
        }).observeOn(MainScheduler.instance)
    }

}
