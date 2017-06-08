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

import RealmSwift
import RxSwift
import RxRealm

class MessagesService: MessagesAdapterDelegate {

    fileprivate let messageAdapter :MessagesAdapter
    fileprivate let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"
    fileprivate let realm :Realm = try! Realm()

    let conversations :Observable<Results<ConversationModel>>

    init(withMessageAdapter messageAdapter: MessagesAdapter) {
        self.messageAdapter = messageAdapter
        self.conversations = Observable.collection(from: realm.objects(ConversationModel.self))
        MessagesAdapter.delegate = self
    }

    func sendMessage(withContent content: String, from senderAccount: AccountModel, to recipient: ContactModel) {

        let contentDict = [textPlainMIMEType : content]
        self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipient.ringId)

        let accountHelper = AccountModelHelper(withAccount: senderAccount)

        if accountHelper.ringId! != recipient.ringId {
            self.addMessage(withContent: content, byAuthor: accountHelper.ringId!, toConversationWith: recipient.ringId)
        }
    }

    func addConversation(conversation: ConversationModel) {
        try! realm.write {
            realm.add(conversation)
        }
    }

    func status(forMessageId messageId: UInt64) -> MessageStatus {
        return self.messageAdapter.status(forMessageId: messageId)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel) {

        try! realm.write {
            for message in conversation.messages.filter({ message in
                return message.status != .read
            }) {
                message.status = .read
            }
        }
    }

    fileprivate func addMessage(withContent content: String, byAuthor author: String, toConversationWith account: String) {

        let message = MessageModel(withId: 0, receivedDate: Date(), content: content, author: author)

        if author != account {
            message.status = .read
        }

        let results = realm.objects(ConversationModel.self)

        //Get conversations for this sender
        var currentConversation = results.filter({ conversation in
            return conversation.recipient?.ringId == account
        }).first

        //Create a new conversation for this sender if not exists
        if currentConversation == nil {
            currentConversation = ConversationModel(withRecipient: ContactModel(withRingId: account))

            try! realm.write {
                realm.add(currentConversation!)
            }
        }

        try! realm.write {
            //Add the received message into the conversation
            currentConversation?.messages.append(message)
            currentConversation?.lastMessageDate = message.receivedDate
        }
    }

    //MARK: Message Adapter delegate

    func didReceiveMessage(_ message: Dictionary<String, String>, from senderAccount: String,
                           to receiverAccountId: String) {

        if let content = message[textPlainMIMEType] {
            self.addMessage(withContent: content, byAuthor: senderAccount, toConversationWith: senderAccount)
        }
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64,
                              from senderAccountId: String, to receiverAccount: String) {

        print("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(senderAccountId) to: \(receiverAccount)")
    }
}
