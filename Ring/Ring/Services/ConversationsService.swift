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
import RxRelay
import SwiftyBeaver

// swiftlint:disable type_body_length
// swiftlint:disable file_length
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

    var conversations = BehaviorRelay(value: [ConversationModel]())

    var messagesSemaphore = DispatchSemaphore(value: 1)

    typealias SavedMessageForConversation = (messageID: String, conversationID: String)

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

    func getConversationIdForParticipant(participantUri: String) -> String? {
        return self.conversations.value.filter { conversation in
            conversation.getParticipants().first?.uri == participantUri
        }.first?.conversationId
    }

    func getConversationForId(conversationId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.conversationId == conversationId
        }.first
    }

    func insertMessages(conversationId: String, accountId: String, messages: [[String: String]], accountURI: String) {
        guard let conversation = self.conversations.value
                .filter({ conversation in
                    return conversation.conversationId == conversationId && conversation.accountId == accountId
                })
                .first else { return }
        var currentInteractions = conversation.messages.value
        var numberOfNewMessages = 0
        messages.forEach { messageInfo in
            // do not add interaction that already exists
            guard let messageId = messageInfo["id"] else { return }
            if currentInteractions.contains(where: { message in
                message.messageId == messageId
            }) { return }

            let newMessage = MessageModel(withInfo: messageInfo, accountURI: accountURI)
            if newMessage.type == .merge {
                return
            }
            // find parent to insert interaction after
            numberOfNewMessages += 1
            if let index = currentInteractions.firstIndex(where: { message in
                message.messageId == newMessage.parentId
            }) {
                currentInteractions.insert(newMessage, at: index + 1)
            } else {
                currentInteractions.append(newMessage)
                // save message without parent to dictionary, so if we receive parent later we could move message
                conversation.parentsId[newMessage.parentId] = newMessage.messageId
            }
            // if a new message is a parent for previously added message move it to keep ordered
            if conversation.parentsId.keys.contains(where: { parentId in
                parentId == newMessage.messageId
            }), let childId = conversation.parentsId[newMessage.messageId] {
                moveInteraction(interactionId: childId, after: newMessage.messageId, messages: &currentInteractions)
            }
        }
        if numberOfNewMessages == 0 {
            return
        }
        conversation.messages.accept(currentInteractions)
        // check if conversation order changed
        if let firstDate = currentInteractions.last?.receivedDate, let secondDate = self.conversations.value.first?.messages.value.last?.receivedDate {
            if firstDate > secondDate {
                let currentConversations = self.conversations.value
                let sorted = currentConversations.sorted(by: { conversation1, conversations2 in
                                        guard let lastMessage1 = conversation1.messages.value.last,
                                              let lastMessage2 = conversations2.messages.value.last else {
                                            return conversation1.messages.value.count > conversations2.messages.value.count
                                        }
                                        return lastMessage1.receivedDate > lastMessage2.receivedDate
                                    })
                self.conversations.accept(sorted)
            }
        }
    }

    func conversationRequestReceived(conversationId: String, accountId: String, metadata: [String: String]) {
        if self.getConversationInfo(for: conversationId, accountId: accountId) != nil {
            return
        }
        var currentConversations = self.conversations.value
        let conversation = ConversationModel()
        conversation.updateRequestFromInfo(info: metadata)
        currentConversations.append(conversation)
        let sorted = currentConversations.sorted(by: { conversation1, conversations2 in
                                guard let lastMessage1 = conversation1.messages.value.last,
                                      let lastMessage2 = conversations2.messages.value.last else {
                                    return conversation1.messages.value.count > conversations2.messages.value.count
                                }
                                return lastMessage1.receivedDate > lastMessage2.receivedDate
                            })
        self.conversations.accept(sorted)
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        if let conv = self.getConversationInfo(for: conversationId, accountId: accountId) {
            // update conversation
        } else {
            var currentConversations = self.conversations.value
            if let info = messageAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
               let participantsInfo = messageAdapter.getConversationMembers(accountId, conversationId: conversationId) as? [[String: String]] {
                let conversation = ConversationModel(withId: conversationId, accountId: accountId, info: info)
                conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
                currentConversations.append(conversation)
                let sorted = currentConversations.sorted(by: { conversation1, conversations2 in
                                        guard let lastMessage1 = conversation1.messages.value.last,
                                              let lastMessage2 = conversations2.messages.value.last else {
                                            return conversation1.messages.value.count > conversations2.messages.value.count
                                        }
                                        return lastMessage1.receivedDate > lastMessage2.receivedDate
                                    })
                self.conversations.accept(sorted)
            }
        }
    }

    func conversationLoaded(conversationId: String, accountId: String, messages: [Any], accountURI: String) {
        guard let messagesDictionary = messages as? [[String: String]] else { return }
        self.insertMessages(conversationId: conversationId, accountId: accountId, messages: messagesDictionary, accountURI: accountURI)
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String], accountURI: String) {
        self.insertMessages(conversationId: conversationId, accountId: accountId, messages: [message], accountURI: accountURI)
    }

    func moveInteraction(interactionId: String, after parentId: String, messages: inout [MessageModel]) {
        if let index = messages.firstIndex(where: { messge in
            messge.messageId == interactionId
        }), let parentIndex = messages.firstIndex(where: { messge in
            messge.messageId == parentId
        }), parentIndex < messages.count - 1 {
            // if interaction we are going to move is parent for next interaction we should move next interaction as well
            let interactionToMove = messages[index]
            if index < messages.count - 1 {
                let nextInteraction = messages[index + 1]
                let moveNextInteraction = interactionToMove.messageId == nextInteraction.parentId
                messages.insert(messages.remove(at: index), at: parentIndex + 1)
                if !moveNextInteraction {
                    return
                }
                moveInteraction(interactionId: nextInteraction.messageId, after: interactionToMove.messageId, messages: &messages)
            } else {
                messages.insert(messages.remove(at: index), at: parentIndex + 1)
            }
        }
    }

    func getConversationInfo(for conversationId: String, accountId: String) -> [String: String]? {
        return messageAdapter.getConversationMembers(accountId, conversationId: conversationId) as? [String: String]
    }

    func acceptConversationRequest(conversationId: String, accountId: String) {
        self.messageAdapter.acceptConversationRequest(accountId, conversationId: conversationId)
    }

    func declineConversationRequest(conversationId: String, accountId: String) {
        self.messageAdapter.declineConversationRequest(accountId, conversationId: conversationId)
    }

    func removeConversation(conversationId: String, accountId: String) {
        self.messageAdapter.removeConversation(accountId, conversationId: conversationId)
    }

    func startConversation(accountId: String) {
        self.messageAdapter.startConversation(accountId)
    }

    func getConversationsForAccount(accountId: String, accountURI: String) -> Observable<[ConversationModel]> {
        /* if we don't have conversation that could mean the app
        just launched and we need symchronize messages status
        */
        var shouldUpdateMessagesStatus = true
        if self.conversations.value.first != nil {
            shouldUpdateMessagesStatus = false
        }
        // get swarms conversdations
        log.warning("getConversationsForAccount: \(accountURI)")
        var currentConversations = [ConversationModel]()
        if let swarmIds = messageAdapter.getSwarmConversations(forAccount: accountId) as? [String] {
            for swarmId in swarmIds {
                if let info = messageAdapter.getConversationInfo(forAccount: accountId, conversationId: swarmId) as? [String: String],
                   let participantsInfo = messageAdapter.getConversationMembers(accountId, conversationId: swarmId) as? [[String: String]] {
                    let conversation = ConversationModel(withId: swarmId, accountId: accountId, info: info)
                    conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
                    messageAdapter.loadConversationMessages(accountId, conversationId: swarmId, from: "", size: 3)
                    currentConversations.append(conversation)
                }
            }
        }
        // get swarm requests
        if let requests = messageAdapter.getSwarmRequests(forAccount: accountId) as? [[String: String]] {
            for request in requests {
                let conversation = ConversationModel()
                conversation.updateRequestFromInfo(info: request)
                currentConversations.append(conversation)
            }
        }
        // get conversations from db
        dbManager.getConversationsObservable(for: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] conversationsModels in
                currentConversations.append(contentsOf: conversationsModels)
                let sorted = currentConversations.sorted(by: { conversation1, conversations2 in
                                        guard let lastMessage1 = conversation1.messages.value.last,
                                              let lastMessage2 = conversations2.messages.value.last else {
                                            return conversation1.messages.value.count > conversations2.messages.value.count
                                        }
                                        return lastMessage1.receivedDate > lastMessage2.receivedDate
                                    })
                self?.conversations.accept(sorted)
                if let swarmIds = self?.messageAdapter.getSwarmConversations(forAccount: accountId) as? [String] {
                    for swarmId in swarmIds {
                        self?.messageAdapter.loadConversationMessages(accountId, conversationId: swarmId, from: "", size: 3)
                    }
                }
                // self?.conversations.accept(currentConversations)
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
            for message in (conversation.messages.value) {
                if !message.daemonId.isEmpty && (message.status == .unknown || message.status == .sending ) {
                    let updatedMessageStatus = self.status(forMessageId: message.daemonId)
                    if (updatedMessageStatus.rawValue > message.status.rawValue && updatedMessageStatus != .failure) ||
                        (updatedMessageStatus == .failure && message.status == .sending) {
                        self.dbManager.updateMessageStatus(daemonID: message.daemonId,
                                                           withStatus: updatedMessageStatus,
                                                           accountId: accountId)
                            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
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

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
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
                    .subscribe(onCompleted: { [weak self] in
                        self?.log.debug("Message saved")
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
//        if let generated = generated {
//            message.isGenerated = generated
//        }
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

        return Completable.create(subscribe: { [weak self] _ in
            guard let self = self else { return Disposables.create { } }
            self.messagesSemaphore.wait()
            self.dbManager.saveMessage(for: toAccountId,
                                       with: recipientRingId,
                                       message: message,
                                       incoming: message.incoming,
                                       interactionType: interactionType, duration: 0)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] _ in
//                    guard let self = self else { return }
//                    // append new message so it can be found if a status update is received before the DB finishes reload
//                    self.conversations.value
//                        .filter({ conversation in
//                            return conversation.participantUri == recipientRingId &&
//                                conversation.accountId == toAccountId
//                        })
//                        .first?.messages
//                        .append(message)
//                    self.messagesSemaphore.signal()
//                    if shouldRefreshConversations {
//                        self.dbManager.getConversationsObservable(for: toAccountId)
//                            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                            .subscribe(onNext: { [weak self] conversationsModels in
//                                self?.conversations.accept(conversationsModels)
//                            })
//                            .disposed(by: (self.disposeBag))
//                    }
//                    completable(.completed)
//                    }, onError: { error in
//                        self.messagesSemaphore.signal()
//                        completable(.error(error))
                })
                .disposed(by: self.disposeBag)

            return Disposables.create { }
        })
    }

    func findConversation(withUri uri: String,
                          withAccountId accountId: String) -> ConversationModel? {
        return self.conversations.value
            .filter({ conversation in
                return conversation.getParticipants().first?.uri == uri && conversation.accountId == accountId
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
//        let message = MessageModel(withId: "", receivedDate: date, content: messageContent, authorURI: "", incoming: false)
//       // message.isGenerated = true
//
//        self.dbManager.saveMessage(for: accountId, with: contactUri, message: message, incoming: false, interactionType: interactionType, duration: Int(duration))
//            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//            .subscribe(onNext: { [weak self] _ in
//                guard let self = self else { return }
//                if shouldUpdateConversation {
//                    self.dbManager.getConversationsObservable(for: accountId)
//                        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                        .subscribe(onNext: { conversationsModels in
//                            self.conversations.accept(conversationsModels)
//                        })
//                        .disposed(by: (self.disposeBag))
//                }
//                }, onError: { _ in
//            })
//            .disposed(by: self.disposeBag)
    }

    func generateDataTransferMessage(transferId: UInt64,
                                     transferInfo: NSDataTransferInfo,
                                     accountId: String,
                                     photoIdentifier: String?,
                                     updateConversation: Bool) -> Completable {

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }

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
           // message.isGenerated = false
            message.type = .fileTransfer

            self.messagesSemaphore.wait()
//            self.dbManager.saveMessage(for: accountId, with: contactUri,
//                                       message: message, incoming: isIncoming,
//                                       interactionType: interactionType, duration: 0)
//                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                .subscribe(onNext: { [weak self] message in
//                    guard let self = self else { return }
//                    self.dataTransferMessageMap[transferId] = message
//                    self.dbManager.getConversationsObservable(for: accountId)
//                        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                        .subscribe(onNext: { conversationsModels in
//                            if updateConversation {
//                                self.conversations.accept(conversationsModels)
//                            }
//                            let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
//                            var serviceEvent = ServiceEvent(withEventType: serviceEventType)
//                            serviceEvent.addEventInput(.transferId, value: transferId)
//                            self.responseStream.onNext(serviceEvent)
//
//                            self.messagesSemaphore.signal()
//                            completable(.completed)
//                        })
//                        .disposed(by: (self.disposeBag))
//                    }, onError: { [weak self] error in
//                        self?.messagesSemaphore.signal()
//                        completable(.error(error))
//                })
//                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func status(forMessageId messageId: String) -> MessageStatus {
        guard let status = UInt64(messageId) else { return .unknown }
        return self.messageAdapter.status(forMessageId: status)
    }

    func setMessageAsRead(daemonId: String, messageID: String,
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
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel, accountId: String, accountURI: String) -> Completable {

        return Completable.create(subscribe: { [weak self] _ in
            guard let self = self else { return Disposables.create { } }

            // Filter out read, outgoing, and transfer messages
            let unreadMessages = conversation.messages.value.filter({ messages in
                return messages.status != .displayed && messages.incoming && messages.type == .text
            })

            let messagesIds = unreadMessages.map({ $0.messageId }).filter({ !$0.isEmpty })
            let messagesDaemonIds = unreadMessages.map({ $0.daemonId }).filter({ !$0.isEmpty })
            messagesDaemonIds.forEach { (msgId) in
                self.messageAdapter
                    .setMessageDisplayedFrom(conversation.hash,
                                             byAccount: accountId,
                                             messageId: msgId,
                                             status: .displayed)
            }
//            self.dbManager
//                .setMessagesAsRead(messagesIDs: messagesIds,
//                                   withStatus: .displayed,
//                                   accountId: accountId)
//                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                .subscribe(onCompleted: { [weak self] in
//                    guard let self = self else { return }
//                    self.dbManager.getConversationsObservable(for: accountId)
//                        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                        .subscribe(onNext: { [weak self] conversationsModels in
//                            self?.conversations.accept(conversationsModels)
//                        })
//                        .disposed(by: (self.disposeBag))
//                    completable(.completed)
//                }, onError: { error in
//                    completable(.error(error))
//                })
//                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func deleteMessage(messagesId: Int64, accountId: String) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            self.dbManager
                .deleteMessage(messagesId: messagesId, accountId: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: { completable(.completed) }, onError: { error in completable(.error(error)) })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func getProfile(uri: String, accountId: String) -> Observable<Profile> {
        return self.dbManager.profileObservable(for: uri, createIfNotExists: false, accountId: accountId)
    }

    func clearHistory(conversation: ConversationModel, keepConversation: Bool) {
//        self.dbManager.clearHistoryFor(accountId: conversation.accountId, and: conversation.participantUri, keepConversation: keepConversation)
//            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//            .subscribe(onCompleted: { [weak self] in
//                guard let self = self else { return }
//                self.removeSavedFiles(accountId: conversation.accountId, conversationId: conversation.conversationId)
//                self.dbManager
//                    .getConversationsObservable(for: conversation.accountId)
//                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                    .subscribe(onNext: { [weak self] conversationsModels in
//                        self?.conversations.accept(conversationsModels)
//                    })
//                    .disposed(by: (self.disposeBag))
//                }, onError: { error in
//                    self.log.error(error)
//            })
//            .disposed(by: self.disposeBag)
    }

    func removeSavedFiles(accountId: String, conversationId: String) {
        let downloadsFolderName = Directories.downloads.rawValue
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let downloadsURL = documentsURL.appendingPathComponent(downloadsFolderName)
            .appendingPathComponent(accountId)
            .appendingPathComponent(conversationId)
        try? FileManager.default.removeItem(atPath: downloadsURL.path)
        let recordedFolderName = Directories.recorded.rawValue
        let recordedURL = documentsURL.appendingPathComponent(recordedFolderName)
            .appendingPathComponent(accountId)
            .appendingPathComponent(conversationId)
        try? FileManager.default.removeItem(atPath: recordedURL.path)
    }

    func messageStatusChanged(_ status: MessageStatus,
                              for messageId: UInt64,
                              fromAccount account: AccountModel,
                              to uri: String) {
//        self.messagesSemaphore.wait()
//        // Get conversations for this sender
//        let conversation = self.conversations.value.filter({ conversation in
//            return  conversation.participantUri == uri &&
//                    conversation.accountId == account.id
//        }).first
//
//        // Find message
//        if let messages: [MessageModel] = conversation?.messages.filter({ (message) -> Bool in
//            return  !message.daemonId.isEmpty && message.daemonId == String(messageId) &&
//                    ((status.rawValue > message.status.rawValue && status != .failure) ||
//                    (status == .failure && message.status == .sending))
//        }) {
//            if let message = messages.first {
//                let displayedMessage = status == .displayed && !message.incoming
//                let oldDisplayedMessage = conversation?.lastDisplayedMessage.id
//                let isLater = (conversation?.lastDisplayedMessage.id ?? 0) < Int64(0) || conversation?.lastDisplayedMessage.timestamp ?? Date() < message.receivedDate
//                if  displayedMessage && isLater {
//                    conversation?.lastDisplayedMessage = (message.messageId, message.receivedDate)
//                    var event = ServiceEvent(withEventType: .lastDisplayedMessageUpdated)
//                    event.addEventInput(.oldDisplayedMessage, value: oldDisplayedMessage)
//                    event.addEventInput(.newDisplayedMessage, value: message.messageId)
//                    self.responseStream.onNext(event)
//                }
//                self.dbManager
//                    .updateMessageStatus(daemonID: message.daemonId,
//                                         withStatus: status,
//                                         accountId: account.id)
//                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                    .subscribe(onCompleted: { [weak self] in
//                        guard let self = self else { return }
//                        self.messagesSemaphore.signal()
//                        self.log.info("messageStatusChanged: Message status updated")
//                        var event = ServiceEvent(withEventType: .messageStateChanged)
//                        event.addEventInput(.messageStatus, value: status)
//                        event.addEventInput(.messageId, value: String(messageId))
//                        event.addEventInput(.id, value: account.id)
//                        event.addEventInput(.uri, value: uri)
//                        self.responseStream.onNext(event)
//                    }, onError: { _ in
//                        self.messagesSemaphore.signal()
//                    })
//                    .disposed(by: self.disposeBag)
//            } else {
//                self.log.warning("messageStatusChanged: Message not found")
//                self.messagesSemaphore.signal()
//            }
//        } else {
//            self.messagesSemaphore.signal()
//        }
//
//        log.debug("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(account.id) to: \(uri)")
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
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: { [weak self] in
                guard let self = self else { return }
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

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
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
                    .subscribe(onCompleted: { [weak self] in
                        self?.log.debug("Location saved")
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
        return Completable.create(subscribe: { [weak self] _ in
            guard let self = self else { return Disposables.create { } }
//            self.dbManager.deleteLocationUpdates(incoming: incoming, peerUri: peerUri, accountId: accountId)
//                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                .subscribe(onCompleted: {
//                    if shouldRefreshConversations {
//                        self.dbManager.getConversationsObservable(for: accountId)
//                            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
//                            .subscribe(onNext: { [weak self] conversationsModels in
//                                self?.conversations.accept(conversationsModels)
//                            })
//                            .disposed(by: (self.disposeBag))
//                    }
//                    completable(.completed)
//                }, onError: { (error) in
//                    completable(.error(error))
//                })
                // .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }
}
