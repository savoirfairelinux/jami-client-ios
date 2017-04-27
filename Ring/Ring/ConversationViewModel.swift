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

class ConversationViewModel {

    let conversation: ConversationModel
    let userName: Observable<String>

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    let messages :Observable<[MessageViewModel]>

    private let conversationsService = AppDelegate.conversationsService
    private let accountService = AppDelegate.accountService

    init(withConversation conversation: ConversationModel) {
        self.conversation = conversation

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"

        self.userName = ContactHelper.lookupUserName(forRingId: self.conversation.recipient.ringId,
                                                nameService: AppDelegate.nameService,
                                                disposeBag: DisposeBag()).asObservable()

        //Create observable from sorted conversations and flatMap them to view models
        self.messages = self.conversationsService.conversations.asObservable().map({ conversations in
            return conversations.filter({ currentConversation in
                return currentConversation.recipient == conversation.recipient
            }).flatMap({ conversation in
                conversation.messages.map({ message in
                    return MessageViewModel(withMessage: message)
                })
            })
        }).observeOn(MainScheduler.instance)

    }

    var unreadMessages: String {
       return self.unreadMessagesCount.description
    }

    var hasUnreadMessages: Bool {
        return unreadMessagesCount > 0
    }

    var lastMessage: String {
        if let lastMessage = conversation.messages.last?.content {
            return lastMessage
        } else {
            return ""
        }
    }

    var lastMessageReceivedDate: String {

        guard let lastMessageDate = self.conversation.messages.last?.receivedDate else {
            return ""
        }

        let dateToday = Date()

        //Get components from today date
        let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
        let todayDay = Calendar.current.component(.day, from: dateToday)
        let todayMonth = Calendar.current.component(.month, from: dateToday)
        let todayYear = Calendar.current.component(.year, from: dateToday)

        //Get components from last message date
        let weekOfYear = Calendar.current.component(.weekOfYear, from: lastMessageDate)
        let day = Calendar.current.component(.day, from: lastMessageDate)
        let month = Calendar.current.component(.month, from: lastMessageDate)
        let year = Calendar.current.component(.year, from: lastMessageDate)

        if todayDay == day && todayMonth == month && todayYear == year {
            return hourFormatter.string(from: lastMessageDate)
        } else if day == todayDay - 1 {
            return NSLocalizedString("Yesterday", tableName: "Smartlist", comment: "")
        } else if todayYear == year && todayWeekOfYear == weekOfYear {
            return lastMessageDate.dayOfWeek()
        } else {
            return dateFormatter.string(from: lastMessageDate)
        }
    }

    var hideNewMessagesLabel: Bool {
        return self.unreadMessagesCount == 0
    }

    func sendMessage(withContent content: String) {
        self.conversationsService.sendMessage(withContent: content,
                                         from: accountService.currentAccount!,
                                         to: self.conversation.recipient)
    }

    func setMessagesAsRead() {
        self.conversationsService.setMessagesAsRead(forConversation: self.conversation)
    }

    fileprivate var unreadMessagesCount: Int {
        let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
        return self.conversation.messages.filter({ message in
            return message.status != .read && message.author != accountHelper.ringId!
        }).count
    }
}
