/*
 *  Copyright (C) 2017-2018 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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
import SwiftyBeaver

class ConversationsService {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    fileprivate let messageAdapter: MessagesAdapter
    fileprivate let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"

    fileprivate let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    var conversations = Variable([ConversationModel]())

    var messagesSemaphore = DispatchSemaphore(value: 1)

    var dataTransferMessageMap = [UInt64: Int64]()

    lazy var conversationsForCurrentAccount: Observable<[ConversationModel]> = {
        return self.conversations.asObservable()
    }()

    let dbManager = DBManager(profileHepler: ProfileDataHelper(), conversationHelper: ConversationDataHelper(), interactionHepler: InteractionDataHelper())

    init(withMessageAdapter adapter: MessagesAdapter) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        messageAdapter = adapter
    }

    func getConversationsForAccount(accountId: String, accountUri: String) -> Observable<[ConversationModel]> {
        /* if we don't have conversation that could mean the app
        just launched and we need symchronize messages status
        */
        var shouldUpdateMessagesStatus = true
        if self.conversations.value.first != nil {
            shouldUpdateMessagesStatus = false
        }
        dbManager.getConversationsObservable(for: accountId, accountURI: accountUri)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] conversationsModels in
                self?.conversations.value = conversationsModels
                if shouldUpdateMessagesStatus {
                    self?.updateMessagesStatus()
                }
            })
            .disposed(by: self.disposeBag)
        return self.conversations.asObservable()
    }

    func updateMessagesStatus() {
        /**
         If the app was closed prior to messages receiving a "stable"
         status, incorrect status values will remain in the database.
         Get updated message status from the daemon for each
         message as conversations are loaded from the database.
         Only sent messages having an 'unknown' or 'sending' status
         are considered for updating.
         */
        for conversation in self.conversations.value {
            for message in (conversation.messages) {
                if !message.daemonId.isEmpty && (message.status == .unknown || message.status == .sending ) {
                    let updatedMessageStatus = self.status(forMessageId: message.daemonId)
                    if (updatedMessageStatus.rawValue > message.status.rawValue && updatedMessageStatus != .failure) ||
                        (updatedMessageStatus == .failure && message.status == .sending) {
                        self.dbManager.updateMessageStatus(daemonID: message.daemonId, withStatus: updatedMessageStatus)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onCompleted: { [] in
                                print("Message status updated - load")
                            })
                            .disposed(by: self.disposeBag)
                    }
                }
            }
        }
    }

    func sendMessage(withContent content: String,
                     from senderAccount: AccountModel,
                     to recipientRingId: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let contentDict = [self.textPlainMIMEType: content]
            let messageId = String(self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientRingId))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            if let ringId = accountHelper.ringId, ringId != recipientRingId {
                let message = self.createMessage(withId: messageId,
                                                 withContent: content,
                                                 byAuthor: ringId,
                                                 generated: false,
                                                 incoming: false)
                self.saveMessage(message: message,
                                 toConversationWith: recipientRingId,
                                 toAccountId: senderAccount.id,
                                 toAccountUri: ringId,
                                 shouldRefreshConversations: true)
                    .subscribe(onCompleted: { [unowned self] in
                        self.log.debug("Message saved")
                    })
                    .disposed(by: self.disposeBag)
            }

            completable(.completed)

            return Disposables.create {}
        })
    }

    func createMessage(withId messageId: String,
                       withContent content: String,
                       byAuthor author: String,
                       generated: Bool?,
                       incoming: Bool) -> MessageModel {
        let message = MessageModel(withId: messageId, receivedDate: Date(), content: content, author: author, incoming: incoming)
        if let generated = generated {
            message.isGenerated = generated
        }
        return message
    }

    func saveMessage(message: MessageModel,
                     toConversationWith recipientRingId: String,
                     toAccountId: String,
                     toAccountUri: String,
                     shouldRefreshConversations: Bool) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            self.messagesSemaphore.wait()
            self.dbManager.saveMessage(for: toAccountUri,
                                       with: recipientRingId,
                                       message: message,
                                       incoming: message.incoming,
                                       interactionType: InteractionType.text)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] _ in
                    // append new message so it can be found if a status update is received before the DB finishes reload
                    self?.conversations.value.filter({ conversation in
                        return conversation.recipientRingId == recipientRingId &&
                            conversation.accountId == toAccountId
                    }).first?.messages.append(message)
                    self?.messagesSemaphore.signal()
                    if shouldRefreshConversations {
                        self?.dbManager.getConversationsObservable(for: toAccountId, accountURI: toAccountUri)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onNext: { [weak self] conversationsModels in
                                self?.conversations.value = conversationsModels
                            })
                            .disposed(by: (self?.disposeBag)!)
                    }
                    completable(.completed)
                    }, onError: { error in
                        self.messagesSemaphore.signal()
                        completable(.error(error))
                }).disposed(by: self.disposeBag)

            return Disposables.create { }
        })
    }

    func findConversation(withRingId ringId: String,
                          withAccountId accountId: String) -> ConversationModel? {
        return self.conversations.value
            .filter({ conversation in
                return conversation.recipientRingId == ringId && conversation.accountId == accountId
            })
            .first
    }

    func generateMessage(messageContent: String,
                         contactRingId: String,
                         accountRingId: String,
                         accountId: String,
                         date: Date,
                         interactionType: InteractionType,
                         shouldUpdateConversation: Bool) {
        let message = MessageModel(withId: "", receivedDate: date, content: messageContent, author: accountRingId, incoming: false)
        message.isGenerated = true

        self.dbManager.saveMessage(for: accountRingId, with: contactRingId, message: message, incoming: false, interactionType: interactionType)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [unowned self] _ in
                if shouldUpdateConversation {
                    self.dbManager.getConversationsObservable(for: accountId, accountURI: accountRingId)
                        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                        .subscribe(onNext: { conversationsModels in
                            self.conversations.value = conversationsModels
                        })
                        .disposed(by: (self.disposeBag))
                }
                }, onError: { _ in
            }).disposed(by: self.disposeBag)
    }

    func generateDataTransferMessage(transferId: UInt64,
                                     transferInfo: NSDataTransferInfo,
                                     accountRingId: String,
                                     accountId: String,
                                     photoIdentifier: String?) {

        let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: transferInfo.totalSize, countStyle: .file)
        var messageContent = transferInfo.displayName + "\n" + fileSizeWithUnit
        if let photoIdentifier = photoIdentifier {
           messageContent = transferInfo.displayName + "\n" + fileSizeWithUnit + "\n" + photoIdentifier
        }
        let isIncoming = transferInfo.flags == 1
        let interactionType: InteractionType = isIncoming ? .iTransfer : .oTransfer
        let date = Date()
        let contactRingId = transferInfo.peer!

        let message = MessageModel(withId: String(transferId), receivedDate: date, content: messageContent, author: accountRingId, incoming: isIncoming)
        message.transferStatus = isIncoming ? .awaiting : .created
        message.isGenerated = false
        message.isTransfer = true

        self.messagesSemaphore.wait()
        self.dbManager.saveMessage(for: accountRingId, with: contactRingId, message: message, incoming: isIncoming, interactionType: interactionType)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [unowned self] messageId in
                self.dataTransferMessageMap[transferId] = messageId
                self.dbManager.getConversationsObservable(for: accountId, accountURI: accountRingId)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe(onNext: { conversationsModels in
                        self.conversations.value = conversationsModels
                        self.messagesSemaphore.signal()
                        let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
                        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                        serviceEvent.addEventInput(.transferId, value: transferId)
                        self.responseStream.onNext(serviceEvent)
                    })
                    .disposed(by: (self.disposeBag))
                }, onError: { [unowned self] _ in
                    self.messagesSemaphore.signal()
            })
            .disposed(by: self.disposeBag)
    }

    func status(forMessageId messageId: String) -> MessageStatus {
        return self.messageAdapter.status(forMessageId: UInt64(messageId)!)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel, accountId: String, accountURI: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in

            //Filter out read, outgoing, and transfer messages
            let unreadMessages = conversation.messages.filter({ messages in
                return messages.status != .read && messages.incoming && !messages.isTransfer
            })

            let messagesIds = unreadMessages.map({$0.messageId}).filter({$0 >= 0})
            self.dbManager
                .setMessagesAsRead(messagesIDs: messagesIds, withStatus: .read)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: { [weak self] in
                        self?.dbManager.getConversationsObservable(for: accountId, accountURI: accountURI)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onNext: { [weak self] conversationsModels in
                                self?.conversations.value = conversationsModels
                            })
                            .disposed(by: (self?.disposeBag)!)
                    completable(.completed)
                }, onError: { error in
                    completable(.error(error))
                }).disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func getProfile(uri: String) -> Observable<Profile> {
       return self.dbManager.profileObservable(for: uri, createIfNotExists: false)
    }

    func deleteConversation(conversation: ConversationModel, keepContactInteraction: Bool) {
        self.dbManager.removeConversationBetween(accountUri: conversation.accountUri, and: conversation.recipientRingId, keepAddContactEvent: keepContactInteraction)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: { [weak self] in
                self?.removeSavedFiles(accountId: conversation.accountId, conversationId: conversation.conversationId)
                self?.dbManager
                    .getConversationsObservable(for: conversation.accountId,
                                                accountURI: conversation.accountUri)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe(onNext: { [weak self] conversationsModels in
                        self?.conversations.value = conversationsModels
                    })
                    .disposed(by: (self?.disposeBag)!)
                }, onError: { error in
                    self.log.error(error)
            }).disposed(by: self.disposeBag)
    }

    func removeSavedFiles(accountId: String, conversationId: String) {
        let downloadsFolderName = "downloads"
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let directoryURL = documentsURL.appendingPathComponent(downloadsFolderName)
            .appendingPathComponent(accountId).appendingPathComponent(conversationId)
        try? FileManager.default.removeItem(atPath: directoryURL.path)
    }

    func messageStatusChanged(_ status: MessageStatus,
                              for messageId: UInt64,
                              fromAccount account: AccountModel,
                              to uri: String) {
        self.messagesSemaphore.wait()
        //Get conversations for this sender
        let conversation = self.conversations.value.filter({ conversation in
            return  conversation.recipientRingId == uri &&
                    conversation.accountId == account.id
        }).first

        //Find message
        if let messages: [MessageModel] = conversation?.messages.filter({ (message) -> Bool in
            return  !message.daemonId.isEmpty && message.daemonId == String(messageId) &&
                    ((status.rawValue > message.status.rawValue && status != .failure) ||
                    (status == .failure && message.status == .sending))
        }) {
            if let message = messages.first {
                self.dbManager
                    .updateMessageStatus(daemonID: message.daemonId, withStatus: status)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe(onCompleted: { [unowned self] in
                        self.messagesSemaphore.signal()
                        self.log.info("messageStatusChanged: Message status updated")
                        var event = ServiceEvent(withEventType: .messageStateChanged)
                        event.addEventInput(.messageStatus, value: status)
                        event.addEventInput(.messageId, value: String(messageId))
                        event.addEventInput(.id, value: account.id)
                        event.addEventInput(.uri, value: uri)
                        self.responseStream.onNext(event)
                    }, onError: { _ in
                        self.messagesSemaphore.signal()
                    })
                    .disposed(by: self.disposeBag)
            } else {
                self.log.warning("messageStatusChanged: Message not found")
                self.messagesSemaphore.signal()
            }
        } else {
            self.messagesSemaphore.signal()
        }

        log.debug("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(account.id) to: \(uri)")
    }

    func transferStatusChanged(_ transferStatus: DataTransferStatus,
                               for transferId: UInt64,
                               fromAccount account: AccountModel,
                               to uri: String) {
        self.messagesSemaphore.wait()
        //Get conversations for this sender
        let conversation = self.conversations.value.filter({ conversation in
            return  conversation.recipientRingId == uri &&
                conversation.accountId == account.id
        }).first

        //Find message
        if let messages: [MessageModel] = conversation?.messages.filter({ (message) -> Bool in
            return  message.daemonId == String(transferId)
        }) {
            if let message = messages.first {
                self.dbManager
                    .updateTransferStatus(daemonID: message.daemonId, withStatus: transferStatus)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe(onCompleted: { [unowned self] in
                        self.messagesSemaphore.signal()
                        self.log.info("ConversationService: transferStatusChanged - transfer status updated")
                        let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
                        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                        serviceEvent.addEventInput(.transferId, value: transferId)
                        self.responseStream.onNext(serviceEvent)
                    }, onError: { _ in
                        self.messagesSemaphore.signal()
                    })
                    .disposed(by: self.disposeBag)
            } else {
                self.log.error("ConversationService: transferStatusChanged - transfer not found")
                self.messagesSemaphore.signal()
            }
        } else {
            self.messagesSemaphore.signal()
        }

        log.debug("ConversationService: transferStatusChanged - \(transferStatus.description) for id: \(transferId) from: \(account.id) to: \(uri)")
    }
}
