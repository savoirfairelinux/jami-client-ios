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
    let messages :Observable<[MessageViewModel]>

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    private var recipientViewModel: ContactViewModel?

    //Services
    private let messagesService = AppDelegate.messagesService
    private let accountService = AppDelegate.accountService

    init(withConversation conversation: ConversationModel) {
        self.conversation = conversation

        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"

        //Create observable from sorted conversations and flatMap them to view models
        self.messages = self.messagesService.conversations.asObservable().map({ conversations in
            return conversations.filter({ currentConversation in
                return currentConversation.recipient == conversation.recipient
            }).flatMap({ conversation in
                conversation.messages.map({ message in
                    return MessageViewModel(withMessage: message)
                })
            })
        }).observeOn(MainScheduler.instance)
    }

    var userName: Observable<String> {
        if recipientViewModel == nil {
            recipientViewModel = ContactViewModel(withContact: self.conversation.recipient)
        }
        return recipientViewModel!.userName.asObservable().observeOn(MainScheduler.instance)
    }

    var unreadMessages: String {
        if unreadMessagesCount == 0 {
            return ""
        } else if unreadMessagesCount == 1 {
            let text = NSLocalizedString("NewMessage", tableName: "Smartlist", comment: "")
            return "\(self.unreadMessagesCount) \(text)"
        } else {
            let text = NSLocalizedString("NewMessages", tableName: "Smartlist", comment: "")
            return "\(self.unreadMessagesCount) \(text)"
        }
    }

    var hasUnreadMessages: Bool {
        return unreadMessagesCount > 0
    }

    var lastMessageReceivedDate: String {

        if self.conversation.messages.count == 0 {
            return ""
        }

        let dateToday = Date()

        //Get components from today date
        let todayWeekOfYear = Calendar.current.component(.weekOfYear, from: dateToday)
        let todayDay = Calendar.current.component(.day, from: dateToday)
        let todayMonth = Calendar.current.component(.month, from: dateToday)
        let todayYear = Calendar.current.component(.year, from: dateToday)

        //Get components from last message date
        let weekOfYear = Calendar.current.component(.weekOfYear, from: self.conversation.lastMessageDate)
        let day = Calendar.current.component(.day, from: self.conversation.lastMessageDate)
        let month = Calendar.current.component(.month, from: self.conversation.lastMessageDate)
        let year = Calendar.current.component(.year, from: self.conversation.lastMessageDate)

        if todayDay == day && todayMonth == month && todayYear == year {
            return hourFormatter.string(from: self.conversation.lastMessageDate)
        } else if day == todayDay - 1 {
            return NSLocalizedString("Yesterday", tableName: "Smartlist", comment: "")
        } else if todayYear == year && todayWeekOfYear == weekOfYear {
            return self.conversation.lastMessageDate.dayOfWeek()
        } else {
            return dateFormatter.string(from: self.conversation.lastMessageDate)
        }
    }

    var hideNewMessagesLabel: Bool {
        return self.unreadMessagesCount == 0
    }

    var hideDate: Bool {
        return self.conversation.messages.count == 0
    }

    func sendMessage(withContent content: String) {
        self.messagesService.sendMessage(withContent: content,
                                         from: accountService.currentAccount!,
                                         to: self.conversation.recipient)
    }

    func setMessagesAsRead() {
        self.messagesService.setMessagesAsRead(forConversation: self.conversation)
    }

    fileprivate var unreadMessagesCount: Int {
        let accountHelper = AccountModelHelper(withAccount: self.accountService.currentAccount!)
        return self.conversation.messages.filter({ message in
            return message.status != .read && message.author != accountHelper.ringId!
        }).count
    }
}
