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

class MessagesService: MessagesAdapterDelegate {

    fileprivate let messageAdapter :MessagesAdapter

    init(with messageAdapter: MessagesAdapter) {
        self.messageAdapter = messageAdapter
        MessagesAdapter.delegate = self
    }

    func send(message: String, from senderAccount: AccountModel, to receiverAccount: String) {
        let message = ["text/plain" : message]
        self.messageAdapter.sendMessage(message, withAccountId: senderAccount.id, to: receiverAccount)
    }

    func status(forMessage messageId: UInt64) -> MessageStatus {
        return self.messageAdapter.status(forMessage: messageId)
    }

    //MARK: Message Adapter delegate

    func didReceiveMessage(_ message: Dictionary<String, String>, from senderAccount: String,
                           to receiverAccountId: String) {

        print("didReceiveMessage: \(message) from: \(senderAccount) to: \(receiverAccountId)")
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64,
                              from senderAccountId: String, to receiverAccount: String) {

        print("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(senderAccountId) to: \(receiverAccount)")
    }
}
