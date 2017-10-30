/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

    var itemBageValue: Observable<String?>

    required init(with injectionBag: InjectionBag) {
        let accountService = injectionBag.accountService
        let conversationService = injectionBag.conversationsService
        let accountHelper = AccountModelHelper(withAccount: accountService.currentAccount!)
        self.itemBageValue = {
            return conversationService.conversations.map({ conversations in
                return conversations.map({ conversation in
                    return conversation.messages.filter({ message in
                        return message.status != .read && message.author != accountHelper.ringId!
                    }).count
                }).reduce(0, +)
            })
            }()
            .map { number in
                     if number == 0 {
                         return nil
                     }
                return "\(number)"
            }
    }
}
