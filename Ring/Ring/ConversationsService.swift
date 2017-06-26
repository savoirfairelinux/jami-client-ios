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

class ConversationsService: MessagesAdapterDelegate {

    fileprivate let messageAdapter :MessagesAdapter
    fileprivate let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"

    var conversations = Variable([ConversationModel]())

    init(withMessageAdapter messageAdapter: MessagesAdapter) {
        self.messageAdapter = messageAdapter
        MessagesAdapter.delegate = self
    }

    func sendMessage(withContent content: String,
                     from senderAccount: AccountModel,
                     to recipient: ContactModel) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let contentDict = [self.textPlainMIMEType : content]
            self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipient.ringId)

            let accountHelper = AccountModelHelper(withAccount: senderAccount)

            if accountHelper.ringId! != recipient.ringId {
                _ = self.saveMessage(withContent: content, byAuthor: accountHelper.ringId!, toConversationWith: recipient.ringId, currentAccountId: senderAccount.id)
            }

            completable(.completed)

            return Disposables.create {}
        })
    }

    func addConversation(conversation: ConversationModel) {
        self.conversations.value.append(conversation)
    }

    func saveMessage(withContent content: String,
                     byAuthor author: String,
                     toConversationWith recipientRingId: String,
                     currentAccountId: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let message = MessageModel(withId: nil, receivedDate: Date(), content: content, author: author)

            //Get conversations for this sender
            var currentConversation = self.conversations.value.filter({ conversation in
                return conversation.recipient.ringId == recipientRingId
            }).first

            //Get the current array of conversations
            var currentConversations = self.conversations.value

            //Create a new conversation for this sender if not exists
            if currentConversation == nil {
                currentConversation = ConversationModel(withRecipient: ContactModel(withRingId: recipientRingId), accountId: currentAccountId)
                currentConversations.append(currentConversation!)
            }

            //Add the received message into the conversation
            currentConversation?.messages.append(message)

            //Upate the value of the Variable
            self.conversations.value = currentConversations

            completable(.completed)

            return Disposables.create { }

        })
    }

    func status(forMessageId messageId: UInt64) -> MessageStatus {
        return self.messageAdapter.status(forMessageId: messageId)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel) -> Completable {

        return Completable.create(subscribe: { completable in

            //Get the current array of conversations
            let currentConversations = self.conversations.value

            //Filter unread messages
            let unreadMessages = conversation.messages.filter({ messages in
                return messages.status != .read
            })

            for message in unreadMessages {
                message.status = .read
            }

            //Upate the value of the Variable
            self.conversations.value = currentConversations

            completable(.completed)

            return Disposables.create { }

        })
    }

    //MARK: Message Adapter delegate

    func didReceiveMessage(_ message: Dictionary<String, String>, from senderAccount: String,
                           to receiverAccountId: String) {

        if let content = message[textPlainMIMEType] {
            self.saveMessage(withContent: content, byAuthor: senderAccount, toConversationWith: senderAccount, currentAccountId: receiverAccountId)
                .subscribe(onCompleted: {
                    print("Message saved")
                })
                .addDisposableTo(disposeBag)
        }
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64,
                              from senderAccountId: String, to receiverAccount: String) {

        print("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(senderAccountId) to: \(receiverAccount)")
    }
}
