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

class ConversationModel {

    var messages = [MessageModel]()
    var recipient: ContactModel
    var lastMessageDate: Date?

    init(withRecipient recipient: ContactModel) {
        self.recipient = recipient
    }

    lazy var viewModel: ConversationViewModel = {
        return ConversationViewModel(withConversation: self)
    }()

    func add(message: MessageModel) {
        self.messages.append(message)

        self.viewModel.messages.value = self.messages.map({ message in
            return message.viewModel
        })

        self.lastMessageDate = message.receivedDate
    }
}

extension ConversationModel {

    var unreadMessagesCount: Int {
        return self.messages.filter({ message in
            return message.status != .read
        }).count
    }
}
