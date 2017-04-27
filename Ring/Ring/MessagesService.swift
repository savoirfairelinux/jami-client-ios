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

class MessagesService: MessagesAdapterDelegate {

    let textPlainMIMEType = "text/plain"

    fileprivate let messageAdapter :MessagesAdapter

    fileprivate let disposeBag = DisposeBag()

    let conversationsStream = PublishSubject<[ConversationModel]>()

    fileprivate var conversations = [ConversationModel]()

    init(withMessageAdapter messageAdapter: MessagesAdapter) {
        self.messageAdapter = messageAdapter
        MessagesAdapter.delegate = self
    }

    func sendMessage(withContent content: String, from senderAccount: AccountModel, to receiverAccount: String) {
        let content = [textPlainMIMEType : content]
        self.messageAdapter.sendMessage(withContent: content, withAccountId: senderAccount.id, to: receiverAccount)
    }

    func status(forMessageId messageId: UInt64) -> MessageStatus {
        return self.messageAdapter.status(forMessageId: messageId)
    }

    //MARK: Message Adapter delegate

    func didReceiveMessage(_ message: Dictionary<String, String>, from senderAccount: String,
                           to receiverAccountId: String) {

        if let content = message[textPlainMIMEType] {
            let message = MessageModel(withId: nil, receivedDate: Date(), content: content, author: senderAccount)

            //Get conversations for this sender
            var currentConversation = conversations.filter({ conversation in
                return conversation.recipient == senderAccount
            }).first

            //Create a new conversation for this sender if not exists
            if currentConversation == nil {
                currentConversation = ConversationModel(withRecipient: receiverAccountId)
                currentConversation?.recipient = senderAccount
                self.conversations.append(currentConversation!)
            }

            currentConversation?.add(message: message)

            self.conversationsStream.onNext(conversations)
        }
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64,
                              from senderAccountId: String, to receiverAccount: String) {

        print("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(senderAccountId) to: \(receiverAccount)")
    }
}
