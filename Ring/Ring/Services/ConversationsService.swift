/*
 *  Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

enum LoadReplyResult {
    case messageFound(MessageModel)
    case duplicateRequest
    case loadTriggered
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

    var conversations: Observable<[ConversationModel]> {
        return store.conversationsStream
    }
    var currentConversations: [ConversationModel] {
        return store.currentConversations
    }
    var conversationReady: Observable<String> {
        return store.conversationReadyStream
    }

    private let replyTargetRegistry = ReplyTargetRegistry()
    var replyTargets: BehaviorRelay<[MessageModel]> {
        return replyTargetRegistry.targets
    }

    let dbManager: DBManager

    private let serialOperationQueue = DispatchQueue(label: "com.jami.ConversationsService.operationQueue")
    private let store: ConversationStore

    var onEvent: ((ConversationEvent) -> Void)?

    private(set) lazy var eventSource = ConversationEventSource(
        onStateEvent: { [weak self] event in
            guard let self = self else { return }
            self.perform { store in
                self.apply(event, to: store)
            }
        },
        onEvent: { [weak self] event in
            guard let self = self else { return }
            guard event.isOrderedWithConversationState else {
                self.onEvent?(event)
                return
            }
            self.serialOperationQueue.async {
                self.onEvent?(event)
            }
        })

    func startEvents() {
        eventSource.attachToAdapter()
    }

    // MARK: initial loading

    init(withConversationsAdapter adapter: ConversationsAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.conversationsAdapter = adapter
        self.dbManager = dbManager
        self.store = ConversationStore(adapter: adapter,
                                       dbManager: dbManager,
                                       queue: serialOperationQueue,
                                       replyTargets: replyTargetRegistry,
                                       responseStream: responseStream)
    }

    private func perform(_ work: @escaping (ConversationStore) -> Void) {
        let store = self.store
        serialOperationQueue.async {
            work(store)
        }
    }

    private func apply(_ event: ConversationStateEvent, to store: ConversationStore) {
        switch event {
        case let .composingStatusChanged(accountId, conversationId, from, status):
            store.composingStatusChanged(accountId: accountId, conversationId: conversationId,
                                         from: from, status: status)

        case let .reactionAdded(accountId, conversationId, messageId, reaction):
            store.reactionAdded(conversationId: conversationId, accountId: accountId,
                                messageId: messageId, reaction: reaction)

        case let .reactionRemoved(accountId, conversationId, messageId, reactionId):
            store.reactionRemoved(conversationId: conversationId, accountId: accountId,
                                  messageId: messageId, reactionId: reactionId)

        case let .conversationProfileUpdated(accountId, conversationId, profile):
            store.conversationProfileUpdated(conversationId: conversationId, accountId: accountId,
                                             profile: profile)

        case let .conversationPreferencesUpdated(accountId, conversationId, preferences):
            store.conversationPreferencesUpdated(conversationId: conversationId, accountId: accountId,
                                                 preferences: preferences)
        }
    }

    /**
     Called when application starts and when  account changed
     */
    func getConversationsForAccount(accountId: String, accountURI: String) {
        perform { store in
            store.loadConversations(accountId: accountId, accountURI: accountURI)
        }
    }

    func clearConversationsData(accountId: String) {
        perform { store in
            store.clearConversationsData(accountId: accountId)
        }
    }

    func getSwarmMembers(conversationId: String, accountId: String, accountURI: String) -> [ParticipantData] {
        if let participantsInfo = conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) {
            return participantsInfo.compactMap({ info in
                if let jamiId = info["uri"],
                   let roleText = info["role"] {
                    let role: ParticipantRole = ParticipantRole(rawValue: roleText) ?? .member
                    return ParticipantData(jamiId: jamiId, role: role)
                }
                return nil
            })
        }
        return []
    }

    func updateConversationMessages(conversationId: String) {
        for conversation in self.currentConversations where conversation.id == conversationId {
            conversation.clearMessages()
            self.conversationsAdapter.loadConversationMessages(conversation.accountId, conversationId: conversationId, from: "", size: 40)
        }
    }

    func reloadConversationsAndRequests(accountId: String) {
        self.conversationsAdapter.reloadConversationsAndRequests(accountId)
    }

    func addConversationFromAcceptedRequest(conversationId: String, accountId: String, accountURI: String, type: ConversationType) {
        perform { store in
            store.addConversationFromAcceptedRequest(conversationId: conversationId, accountId: accountId,
                                                     accountURI: accountURI, type: type)
        }
    }

    // MARK: swarm interactions management

    func loadConversationMessages(conversationId: String, accountId: String, from: String, size: Int = 40) {
        store.loadMessages(conversationId: conversationId, accountId: accountId, from: from, size: size)
    }

    func loadMessagesUntil(messageId: String, conversationId: String, accountId: String, from: String) {
        self.conversationsAdapter.loadConversation(
            forAccountId: accountId,
            conversationId: conversationId,
            from: from,
            until: messageId
        )
    }

    func loadTargetReply(conversationId: String, accountId: String, target: String) -> LoadReplyResult {
        if !self.replyTargetRegistry.request(target) {
            return .duplicateRequest
        }

        if let message = self.replyTargetRegistry.target(withId: target) {
            return .messageFound(message)
        } else {
            self.triggerConversationLoad(accountId: accountId, conversationId: conversationId, replyToId: target)
            return .loadTriggered
        }
    }

    private func triggerConversationLoad(accountId: String, conversationId: String, replyToId: String) {
        self.conversationsAdapter.loadConversation(
            forAccountId: accountId,
            conversationId: conversationId,
            from: replyToId,
            until: replyToId
        )
    }

    func getReplyMessage(conversationId: String, accountId: String, id: String) {
        self.conversationsAdapter.loadConversationMessages(accountId, conversationId: conversationId, from: id, size: 1)
    }

    func editSwarmMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        self.conversationsAdapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 1)
    }

    func sendEmojiReactionMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        self.conversationsAdapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 2)
    }

    func sendSwarmMessage(conversationId: String, accountId: String, message: String, parentId: String) {
        self.conversationsAdapter.sendSwarmMessage(accountId, conversationId: conversationId, message: message, parentId: parentId, flag: 0)
    }

    func getConversationInfo(conversationId: String, accountId: String) -> [String: String] {
        return conversationsAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String] ?? [String: String]()
    }

    var typingStatusStream: Observable<TypingStatus> {
        return store.typingStatus.asObservable()
    }

    // MARK: actions for ConversationsManager

    func insertMessages(messages: [MessageModel], accountId: String, localJamiId: String, conversationId: String, fromLoaded: Bool) -> Bool {
        return store.insertMessages(messages: messages, accountId: accountId, localJamiId: localJamiId,
                                    conversationId: conversationId, fromLoaded: fromLoaded)
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        store.conversationReady(conversationId: conversationId, accountId: accountId, accountURI: accountURI)
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        store.conversationRemoved(conversationId: conversationId, accountId: accountId)
    }

    func conversationMemberEvent(conversationId: String, accountId: String, accountURI: String) {
        store.conversationMemberEvent(conversationId: conversationId, accountId: accountId, accountURI: accountURI)
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap, localJamiId: String) {
        store.messageUpdated(conversationId: conversationId, accountId: accountId, message: message, localJamiId: localJamiId)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        store.messageStatusChanged(status, for: messageId, from: accountId, to: jamiId, in: conversationId)
    }

    // MARK: conversations management

    func removeConversation(conversationId: String, accountId: String) {
        self.conversationsAdapter.removeConversation(accountId, conversationId: conversationId)
    }

    func startConversation(accountId: String) -> String {
        return self.conversationsAdapter.startConversation(accountId)
    }

    // MARK: legacy support for non swarm conversations

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
                    self.perform { store in
                        let hash = JamiURI(from: recipientURI).hash
                        /// append new message so it can be found if a status update is received before the DB finishes reload
                        if shouldRefreshConversations, let conversation = store.currentConversations
                            .filter({ conversation in
                                return conversation.getParticipants().first?.jamiId == hash &&
                                    conversation.accountId == toAccountId
                            })
                            .first {
                            let content = (message.type.isContact || message.type == .call) ?
                                GeneratedMessage.init(from: message.content).toMessage(with: Int(duration))
                                : message.content
                            message.content = content
                            message.id = savedMessage.messageID
                            conversation.appendNonSwarm(message: message)
                            if let lastMessage = conversation.lastMessage {
                                if lastMessage.receivedDate < message.receivedDate {
                                    conversation.lastMessage = message
                                }

                            } else {
                                conversation.lastMessage = message
                            }
                            store.sortIfNeeded()
                        }
                        completable(.completed)
                    }
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
            let messageId = String(self.conversationsAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: jamiId, flag: 0))
            let accountHelper = AccountModelHelper(withAccount: senderAccount)
            let type = accountHelper.isAccountSip() ? URIType.sip : URIType.ring
            let contactUri = JamiURI.init(schema: type, infoHash: jamiId, account: senderAccount)
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
        /// do not add multiple contact interactions
        if let hash = JamiURI(from: contactUri).hash,
           interactionType == .contact,
           let conversation = self.getConversationForParticipant(jamiId: hash, accountId: accountId),
           conversation.messages.map({ ($0.content) }).contains(messageContent) {
            return

        }
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
        let schema: URIType = conversation.isSip() ? .sip : .ring
        guard let uri = JamiURI(schema: schema, infoHash: jamiId).uriString else { return }
        let finish: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.removeSavedFiles(accountId: conversation.accountId, conversationId: conversation.id)
            self.perform { store in
                store.removeConversation(conversation)
                if !keepConversation {
                    var serviceEvent = ServiceEvent(withEventType: .conversationRemoved)
                    serviceEvent.addEventInput(.conversationId, value: conversation.id)
                    serviceEvent.addEventInput(.accountId, value: conversation.accountId)
                    serviceEvent.addEventInput(.peerUri, value: uri)
                    self.responseStream.onNext(serviceEvent)
                }
            }
        }
        self.dbManager.clearHistoryFor(accountId: conversation.accountId, and: uri, keepConversation: keepConversation)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onCompleted: finish,
                       onError: { [weak self] error in
                        self?.log.error(error)
                        finish()
                       })
            .disposed(by: self.disposeBag)
    }

    private func removeSavedFiles(accountId: String, conversationId: String) {
        let downloadsFolderName = Directories.downloads.rawValue
        guard let documentsURL = Constants.documentsPath else { return }
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

    func createSipConversation(uri: String, accountId: String) {
        /// create db. Return if opening db failed
        do {
            /// return false if unable to open database connection
            if try !dbManager.createDatabaseForAccount(accountId: accountId) {
                return
            }
            /// if tables already exist an exeption will be thrown
        } catch { }
        /// add conversation to db
        let conversationId = dbManager.createConversationsFor(contactUri: uri, accountId: accountId)
        if !self.currentConversations.map({ $0.id }).contains(conversationId) {
            /// new conversation. Need to update conversation list
            self.dbManager
                .getConversationsObservable(for: accountId)
                .subscribe { [weak self] conversationModels in
                    self?.perform { store in
                        store.replaceConversations(conversationModels)
                        store.sortIfNeeded()
                    }
                } onError: { _ in
                }
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: helpers

    func getConversationForParticipant(jamiId: String, accountId: String) -> ConversationModel? {
        return store.getConversationForParticipant(jamiId: jamiId, accountId: accountId)
    }

    func getConversationForId(conversationId: String, accountId: String) -> ConversationModel? {
        return store.getConversationForId(conversationId: conversationId, accountId: accountId)
    }

    func addSwarmConversationId(conversationId: String, accountId: String, jamiId: String) {
        perform { store in
            store.addSwarmConversationId(conversationId: conversationId, accountId: accountId, jamiId: jamiId)
        }
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
                                                infoHash: transferInfo.peer).uriString else {
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
                    self.perform { store in
                        let hash = JamiURI(from: contactUri).hash
                        if updateConversation, let conversation = store.currentConversations
                            .filter({ conversation in
                                return conversation.getParticipants().first?.jamiId == hash &&
                                    conversation.accountId == accountId
                            })
                            .first {
                            let content = (message.type.isContact || message.type == .call) ?
                                GeneratedMessage.init(from: message.content).toMessage(with: Int(0))
                                : message.content
                            message.content = content
                            message.id = dbMessage.messageID
                            message.daemonId = transferId
                            conversation.appendNonSwarm(message: message)
                            store.sortIfNeeded()
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
                    }
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
        perform { store in
            store.transferStatusChanged(transferStatus, for: transferId, conversationId: conversationId,
                                        interactionId: interactionId, accountId: accountId, to: jamiId)
        }
    }

    func setMessagesAsRead(forConversation conversation: ConversationModel, accountId: String, accountURI: String) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self,
                  let conversationURI = conversation.getConversationURI() else { return Disposables.create { } }

            var lastUnreadMessageId: String?

            if conversation.isSwarm() {
                let lastMessage = conversation.messages.first
                lastUnreadMessageId = lastMessage?.id
            } else {
                // Filter out read, outgoing, and transfer messages
                let unreadMessages = conversation.messages.filter({ messages in
                    return messages.status != .displayed && messages.incoming && messages.type == .text
                })
                let messagesIds = unreadMessages.map({ $0.id }).filter({ !$0.isEmpty })
                self.dbManager
                    .setMessagesAsRead(messagesIDs: messagesIds,
                                       withStatus: .displayed,
                                       accountId: accountId)
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe()
                    .disposed(by: self.disposeBag)
                lastUnreadMessageId = unreadMessages.last?.id
            }

            // update messages  status localy
            conversation.setAllMessagesAsRead()

            if let lastUnreadMessageId = lastUnreadMessageId {
                self.conversationsAdapter
                    .setMessageDisplayedFrom(conversationURI,
                                             byAccount: accountId,
                                             messageId: lastUnreadMessageId,
                                             status: .displayed)
            }
            completable(.completed)
            return Disposables.create { }
        })
    }

    func getConversationPreferences(accountId: String, conversationId: String) -> [String: String]? {
        return store.getConversationPreferences(accountId: accountId, conversationId: conversationId)
    }

    func updateConversationInfos(accountId: String, conversationId: String, infos: [String: String]) {
        self.conversationsAdapter.updateConversationInfos(for: accountId, conversationId: conversationId, infos: infos)
    }

    func updateConversationPrefs(accountId: String, conversationId: String, prefs: [String: String]) {
        self.conversationsAdapter.updateConversationPreferences(for: accountId, conversationId: conversationId, prefs: prefs)
    }

    func addConversationMember(accountId: String, conversationId: String, memberId: String) {
        self.conversationsAdapter.addConversationMember(for: accountId, conversationId: conversationId, memberId: memberId)
    }

    func removeConversationMember(accountId: String, conversationId: String, memberId: String) {
        self.conversationsAdapter.removeConversationMember(for: accountId, conversationId: conversationId, memberId: memberId)
    }

    // MARK: typing indicator

    func setIsComposingMsg(to conversationUri: String, from accountId: String, isComposing: Bool) {
        conversationsAdapter.setComposingMessageTo(conversationUri, fromAccount: accountId, isComposing: isComposing)
    }
}

// MARK: Location
extension ConversationsService {

    // TODO: Possible extraction with sendMessage
    func sendLocation(withContent content: String, from senderAccount: AccountModel,
                      recipientUri: String, shouldRefreshConversations: Bool,
                      shouldTryToSave: Bool) -> Completable {

        return Completable.create(subscribe: { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            let contentDict = [self.geoLocationMIMEType: content]
            _ = String(self.conversationsAdapter.sendMessage(withContent: contentDict, withAccountId: senderAccount.id, to: recipientUri, flag: 1))
            completable(.completed)
            return Disposables.create {}
        })
    }
}
