/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

class ChatTabBarItemViewModel: ViewModel, TabBarItemViewModel {

    var itemBadgeValue: Observable<String?>

    required init(with injectionBag: InjectionBag) {
        let conversationService = injectionBag.conversationsService
        let contactsService = injectionBag.contactsService
        self.itemBadgeValue = {
            return conversationService.conversationsForCurrentAccount
                .map({ conversations in
                    return conversations
                        .map({ conversation in
                            let unreadMsg = conversation.messages.filter({ message in
                                //filtre out read messages, outgoing messages and messages that are displayed in contactrequest conversation
                                return message.status != .displayed  && !message.isTransfer && message.incoming
                                    && (contactsService.contactRequest(withRingId: JamiURI.init(schema: URIType.ring, infoHach: message.authorURI).hash ?? "") == nil)
                            })
                            return unreadMsg.count
                        })
                        .reduce(0, +)
                })
            }()
            .map({ number in
                if number == 0 {
                    return nil
                }
                return "\(number)"
            })
    }
}
