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

    //Displays the entire date ( for messages received before the current week )
    private let dateFormatter = DateFormatter()

    //Displays the hour of the message reception ( for messages received today )
    private let hourFormatter = DateFormatter()

    private var recipientViewModel: ContactViewModel?

    init(withConversation conversation: ConversationModel) {
        self.conversation = conversation
        dateFormatter.dateStyle = .medium
        hourFormatter.dateFormat = "HH:mm"
    }

    var userName: Observable<String> {
        if recipientViewModel == nil {
            recipientViewModel = ContactViewModel(withContact: self.conversation.recipient)
        }
        return recipientViewModel!.userName.asObservable()
    }

    var unreadMessages: String {
        if conversation.messages.count == 0 {
            return ""
        } else if conversation.messages.count == 1 {
            let text = NSLocalizedString("NewMessage", tableName: "Smartlist", comment: "")
            return "\(self.unreadMessagesCount) \(text)"
        } else {
            let text = NSLocalizedString("NewMessages", tableName: "Smartlist", comment: "")
            return "\(self.unreadMessagesCount) \(text)"
        }
    }

    var unreadMessagesCount: Int {
        return self.conversation.messages.filter({ message in
            return message.status != .read
        }).count
    }

    var hasUnreadMessages: Bool {
        return conversation.messages.count > 0
    }

    var lastMessageReceivedDate: String {

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
}
