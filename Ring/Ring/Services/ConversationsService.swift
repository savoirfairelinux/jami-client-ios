/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

// swiftlint:disable type_body_length
class ConversationsService {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    private let messageAdapter: MessagesAdapter
    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    var conversations = Variable([ConversationModel]())

    var messagesSemaphore = DispatchSemaphore(value: 1)

    typealias SavedMessageForConversation = (messageID: Int64, conversationID: Int64)

    var dataTransferMessageMap = [UInt64: SavedMessageForConversation]()

    lazy var conversationsForCurrentAccount: Observable<[ConversationModel]> = {
        return self.conversations.asObservable()
    }()

    let dbManager: DBManager

    init(withMessageAdapter adapter: MessagesAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        messageAdapter = adapter
        self.dbManager = dbManager
    }

    func getConversationsForAccount(accountId: String) -> Observable<[ConversationModel]> {
        /* if we don't have conversation that could mean the app
        just launched and we need symchronize messages status
        */
        var shouldUpdateMessagesStatus = true
        if self.conversations.value.first != nil {
            shouldUpdateMessagesStatus = false
        }
        dbManager.getConversationsObservable(for: accountId)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] conversationsModels in
                self?.conversations.value = conversationsModels
                if shouldUpdateMessagesStatus {
                    self?.updateMessagesStatus(accountId: accountId)
                }
            })
            .disposed(by: self.disposeBag)
        return self.conversations.asObservable()
    }

    func updateMessagesStatus(accountId: String) {
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
                        self.dbManager.updateMessageStatus(daemonID: message.daemonId,
                                                           withStatus: updatedMessageStatus,
                                                           accountId: accountId)
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
                     recipientUri: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let contentDict = [self.textPlainMIMEType: content]
            let messageId = String(self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientUri))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
            let contactUri = JamiURI.init(schema: type, infoHach: recipientUri, account: senderAccount)
            guard let stringUri = contactUri.uriString else {
                completable(.completed)
                return Disposables.create {}
            }
            if let uri = accountHelper.uri, uri != recipientUri {
                let message = self.createMessage(withId: messageId,
                                                 withContent: content,
                                                 byAuthor: uri,
                                                 generated: false,
                                                 incoming: false)
                self.saveMessage(message: message,
                                 toConversationWith: stringUri,
                                 toAccountId: senderAccount.id,
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
        let message = MessageModel(withId: messageId, receivedDate: Date(), content: content, authorURI: author, incoming: incoming)
        if let generated = generated {
            message.isGenerated = generated
        }
        return message
    }

    func saveMessage(message: MessageModel,
                     toConversationWith recipientRingId: String,
                     toAccountId: String,
                     shouldRefreshConversations: Bool) -> Completable {
        return self.saveMessageModel(message: message, toConversationWith: recipientRingId,
                                     toAccountId: toAccountId, shouldRefreshConversations: shouldRefreshConversations,
                                     interactionType: InteractionType.text)
    }

    func saveMessageModel(message: MessageModel,
                          toConversationWith recipientRingId: String,
                          toAccountId: String,
                          shouldRefreshConversations: Bool,
                          interactionType: InteractionType = InteractionType.text) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            self.messagesSemaphore.wait()
            self.dbManager.saveMessage(for: toAccountId,
                                       with: recipientRingId,
                                       message: message,
                                       incoming: message.incoming,
                                       interactionType: interactionType, duration: 0)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [unowned self] _ in
                    // append new message so it can be found if a status update is received before the DB finishes reload
                    self.conversations.value.filter({ conversation in
                        return conversation.participantUri == recipientRingId &&
                            conversation.accountId == toAccountId
                    }).first?.messages.append(message)
                    self.messagesSemaphore.signal()
                    if shouldRefreshConversations {
                        self.dbManager.getConversationsObservable(for: toAccountId)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onNext: { [unowned self] conversationsModels in
                                self.conversations.value = conversationsModels
                            })
                            .disposed(by: (self.disposeBag))
                    }
                    completable(.completed)
                    }, onError: { error in
                        self.messagesSemaphore.signal()
                        completable(.error(error))
                }).disposed(by: self.disposeBag)

            return Disposables.create { }
        })
    }

    func findConversation(withUri uri: String,
                          withAccountId accountId: String) -> ConversationModel? {
        return self.conversations.value
            .filter({ conversation in
                return conversation.participantUri == uri && conversation.accountId == accountId
            })
            .first
    }

    // swiftlint:disable:next function_parameter_count
    func generateMessage(messageContent: String,
                         contactUri: String,
                         accountId: String,
                         date: Date,
                         interactionType: InteractionType,
                         shouldUpdateConversation: Bool) {
        self.generateMessage(messageContent: messageContent,
                             duration: 0, contactUri: contactUri,
                             accountId: accountId,
                             date: date, interactionType: interactionType,
                             shouldUpdateConversation: shouldUpdateConversation)
    }

    // swiftlint:disable:next function_parameter_count
    func generateMessage(messageContent: String,
                         duration: Int64,
                         contactUri: String,
                         accountId: String,
                         date: Date,
                         interactionType: InteractionType,
                         shouldUpdateConversation: Bool) {
        let message = MessageModel(withId: "", receivedDate: date, content: messageContent, authorURI: "", incoming: false)
        message.isGenerated = true

        self.dbManager.saveMessage(for: accountId, with: contactUri, message: message, incoming: false, interactionType: interactionType, duration: Int(duration))
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [unowned self] _ in
                if shouldUpdateConversation {
                    self.dbManager.getConversationsObservable(for: accountId)
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
                                     accountId: String,
                                     photoIdentifier: String?,
                                     updateConversation: Bool) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in

            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: transferInfo.totalSize, countStyle: .file)
            var messageContent = transferInfo.displayName + "\n" + fileSizeWithUnit
            if let photoIdentifier = photoIdentifier {
                messageContent = transferInfo.displayName + "\n" + fileSizeWithUnit + "\n" + photoIdentifier
            }
            let isIncoming = transferInfo.flags == 1
            let interactionType: InteractionType = isIncoming ? .iTransfer : .oTransfer
            guard let contactUri = JamiURI.init(schema: URIType.ring,
                                                infoHach: transferInfo.peer).uriString else {
                                                    completable(.completed)
                                                    return Disposables.create { }
            }
            let author = isIncoming ? contactUri : ""
            let date = Date()
            let message = MessageModel(withId: String(transferId),
                                       receivedDate: date, content: messageContent,
                                       authorURI: author, incoming: isIncoming)
            message.transferStatus = isIncoming ? .awaiting : .created
            message.isGenerated = false
            message.isTransfer = true

            self.messagesSemaphore.wait()
            self.dbManager.saveMessage(for: accountId, with: contactUri,
                                       message: message, incoming: isIncoming,
                                       interactionType: interactionType, duration: 0)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [unowned self] message in
                    self.dataTransferMessageMap[transferId] = message
                    self.dbManager.getConversationsObservable(for: accountId)
                        .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                        .subscribe(onNext: { conversationsModels in
                            if updateConversation {
                                self.conversations.value = conversationsModels
                            }
                            let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
                            var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                            serviceEvent.addEventInput(.transferId, value: transferId)
                            self.responseStream.onNext(serviceEvent)

                            self.messagesSemaphore.signal()
                            completable(.completed)
                        })
                        .disposed(by: (self.disposeBag))
                    }, onError: { [unowned self] error in
                        self.messagesSemaphore.signal()
                        completable(.error(error))
                })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func status(forMessageId messageId: String) -> MessageStatus {
        guard let status = UInt64(messageId) else { return .unknown }
        return self.messageAdapter.status(forMessageId: status)
    }

    func setMessageAsRead(daemonId: String, messageID: Int64,
                          from: String, accountId: String, accountURI: String) {
        self.messageAdapter
            .setMessageDisplayedFrom(from,
                                     byAccount: accountId,
                                     messageId: daemonId,
                                     status: .displayed)
        self.dbManager
            .setMessagesAsRead(messagesIDs: [messageID],
                               withStatus: .displayed,
                               accountId: accountId)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel, accountId: String, accountURI: String) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in

            //Filter out read, outgoing, and transfer messages
            let unreadMessages = conversation.messages.filter({ messages in
                return messages.status != .displayed && messages.incoming && !messages.isTransfer
            })

            let messagesIds = unreadMessages.map({ $0.messageId }).filter({ $0 >= 0 })
            let messagesDaemonIds = unreadMessages.map({ $0.daemonId }).filter({ !$0.isEmpty })
            messagesDaemonIds.forEach { (msgId) in
                self.messageAdapter
                    .setMessageDisplayedFrom(conversation.hash,
                                             byAccount: accountId,
                                             messageId: msgId,
                                             status: .displayed)
            }
            self.dbManager
                .setMessagesAsRead(messagesIDs: messagesIds,
                                   withStatus: .displayed,
                                   accountId: accountId)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: { [unowned self] in
                        self.dbManager.getConversationsObservable(for: accountId)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onNext: { [unowned self] conversationsModels in
                                self.conversations.value = conversationsModels
                            })
                            .disposed(by: (self.disposeBag))
                    completable(.completed)
                }, onError: { error in
                    completable(.error(error))
                }).disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func deleteMessage(messagesId: Int64, accountId: String) -> Completable {
        return Completable.create(subscribe: { [unowned self] completable in
            self.dbManager
                .deleteMessage(messagesId: messagesId, accountId: accountId)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: { completable(.completed) }, onError: { error in completable(.error(error)) })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func getProfile(uri: String, accountId: String) -> Observable<Profile> {
        return self.dbManager.profileObservable(for: uri, createIfNotExists: false, accountId: accountId)
    }

    func clearHistory(conversation: ConversationModel, keepConversation: Bool) {
        self.dbManager.clearHistoryFor(accountId: conversation.accountId, and: conversation.participantUri, keepConversation: keepConversation)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: { [unowned self] in
                self.removeSavedFiles(accountId: conversation.accountId, conversationId: conversation.conversationId)
                self.dbManager
                    .getConversationsObservable(for: conversation.accountId)
                    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe(onNext: { [unowned self] conversationsModels in
                        self.conversations.value = conversationsModels
                    })
                    .disposed(by: (self.disposeBag))
                }, onError: { error in
                    self.log.error(error)
            }).disposed(by: self.disposeBag)
    }

    func removeSavedFiles(accountId: String, conversationId: String) {
        let downloadsFolderName = Directories.downloads.rawValue
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let downloadsURL = documentsURL.appendingPathComponent(downloadsFolderName)
            .appendingPathComponent(accountId).appendingPathComponent(conversationId)
        try? FileManager.default.removeItem(atPath: downloadsURL.path)
        let recordedFolderName = Directories.recorded.rawValue
        let recordedURL = documentsURL.appendingPathComponent(recordedFolderName)
            .appendingPathComponent(accountId).appendingPathComponent(conversationId)
        try? FileManager.default.removeItem(atPath: recordedURL.path)
    }

    func messageStatusChanged(_ status: MessageStatus,
                              for messageId: UInt64,
                              fromAccount account: AccountModel,
                              to uri: String) {
        self.messagesSemaphore.wait()
        //Get conversations for this sender
        let conversation = self.conversations.value.filter({ conversation in
            return  conversation.participantUri == uri &&
                    conversation.accountId == account.id
        }).first

        //Find message
        if let messages: [MessageModel] = conversation?.messages.filter({ (message) -> Bool in
            return  !message.daemonId.isEmpty && message.daemonId == String(messageId) &&
                    ((status.rawValue > message.status.rawValue && status != .failure) ||
                    (status == .failure && message.status == .sending))
        }) {
            if let message = messages.first {
                let displayedMessage = status == .displayed && !message.incoming
                let oldDisplayedMessage = conversation?.lastDisplayedMessage.id
                let isLater = (conversation?.lastDisplayedMessage.id ?? 0) < Int64(0) || conversation?.lastDisplayedMessage.timestamp ?? Date() < message.receivedDate
                if  displayedMessage && isLater {
                    conversation?.lastDisplayedMessage = (message.messageId, message.receivedDate)
                    var event = ServiceEvent(withEventType: .lastDisplayedMessageUpdated)
                    event.addEventInput(.oldDisplayedMessage, value: oldDisplayedMessage)
                    event.addEventInput(.newDisplayedMessage, value: message.messageId)
                    self.responseStream.onNext(event)
                }
                self.dbManager
                    .updateMessageStatus(daemonID: message.daemonId,
                                         withStatus: status,
                                         accountId: account.id)
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
                               accountId: String,
                               to uri: String) {
        self.messagesSemaphore.wait()
        self.dbManager
            .updateTransferStatus(daemonID: String(transferId),
                                  withStatus: transferStatus,
                                  accountId: accountId)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: { [unowned self] in
                self.messagesSemaphore.signal()
                self.log.info("ConversationService: transferStatusChanged - transfer status updated")
                let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
                var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                serviceEvent.addEventInput(.transferId, value: transferId)
                serviceEvent.addEventInput(.state, value: transferStatus)
                self.responseStream.onNext(serviceEvent)
                }, onError: { _ in
                    self.messagesSemaphore.signal()
            })
            .disposed(by: self.disposeBag)
    }

    func setIsComposingMsg(to peer: String, from account: String, isComposing: Bool) {
        messageAdapter.setComposingMessageTo(peer, fromAccount: account, isComposing: isComposing)
    }

    func detectingMessageTyping(_ from: String, for accountId: String, status: Int) {
        let serviceEventType: ServiceEventType = .messageTypingIndicator
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.peerUri, value: from)
        serviceEvent.addEventInput(.accountId, value: accountId)
        serviceEvent.addEventInput(.state, value: status)
        self.responseStream.onNext(serviceEvent)
    }
}

// MARK: Location
extension ConversationsService {

    func createLocation(withId messageId: String, byAuthor author: String, incoming: Bool) -> MessageModel {
        return MessageModel(withId: messageId, receivedDate: Date(), content: L10n.GeneratedMessage.liveLocationSharing, authorURI: author, incoming: incoming)
    }

    // TODO: Possible extraction with sendMessage
    func sendLocation(withContent content: String, from senderAccount: AccountModel,
                      recipientUri: String, shouldRefreshConversations: Bool,
                      shouldTryToSave: Bool) -> Completable {

        return Completable.create(subscribe: { [unowned self] completable in
            let contentDict = [self.geoLocationMIMEType: content]
            let messageId = String(self.messageAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientUri))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
            let contactUri = JamiURI.init(schema: type, infoHach: recipientUri, account: senderAccount)
            guard let stringUri = contactUri.uriString else {
                completable(.completed)
                return Disposables.create {}
            }
            if shouldTryToSave, let uri = accountHelper.uri, uri != recipientUri {
                let message = self.createLocation(withId: messageId,
                                                  byAuthor: uri,
                                                  incoming: false)
                self.saveLocation(message: message,
                                  toConversationWith: stringUri,
                                  toAccountId: senderAccount.id,
                                  shouldRefreshConversations: shouldRefreshConversations,
                                  contactUri: recipientUri)
                    .subscribe(onCompleted: { [unowned self] in
                        self.log.debug("Location saved")
                    })
                    .disposed(by: self.disposeBag)
            }
            completable(.completed)
            return Disposables.create {}
        })
    }

    // Save location only if it's the first one
    func isBeginningOfLocationSharing(incoming: Bool, contactUri: String, accountId: String) -> Bool {
        let isFirstLocationIncomingUpdate = self.dbManager.isFirstLocationIncomingUpdate(incoming: incoming, peerUri: contactUri, accountId: accountId)
        return isFirstLocationIncomingUpdate != nil && isFirstLocationIncomingUpdate!
    }

    // Location saved doesn't actually contain the geolocation data
    func saveLocation(message: MessageModel,
                      toConversationWith recipientRingId: String,
                      toAccountId: String,
                      shouldRefreshConversations: Bool,
                      contactUri: String) -> Completable {
        if self.isBeginningOfLocationSharing(incoming: message.incoming, contactUri: contactUri, accountId: toAccountId) {
            return self.saveMessageModel(message: message, toConversationWith: recipientRingId,
                                         toAccountId: toAccountId, shouldRefreshConversations: shouldRefreshConversations,
                                         interactionType: InteractionType.location)
        }
        return Completable.create(subscribe: { completable in
            completable(.completed)
            return Disposables.create { }
        })
    }

    func deleteLocationUpdate(incoming: Bool, peerUri: String, accountId: String, shouldRefreshConversations: Bool) -> Completable {
        return Completable.create(subscribe: { [unowned self] completable in
            self.dbManager.deleteLocationUpdates(incoming: incoming, peerUri: peerUri, accountId: accountId)
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: {
                    if shouldRefreshConversations {
                        self.dbManager.getConversationsObservable(for: accountId)
                            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onNext: { [unowned self] conversationsModels in
                                self.conversations.value = conversationsModels
                            })
                            .disposed(by: (self.disposeBag))
                    }
                    completable(.completed)
                }, onError: { (error) in
                    completable(.error(error))
                })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }
}
