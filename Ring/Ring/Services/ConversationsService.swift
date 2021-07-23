/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

enum ConversationNotifications: String {
    case conversationReady
}

enum ConversationNotificationsKeys: String {
    case conversationId
    case accountId
}

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class ConversationsService {

    /**
     logguer
     */
    private let log = SwiftyBeaver.self

    private let conversationsAdapter: ConversationsAdapter
    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    var conversations = BehaviorRelay(value: [ConversationModel]())
    var conversationReady = BehaviorRelay(value: "")

    lazy var conversationsForCurrentAccount: Observable<[ConversationModel]> = {
        return self.conversations.asObservable()
    }()

    let dbManager: DBManager

    // MARK: initial loading

    init(withConversationsAdapter adapter: ConversationsAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.conversationsAdapter = adapter
        self.dbManager = dbManager
        ConversationsAdapter.conversationsDelegate = self
    }
    /**
     Called when application starts and when  account changed
     */
    func getConversationsForAccount(accountId: String, accountURI: String) -> Observable<[ConversationModel]> {
        /* if we don't have conversation that could mean the app
         just launched and we need symchronize messages status
         */
        let shouldUpdateMessagesStatus = self.conversations.value.first == nil
        var currentConversations = [ConversationModel]()
        var conversationToLoad = [String]() // list of swarm conversation we need to load first message
        // get swarms conversations
        if let swarmIds = conversationsAdapter.getSwarmConversations(forAccount: accountId) as? [String] {
            conversationToLoad = swarmIds
            for swarmId in swarmIds {
                self.addSwarm(conversationId: swarmId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            }
        }
        // get conversations from db
        dbManager.getConversationsObservable(for: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] conversationsModels in
                var conversationsFromDB = conversationsModels
                if shouldUpdateMessagesStatus {
                    self?.updateMessagesStatus(accountId: accountId, conversations: &conversationsFromDB)
                }
                currentConversations.append(contentsOf: conversationsFromDB)
                self?.sortAndUpdate(conversations: &currentConversations)
                // load one message for each swarm conversation
                for swarmId in conversationToLoad {
                    self?.conversationsAdapter.loadConversationMessages(accountId, conversationId: swarmId, from: "", size: 1)
                }
            })
            .disposed(by: self.disposeBag)
        return self.conversations.asObservable()
    }

    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ConversationModel]) {
        if let info = conversationsAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) {
            let conversation = ConversationModel(withId: conversationId, accountId: accountId, info: info)
            conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            conversations.append(conversation)
        }
    }
    /**
     Sort conversations and emit epdates for conversations
     */
    private func sortAndUpdate(conversations: inout [ConversationModel]) {
        /// sort conversaton by last message date
        let sorted = conversations.sorted(by: { conversation1, conversations2 in
            guard let lastMessage1 = conversation1.messages.value.last,
                  let lastMessage2 = conversations2.messages.value.last else {
                return conversation1.messages.value.count > conversations2.messages.value.count
            }
            return lastMessage1.receivedDate > lastMessage2.receivedDate
        })
        self.conversations.accept(sorted)
    }

    /**
     after adding new interactions for conversation we check if conversation order need to be changed
     */
    private func sortIfNeeded(modifiedMessages: [MessageModel]) {
        if let firstDate = modifiedMessages.last?.receivedDate, let secondDate = self.conversations.value.first?.messages.value.last?.receivedDate {
            if firstDate > secondDate {
                var currentConversations = self.conversations.value
                self.sortAndUpdate(conversations: &currentConversations)
            }
        }
    }
    /**
     move child interaction when found parent interaction
     */
    private func moveInteraction(interactionId: String, after parentId: String, messages: inout [MessageModel]) {
        if let index = messages.firstIndex(where: { messge in
            messge.id == interactionId
        }), let parentIndex = messages.firstIndex(where: { messge in
            messge.id == parentId
        }) {
            if parentIndex < messages.count - 1 {
                let interactionToMove = messages[index]
                if index < messages.count - 1 {
                    /// if interaction we are going to move is parent for next interaction we should move next interaction as well
                    let nextInteraction = messages[index + 1]
                    let moveNextInteraction = interactionToMove.id == nextInteraction.parentId
                    messages.insert(messages.remove(at: index), at: parentIndex + 1)
                    if !moveNextInteraction {
                        return
                    }
                    moveInteraction(interactionId: nextInteraction.id, after: interactionToMove.id, messages: &messages)
                } else {
                    /// message we are going to move is last in the list, we do not need to check child interactions
                    messages.insert(messages.remove(at: index), at: parentIndex + 1)
                }
            } else if parentIndex == messages.count - 1 {
                let interactionToMove = messages[index]
                let nextInteraction = messages[index + 1]
                let moveNextInteraction = interactionToMove.id == nextInteraction.parentId
                messages.append(messages.remove(at: index))
                if !moveNextInteraction {
                    return
                }
                moveInteraction(interactionId: nextInteraction.id, after: interactionToMove.id, messages: &messages)
            }
        }
    }

    // MARK: swarm interactions management

    func loadConversationMessages(conversationId: String, accountId: String, from: String) {
        self.conversationsAdapter.loadConversationMessages(accountId, conversationId: conversationId, from: from, size: 20)
    }

    func sendSwarmMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        self.conversationsAdapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId)
    }

    // MARK: actions for ConversationsManager
    /**
     Insert swarm messages to conversation.
     @param messages.  New messages to insert
     @param accountId.
     @param conversationId.
     @param fromLoaded. Indicates where it is a new received interactions or existiong interactions from loaded conversatio
     @return inserted. Returns true if at least one message was inserted.
     */
    func insertMessages(messages: [MessageModel], accountId: String, conversationId: String, fromLoaded: Bool) -> Bool {
        guard let conversation = self.conversations.value
                .filter({ conversation in
                    return conversation.id == conversationId && conversation.accountId == accountId
                })
                .first else { return false }
        var currentInteractions = conversation.messages.value
        var numberOfNewMessages = 0
        // if all loaded messages are of type .merge, we need to load next messages
        let numberOfInteractions = messages.filter { $0.type != .merge }.count
        if fromLoaded && numberOfInteractions == 0 {
            self.loadConversationMessages(conversationId: conversationId, accountId: accountId, from: messages.first?.id ?? "")
            return false
        }
        messages.reversed().forEach { newMessage in
            /// filter out merge interaction
            if newMessage.type == .merge { return }
            /// filter out existing messages
            if currentInteractions.contains(where: { message in
                message.id == newMessage.id
            }) { return }
            if fromLoaded {
                newMessage.status = .displayed
            }
            numberOfNewMessages += 1
            /// find parent to insert interaction after
            if let index = currentInteractions.firstIndex(where: { message in
                message.id == newMessage.parentId
            }) {
                if index < currentInteractions.count - 1 {
                    currentInteractions.insert(newMessage, at: index + 1)
                } else {
                    currentInteractions.append(newMessage)
                }
            } else {
                /// no parent found. Just add interaction to the end
                currentInteractions.append(newMessage)
                /// save message without parent to dictionary, so if we receive parent later we could move message
                conversation.parentsId[newMessage.parentId] = newMessage.id
            }
            /// if a new message is a parent for previously added message change messages order
            if conversation.parentsId.keys.contains(where: { parentId in
                parentId == newMessage.id
            }), let childId = conversation.parentsId[newMessage.id] {
                moveInteraction(interactionId: childId, after: newMessage.id, messages: &currentInteractions)
            }
        }
        if numberOfNewMessages == 0 {
            return false
        }
        /// emit signal for conversation messages
        conversation.messages.accept(currentInteractions)
        /// check if conversation order changed. In this case we need emit new signal for conversation
        self.sortIfNeeded(modifiedMessages: currentInteractions)
        return true
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) == nil {
            var currentConversations = self.conversations.value
            self.addSwarm(conversationId: conversationId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            self.sortAndUpdate(conversations: &currentConversations)
            var data = [String: Any]()
            data[ConversationNotificationsKeys.conversationId.rawValue] = conversationId
            data[ConversationNotificationsKeys.accountId.rawValue] = accountId
            NotificationCenter.default.post(name: NSNotification.Name(ConversationNotifications.conversationReady.rawValue), object: nil, userInfo: data)
            self.conversationsAdapter.loadConversationMessages(accountId, conversationId: conversationId, from: "", size: 2)
        }
        self.conversationReady.accept(conversationId)
        /// check if legacy conversation for linked account was added to db. If so remopve conversation
        if let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId),
           conversation.isCoredialog(),
           let jamiId = conversation.getParticipants().first?.jamiId,
           let uri = JamiURI.init(schema: .ring, infoHach: jamiId).uriString,
           let nonSwarmConvId = try? self.dbManager.getConversationsFor(contactUri: uri, accountId: accountId) {
            var conversations = self.conversations.value
            _ = self.dbManager
                .clearHistoryFor(accountId: accountId, and: uri, keepConversation: false)
                .subscribe(onCompleted: { [weak self] in
                    guard let self = self else { return }
                    if let index = conversations.firstIndex(where: { conversationModel in
                        conversationModel.id == String(nonSwarmConvId)
                    }) {
                        conversations.remove(at: index)
                        self.conversations.accept(conversations)
                    }
                }, onError: { _ in
                })
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: conversations management

    func removeConversation(conversationId: String, accountId: String) {
        self.conversationsAdapter.removeConversation(accountId, conversationId: conversationId)
    }

    func startConversation(accountId: String) {
        self.conversationsAdapter.startConversation(accountId)
    }

    // MARK: legacy support for non swarm conversations

    private func updateMessagesStatus(accountId: String, conversations: inout [ConversationModel]) {
        /**
         If the app was closed prior to messages receiving a "stable"
         status, incorrect status values will remain in the database.
         Get updated message status from the daemon for each
         message as conversations are loaded from the database.
         Only sent messages having an 'unknown' or 'sending' status
         are considered for updating.
         */
        for conversation in conversations where !conversation.isSwarm() {
            var updatedMessages = 0
            for message in (conversation.messages.value) {
                if !message.daemonId.isEmpty && (message.status == .unknown || message.status == .sending ) {
                    let updatedMessageStatus = self.status(forMessageId: message.daemonId)
                    if (updatedMessageStatus.rawValue > message.status.rawValue && updatedMessageStatus != .failure) ||
                        (updatedMessageStatus == .failure && message.status == .sending) {
                        self.dbManager.updateMessageStatus(daemonID: message.daemonId,
                                                           withStatus: InteractionStatus(status: updatedMessageStatus),
                                                           accountId: accountId)
                            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                            .subscribe(onCompleted: { [] in
                                print("Message status updated - load")
                            })
                            .disposed(by: self.disposeBag)
                    }
                }
                if !message.daemonId.isEmpty &&
                    (message.transferStatus == .ongoing ||
                        message.transferStatus == .created ||
                        message.transferStatus == .awaiting ||
                        message.transferStatus == .unknown) {
                    updatedMessages += 1
                    let updatedMessageStatus: DataTransferStatus = .error
                    message.transferStatus = updatedMessageStatus
                    self.dbManager.updateMessageStatus(daemonID: message.daemonId,
                                                       withStatus: InteractionStatus(status: updatedMessageStatus),
                                                       accountId: accountId)
                        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                        .subscribe()
                        .disposed(by: self.disposeBag)
                }
            }
            if updatedMessages > 0 {
                conversation.messages.accept(conversation.messages.value)
            }
        }
    }

    private func status(forMessageId messageId: String) -> MessageStatus {
        guard let status = UInt64(messageId) else { return .unknown }
        return self.conversationsAdapter.status(forMessageId: status)
    }

    private func saveMessageModelToDb(message: MessageModel,
                                      toConversationWith recipientURI: String,
                                      toAccountId: String,
                                      duration: Int64,
                                      shouldRefreshConversations: Bool,
                                      interactionType: InteractionType = InteractionType.text) -> Completable {

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            // self.messagesSemaphore.wait()
            self.dbManager.saveMessage(for: toAccountId,
                                       with: recipientURI,
                                       message: message,
                                       incoming: message.incoming,
                                       interactionType: interactionType, duration: Int(duration))
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] savedMessage in
                    guard let self = self else { return }
                    let hash = JamiURI(from: recipientURI).hash
                    /// append new message so it can be found if a status update is received before the DB finishes reload
                    if shouldRefreshConversations, let conversation = self.conversations.value
                        .filter({ conversation in
                            return conversation.getParticipants().first?.jamiId == hash &&
                                conversation.accountId == toAccountId
                        })
                        .first {
                        let content = (message.type == .contact || message.type == .call) ?
                            GeneratedMessage.init(from: message.content).toMessage(with: Int(duration))
                            : message.content
                        message.content = content
                        message.id = savedMessage.messageID
                        conversation.appendNonSwarm(message: message)
                        self.sortIfNeeded(modifiedMessages: conversation.messages.value)
                    }
                    completable(.completed)
                }, onError: { error in
                    completable(.error(error))
                })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func sendNonSwarmMessage(withContent content: String,
                             from senderAccount: AccountModel,
                             jamiId: String) -> Completable {

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            let contentDict = [self.textPlainMIMEType: content]
            let messageId = String(self.conversationsAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: jamiId))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
            let contactUri = JamiURI.init(schema: type, infoHach: jamiId, account: senderAccount)
            guard let stringUri = contactUri.uriString else {
                completable(.completed)
                return Disposables.create {}
            }
            if let uri = accountHelper.uri {
                let message = self.createMessage(withId: messageId,
                                                 withContent: content,
                                                 byAuthor: uri,
                                                 type: .text,
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
                       type: MessageType,
                       incoming: Bool) -> MessageModel {
        let message = MessageModel(withId: messageId, receivedDate: Date(), content: content, authorURI: author, incoming: incoming)
        message.type = type
        return message
    }

    func saveMessage(message: MessageModel,
                     toConversationWith jamiId: String,
                     toAccountId: String,
                     shouldRefreshConversations: Bool) -> Completable {
        return self.saveMessageModelToDb(message: message,
                                         toConversationWith: jamiId,
                                         toAccountId: toAccountId,
                                         duration: 0,
                                         shouldRefreshConversations: shouldRefreshConversations,
                                         interactionType: InteractionType.text)
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
        message.type = interactionType.toMessageType()
        self.saveMessageModelToDb(message: message,
                                  toConversationWith: contactUri,
                                  toAccountId: accountId,
                                  duration: duration,
                                  shouldRefreshConversations: shouldUpdateConversation,
                                  interactionType: interactionType)
            .subscribe()
            .disposed(by: self.disposeBag)
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

    func removeConversationFromDB(conversation: ConversationModel, keepConversation: Bool) {
        guard let jamiId = conversation.getParticipants().first?.jamiId else { return }
        let schema: URIType = conversation.type == .sip ? .sip : .ring
        guard let uri = JamiURI(schema: schema, infoHach: jamiId).uriString else { return }
        self.dbManager.clearHistoryFor(accountId: conversation.accountId, and: uri, keepConversation: keepConversation)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: { [weak self] in
                guard let self = self else { return }
                self.removeSavedFiles(accountId: conversation.accountId, conversationId: conversation.id)
                var values = self.conversations.value
                if let index = values.firstIndex(of: conversation) {
                    values.remove(at: index)
                    self.conversations.accept(values)
                }
            }, onError: { error in
                self.log.error(error)
            })
            .disposed(by: self.disposeBag)
    }

    private func removeSavedFiles(accountId: String, conversationId: String) {
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

    /**
     When sending swarm conversation request to peer who does not have app with swarm support
     swarm conversation will be removed an non swarm conversation should be created
     */
    func saveLegacyConversation(conversation: ConversationModel, isExisting: Bool) {
        guard let participantId = conversation.getParticipants().first?.jamiId else { return }
        /// we need to create uri to save conversation to db. saveLegacyConversation called when swarm conversation failed. In this case uri schema should be ring
        guard let participantURI = JamiURI(schema: .ring, infoHach: participantId).uriString else { return }
        /// create db. Return if opening db failed
        do {
            /// return false if could not open database connection
            if try !dbManager.createDatabaseForAccount(accountId: conversation.accountId) {
                return
            }
            /// if tables already exist an exeption will be thrown
        } catch { }
        /// add conversation to db
        let conversationId = dbManager.createConversationsFor(contactUri: participantURI, accountId: conversation.accountId)
        /// update conversation list
        conversation.id = conversationId
        conversation.type = .nonSwarm
        var value = self.conversations.value
        if !isExisting {
            value.append(conversation)
        }
        self.conversations.accept(value)
        /// add contact message
        self.generateMessage(messageContent: GeneratedMessage.invitationAccepted.toString(),
                             contactUri: participantURI,
                             accountId: conversation.accountId,
                             date: Date(),
                             interactionType: InteractionType.contact,
                             shouldUpdateConversation: true)
        self.conversationReady.accept(conversationId)
    }

    func createSipConversation(uri: String, accountId: String) {
        /// create db. Return if opening db failed
        do {
            /// return false if could not open database connection
            if try !dbManager.createDatabaseForAccount(accountId: accountId) {
                return
            }
            /// if tables already exist an exeption will be thrown
        } catch { }
        /// add conversation to db
        let conversationId = dbManager.createConversationsFor(contactUri: uri, accountId: accountId)
        if !self.conversations.value.map({ $0.id }).contains(conversationId) {
            /// new conversation. Need to update conversation list
            self.dbManager
                .getConversationsObservable(for: accountId)
                .subscribe { [weak self] conversationModels in
                    self?.conversations.accept(conversationModels)
                } onError: { _ in
                }
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: helpers

    func getConversationForParticipant(jamiId: String, accontId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.getParticipants().first?.jamiId == jamiId && conversation.isDialog() && conversation.accountId == accontId
        }.first
    }

    func getConversationForId(conversationId: String, accountId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.id == conversationId && conversation.accountId == accountId
        }.first
    }

    // MARK: file transfer

    func generateDataTransferMessage(transferId: String,
                                     transferInfo: NSDataTransferInfo,
                                     accountId: String,
                                     photoIdentifier: String?,
                                     updateConversation: Bool,
                                     conversationId: String,
                                     messageId: String) -> Completable {

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }

            let fileSizeWithUnit = ByteCountFormatter.string(fromByteCount: Int64(transferInfo.totalSize), countStyle: .file)
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
            let message = MessageModel(withId: transferId,
                                       receivedDate: date, content: messageContent,
                                       authorURI: author, incoming: isIncoming)
            message.transferStatus = isIncoming ? .awaiting : .created
            message.type = .fileTransfer
            self.dbManager.saveMessage(for: accountId, with: contactUri,
                                       message: message, incoming: isIncoming,
                                       interactionType: interactionType, duration: 0)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] dbMessage in
                    guard let self = self else { return }
                    let hash = JamiURI(from: contactUri).hash
                    if updateConversation, let conversation = self.conversations.value
                        .filter({ conversation in
                            return conversation.getParticipants().first?.jamiId == hash &&
                                conversation.accountId == accountId
                        })
                        .first {
                        let content = (message.type == .contact || message.type == .call) ?
                            GeneratedMessage.init(from: message.content).toMessage(with: Int(0))
                            : message.content
                        message.content = content
                        message.id = dbMessage.messageID
                        message.daemonId = transferId
                        conversation.appendNonSwarm(message: message)
                        self.sortIfNeeded(modifiedMessages: conversation.messages.value)
                    }
                    let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
                    var serviceEvent = ServiceEvent(withEventType: serviceEventType)
                    serviceEvent.addEventInput(.transferId, value: transferId)
                    serviceEvent.addEventInput(.conversationId, value: conversationId)
                    serviceEvent.addEventInput(.state, value: DataTransferStatus.created)
                    serviceEvent.addEventInput(.accountId, value: accountId)
                    serviceEvent.addEventInput(.messageId, value: messageId)
                    self.responseStream.onNext(serviceEvent)
                    completable(.completed)
                }, onError: { error in
                    completable(.error(error))
                })
                .disposed(by: self.disposeBag)
            return Disposables.create { }
        })
    }

    func transferStatusChanged(_ transferStatus: DataTransferStatus,
                               for transferId: String,
                               conversationId: String,
                               interactionId: String,
                               accountId: String,
                               to jamiId: String) {
        var conversationUnwraped: ConversationModel?
        if !conversationId.isEmpty {
            conversationUnwraped = self.getConversationForId(conversationId: conversationId, accountId: accountId)
        } else {
            conversationUnwraped = self.getConversationForParticipant(jamiId: jamiId, accontId: accountId)
        }
        guard let conversation = conversationUnwraped else { return }
        let messages = conversation.messages.value
        if let message = messages.first(where: { messageModel in
            messageModel.id == interactionId
        }) {
            message.transferStatus = transferStatus
        }
        conversation.messages.accept(messages)
        let serviceEventType: ServiceEventType = .dataTransferMessageUpdated
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.transferId, value: transferId)
        serviceEvent.addEventInput(.state, value: transferStatus)
        self.responseStream.onNext(serviceEvent)
        /// for non swarm conversationId is empty. Update status in db
        if !conversation.isSwarm() {
            self.dbManager
                .updateTransferStatus(daemonID: String(transferId),
                                      withStatus: transferStatus,
                                      accountId: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: interaction status

    func setMessageAsRead(conversation: ConversationModel, messageId: String, daemonId: String) {
        guard let conversationURI = conversation.getConversationURI() else { return }
        let messageToUpdate = !conversation.isSwarm() ? daemonId : messageId
        self.conversationsAdapter
            .setMessageDisplayedFrom(conversationURI,
                                     byAccount: conversation.accountId,
                                     messageId: messageToUpdate,
                                     status: .displayed)
        if let message = conversation.messages.value.filter({ messageModel in
            messageModel.id == messageId && messageModel.daemonId == daemonId
        }).first {
            message.status = .displayed
        }
        if !conversation.isSwarm() {
            self.dbManager
                .setMessagesAsRead(messagesIDs: [messageId],
                                   withStatus: .displayed,
                                   accountId: conversation.accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel, accountId: String, accountURI: String) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self,
                  let conversationURI = conversation.getConversationURI() else { return Disposables.create { } }

            /// Filter out read, outgoing, and transfer messages
            let unreadMessages = conversation.messages.value.filter({ messages in
                return messages.status != .displayed && messages.incoming && messages.type == .text
            })

            /// notify contacts that message was read
            let messagesIds = unreadMessages.map({ $0.id }).filter({ !$0.isEmpty })
            let idsToUpdate = unreadMessages
                .map({ message in
                        return !conversation.isSwarm() ? message.daemonId : message.id})
                .filter({ !$0.isEmpty })
            idsToUpdate.forEach { (msgId) in
                self.conversationsAdapter
                    .setMessageDisplayedFrom(conversationURI,
                                             byAccount: accountId,
                                             messageId: msgId,
                                             status: .displayed)
            }
            /// update messages  status localy
            unreadMessages.forEach { message in
                message.status = .displayed
            }

            /// for non swarm update db
            if !conversation.isSwarm() {
                self.dbManager
                    .setMessagesAsRead(messagesIDs: messagesIds,
                                       withStatus: .displayed,
                                       accountId: accountId)
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe()
                    .disposed(by: self.disposeBag)
            }
            completable(.completed)
            return Disposables.create { }
        })
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        guard let conversation = self.conversations.value.filter({ conversation in
            if !conversationId.isEmpty {
                return  conversation.id == conversationId &&
                    conversation.accountId == accountId
            }
            return conversation.getParticipants().first?.jamiId == jamiId &&
                conversation.accountId == accountId
        }).first else { return }

        /// Find message
        if let message: MessageModel = conversation.messages.value.filter({ (message) -> Bool in
            let messageIDSame = !conversation.isSwarm() ? !message.daemonId.isEmpty && message.daemonId == messageId : message.id == messageId
            return messageIDSame &&
                ((status.rawValue > message.status.rawValue && status != .failure) ||
                    (status == .failure && message.status == .sending))
        }).first {
            message.status = status
            var event = ServiceEvent(withEventType: .messageStateChanged)
            event.addEventInput(.messageStatus, value: status)
            event.addEventInput(.messageId, value: messageId)
            event.addEventInput(.id, value: accountId)
            event.addEventInput(.uri, value: jamiId)
            self.responseStream.onNext(event)
            log.debug("messageStatusChanged: \(status.rawValue) for: \(messageId) from: \(accountId) to: \(jamiId)")
            /// for non swarm conversation we need to save status to db
            if conversation.isSwarm() { return }
            self.dbManager
                .updateMessageStatus(daemonID: message.daemonId,
                                     withStatus: InteractionStatus(status: status),
                                     accountId: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: typing indicator

    func setIsComposingMsg(to peer: String, from account: String, isComposing: Bool) {
        conversationsAdapter.setComposingMessageTo(peer, fromAccount: account, isComposing: isComposing)
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
            let messageId = String(self.conversationsAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientUri))
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
            return self.saveMessageModelToDb(message: message, toConversationWith: recipientRingId,
                                             toAccountId: toAccountId, duration: 0, shouldRefreshConversations: shouldRefreshConversations,
                                             interactionType: InteractionType.location)
        }
        return Completable.create(subscribe: { completable in
            completable(.completed)
            return Disposables.create { }
        })
    }

    func deleteLocationUpdate(incoming: Bool, peerUri: String, accountId: String, shouldRefreshConversations: Bool) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            self.dbManager.deleteLocationUpdates(incoming: incoming, peerUri: peerUri, accountId: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onCompleted: {
                    if shouldRefreshConversations {
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

extension ConversationsService: ConversationsAdapterDelegate {
    func conversationRemoved(conversationId: String, accountId: String) {
        guard let index = self.conversations.value.firstIndex(where: { conversationModel in
            conversationModel.id == conversationId && conversationModel.accountId == accountId
        }) else { return }
        var conversations = self.conversations.value
        conversations.remove(at: index)
        self.conversations.accept(conversations)
    }
}
