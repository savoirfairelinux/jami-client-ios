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

class ConversationViewModel {

    private let conversation: ConversationModel

    private let formatter = DateFormatter()

    init(withConversation conversation: ConversationModel) {
        self.conversation = conversation
        formatter.dateStyle = .short
    }

    var userName: String {
        return conversation.recipient
    }

    var unreadMessages: String {
        if conversation.messages.count == 0 {
            return ""
        } else if conversation.messages.count == 1 {
            return "\(conversation.unreadMessagesCount) New Message"
        } else {
            return "\(conversation.unreadMessagesCount) New Messages"
        }
    }

    var hasUnreadMessages: Bool {
        return conversation.messages.count > 0
    }

    var lastMessageReceivedDate: String {

        if let lastMessage = self.conversation.messages.last {
            return formatter.string(from: lastMessage.receivedDate)
        } else {
            return ""
        }
    }
}
