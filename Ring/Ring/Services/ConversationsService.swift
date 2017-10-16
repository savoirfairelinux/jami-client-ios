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

import RxSwift
import RealmSwift
import SwiftyBeaver

class ConversationsService: MessagesAdapterDelegate {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    fileprivate let messageAdapter: MessagesAdapter
    fileprivate let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"

    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    private var realm: Realm!

    fileprivate let results: Results<ConversationModel>

    var conversations: Observable<Results<ConversationModel>>

    init(withMessageAdapter adapter: MessagesAdapter) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()

        guard let realm = try? Realm() else {
            fatalError("Enable to instantiate Realm")
        }

        messageAdapter = adapter
        self.realm = realm
        results = realm.objects(ConversationModel.self)

        conversations = Observable.collection(from: results, synchronousStart: true)
        MessagesAdapter.delegate = self

    }

    func sendMessage(withContent content: String,
                     from senderAccount: AccountModel,
                     to recipientRingId: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let contentDict = [self.textPlainMIMEType: content]
            let messageId = String(self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientRingId))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            if accountHelper.ringId! != recipientRingId {
                _ = self.saveMessage(withId: messageId,
                                     withContent: content,
                                     byAuthor: accountHelper.ringId!,
                                     toConversationWith: recipientRingId,
                                     currentAccountId: senderAccount.id,
                                     generated: false)
                    .subscribe(onCompleted: { [unowned self] in
                        self.log.debug("Message saved")
                    })
                    .disposed(by: self.disposeBag)
            }

            completable(.completed)

            return Disposables.create {}
        })
    }

    func addConversation(conversation: ConversationModel) -> Completable {
        return Completable.create(subscribe: { [unowned self] completable in
            do {
                try self.realm.write { [unowned self] in
                    self.realm.add(conversation)
                }
                completable(.completed)
            } catch let error {
                completable(.error(error))
            }

            return Disposables.create { }
        })
    }

    func saveMessage(withId messageId: String,
                     withContent content: String,
                     byAuthor author: String,
                     toConversationWith recipientRingId: String,
                     currentAccountId: String,
                     generated: Bool?) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let message = MessageModel(withId: messageId, receivedDate: Date(), content: content, author: author)
            if let generated = generated {
                message.isGenerated = generated
            }

            //Get conversations for this sender
            var currentConversation = self.results.filter({ conversation in
                return conversation.recipientRingId == recipientRingId
            }).first

            //Create a new conversation for this sender if not exists
            if currentConversation == nil {
                currentConversation = ConversationModel(withRecipientRingId: recipientRingId, accountId: currentAccountId)

                do {
                    try self.realm.write { [unowned self] in
                        self.realm.add(currentConversation!)
                    }
                } catch let error {
                    completable(.error(error))
                }
            }

            //Add the received message into the conversation
            do {
                try self.realm.write {
                    currentConversation?.messages.append(message)
                }
                completable(.completed)
            } catch let error {
                completable(.error(error))
            }

            return Disposables.create { }

        })
    }

    func status(forMessageId messageId: String) -> MessageStatus {
        return self.messageAdapter.status(forMessageId: UInt64(messageId)!)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in

            //Filter unread messages
            let unreadMessages = conversation.messages.filter({ messages in
                return messages.status != .read
            })

            do {
                try self.realm.write {
                    for message in unreadMessages {
                        message.status = .read
                    }
                }
                completable(.completed)

            } catch let error {
                completable(.error(error))
            }

            return Disposables.create { }

        })
    }

    func setMessageStatus(withMessageId id: String,
                          withRingId ringId: String,
                          withAccountId accountId: String,
                          withStatus status: MessageStatus) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in

            //Get conversations for this sender
            let conversation = self.results.filter({ conversation in
                return conversation.recipientRingId == ringId &&
                    conversation.accountId == accountId
            }).first

            //Find message
            if let messages = conversation?.messages.filter({ messages in
                return messages.id == id
            }) {
                do {
                    try self.realm.write {
                        for message in messages {
                            message.status = status
                        }
                    }
                    completable(.completed)

                } catch let error {
                    completable(.error(error))
                }
            }

            return Disposables.create { }
        })
    }

    func deleteConversation(conversation: ConversationModel) {

        do {
            try realm.write {

                //Remove all messages from the conversation
                for message in conversation.messages {
                    realm.delete(message)
                }

                realm.delete(conversation)
            }
        } catch let error {
            self.log.error("\(error)")
        }
    }

    // MARK: Message Adapter delegate

    func didReceiveMessage(_ message: [String: String],
                           from senderAccount: String,
                           to receiverAccountId: String) {

        if let content = message[textPlainMIMEType] {
            self.saveMessage(withId: "",
                             withContent: content,
                             byAuthor: senderAccount,
                             toConversationWith: senderAccount,
                             currentAccountId: receiverAccountId,
                             generated: false)
                .subscribe(onCompleted: { [unowned self] in
                    self.log.info("Message saved")
                })
                .disposed(by: disposeBag)
        }
    }

    func messageStatusChanged(_ status: MessageStatus,
                              for messageId: UInt64,
                              from accountId: String,
                              to uri: String) {

        var event = ServiceEvent(withEventType: .messageStateChanged)
        event.addEventInput(.messageStatus, value: status)
        event.addEventInput(.messageId, value: String(messageId))
        event.addEventInput(.id, value: accountId)
        event.addEventInput(.uri, value: uri)
        self.responseStream.onNext(event)

        self.setMessageStatus(withMessageId: String(messageId),
                              withRingId: uri,
                              withAccountId: accountId,
                              withStatus: status)
            .subscribe(onCompleted: { [unowned self] in
                self.log.info("Message status updated")
            })
            .disposed(by: disposeBag)

        log.debug("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(accountId) to: \(uri)")
    }
}
