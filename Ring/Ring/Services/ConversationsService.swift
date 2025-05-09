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

    var conversations = BehaviorRelay(value: [ConversationModel]())
    var conversationReady = BehaviorRelay(value: "")

    var requestedReplyTargets = [String]()
    var replyTargets = BehaviorRelay(value: [MessageModel]())

    let dbManager: DBManager

    private let serialOperationQueue = DispatchQueue(label: "com.jami.ConversationsService.operationQueue")

    // MARK: initial loading

    init(withConversationsAdapter adapter: ConversationsAdapter, dbManager: DBManager) {
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.conversationsAdapter = adapter
        self.dbManager = dbManager
    }
    /**
     Called when application starts and when  account changed
     */
    func getConversationsForAccount(accountId: String, accountURI: String) {
        serialOperationQueue.async { [weak self] in
            guard let self = self else { return }
            var currentConversations = [ConversationModel]()
            self.conversations.accept(currentConversations)
            var conversationToLoad = [String]() // list of swarm conversation we need to load first message
            // get swarms conversations
            if let swarmIds = self.conversationsAdapter.getSwarmConversations(forAccount: accountId) as? [String] {
                conversationToLoad = swarmIds
                for swarmId in swarmIds {
                    self.addSwarm(conversationId: swarmId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
                }
            }
            // get conversations from db
            self.dbManager.getConversationsObservable(for: accountId)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] conversationsModels in
                    self?.serialOperationQueue.async {
                        guard let self = self else { return }
                        let oneToOne = currentConversations.filter { conv in
                            conv.type == .oneToOne || conv.type == .nonSwarm
                        }
                        .map { conv in
                            return conv.getParticipants().first?.jamiId
                        }
                        /// filter out contact requests
                        let conversationsFromDB = conversationsModels.filter { conversation in
                            !(conversation.messages.count == 1 && conversation.messages.first!.content == L10n.GeneratedMessage.nonSwarmInvitationReceived)
                        }
                        /// Filter out conversations that already added to swarm
                        .filter { conversation in
                            guard let jamiId = conversation.getParticipants().first?.jamiId else { return true }
                            return !oneToOne.contains(jamiId)
                        }
                        currentConversations.append(contentsOf: conversationsFromDB)
                        self.sortAndUpdate(conversations: &currentConversations)
                        // load one message for each swarm conversation
                        for swarmId in conversationToLoad {
                            self.loadConversationMessages(conversationId: swarmId, accountId: accountId, from: "", size: 1)
                        }
                    }
                }, onError: { [weak self] _ in
                    self?.serialOperationQueue.async {
                        guard let self = self else { return }
                        self.conversations.accept(currentConversations)
                        for swarmId in conversationToLoad {
                            self.loadConversationMessages(conversationId: swarmId, accountId: accountId, from: "", size: 1)
                        }
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    func clearConversationsData(accountId: String) {
        self.conversations.value.forEach { conversation in
            self.conversationsAdapter
                .clearCashe(forConversationId: conversation.id, accountId: accountId)
        }
    }

    func getSwarmMembers(conversationId: String, accountId: String, accountURI: String) -> [ParticipantInfo] {
        if let participantsInfo = conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) {
            return participantsInfo.compactMap({ info in
                if let jamiId = info["uri"],
                   let roleText = info["role"] {
                    var role = ParticipantRole.member
                    switch roleText {
                    case "admin":
                        role = .admin
                    case "member":
                        role = .member
                    case "invited":
                        role = .invited
                    case "banned":
                        role = .banned
                    default:
                        role = .unknown
                    }
                    return ParticipantInfo(jamiId: jamiId, role: role)
                }
                return nil
            })
        }
        return []
    }

    func updateConversationMessages(conversationId: String) {
        for conversation in self.conversations.value where conversation.id == conversationId {
            conversation.clearMessages()
            self.conversationsAdapter.loadConversationMessages(conversation.accountId, conversationId: conversationId, from: "", size: 40)
        }
    }

    func reloadConversationsAndRequests(accountId: String) {
        self.conversationsAdapter.reloadConversationsAndRequests(accountId)
    }

    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ConversationModel]) {
        if let info = conversationsAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) {
            let conversation = ConversationModel(withId: conversationId, accountId: accountId, info: info)
            if let prefsInfo = getConversationPreferences(accountId: accountId, conversationId: conversationId) {
                conversation.updatePreferences(preferences: prefsInfo)
            }
            conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            conversation.updateLastDisplayedMessage(participantsInfo: participantsInfo)
            self.updateUnreadMessages(conversation: conversation, accountId: accountId)
            conversations.append(conversation)
        }
    }
    /**
     Sort conversations and emit updates for conversations
     */
    private func sortAndUpdate(conversations: inout [ConversationModel]) {
        /// sort conversaton by last message date
        let sorted = conversations.sorted(by: { conversation1, conversations2 in
            guard let lastMessage1 = conversation1.lastMessage,
                  let lastMessage2 = conversations2.lastMessage else {
                return conversation1.messages.count > conversations2.messages.count
            }
            return lastMessage1.receivedDate > lastMessage2.receivedDate
        })
        self.conversations.accept(sorted)
    }

    private func updateUnreadMessages(conversation: ConversationModel, accountId: String) {
        if let lastRead = conversation.getLastReadMessage(), let jamiId = conversation.getLocalParticipants()?.jamiId {
            let unreadInteractions = self.conversationsAdapter.countInteractions(accountId, conversationId: conversation.id, from: lastRead, to: "", authorUri: jamiId)
            conversation.numberOfUnreadMessages.accept(Int(unreadInteractions))
        }
    }

    /**
     after adding new interactions for conversation we check if conversation order need to be changed
     */
    private func sortIfNeeded() {
        serialOperationQueue.async { [weak self] in
            guard let self = self else { return }
            let receivedDates = self.conversations.value.map({ conv in
                return conv.lastMessage?.receivedDate ?? Date()
            })
            if !receivedDates.isDescending() {
                var currentConversations = self.conversations.value
                self.sortAndUpdate(conversations: &currentConversations)
            }
        }
    }

    // MARK: swarm interactions management

    func loadConversationMessages(conversationId: String, accountId: String, from: String, size: Int = 40) {
        DispatchQueue.global(qos: .background).async {
            self.conversationsAdapter.loadConversationMessages(accountId, conversationId: conversationId, from: from, size: size)
        }
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
        if self.requestedReplyTargets.contains(target) {
            return .duplicateRequest
        }
        self.requestedReplyTargets.append(target)

        if let message = self.findReplyTargetsById(target) {
            return .messageFound(message)
        } else {
            self.triggerConversationLoad(accountId: accountId, conversationId: conversationId, replyToId: target)
            return .loadTriggered
        }
    }

    private func findReplyTargetsById(_ id: String) -> MessageModel? {
        return self.replyTargets.value.first(where: { $0.id == id })
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

    func insertReplies(messages: [MessageModel], accountId: String, conversationId: String, fromLoaded: Bool) -> Bool {
        if self.isTargetReply(messages: messages) {
            self.processReplyTargetMessage(with: messages.first)
            return true
        }
        return true
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
    func insertMessages(messages: [MessageModel], accountId: String, localJamiId: String, conversationId: String, fromLoaded: Bool) -> Bool {
        var result = false

        serialOperationQueue.sync {
            guard let conversation = self.conversations.value
                    .filter({ conversation in
                        return conversation.id == conversationId && conversation.accountId == accountId
                    })
                    .first else { return }

            if self.isTargetReply(messages: messages) {
                self.processReplyTargetMessage(with: messages.first)
                result = true
                return
            }

            // If all the loaded messages are of type .merge or .profile or have already been added, we need to load the next set of messages.
            let filtered = messages.filter { newMessage in newMessage.type != .merge && newMessage.type != .profile && !conversation.messages.contains(where: { message in
                message.id == newMessage.id
            })
            }

            if fromLoaded && filtered.isEmpty {
                if let lastMessage = messages.last?.id {
                    self.loadConversationMessages(conversationId: conversationId, accountId: accountId, from: lastMessage)
                }
                result = false
                return
            }

            var newMessages = [MessageModel]()
            filtered.forEach { newMessage in
                newMessages.append(newMessage)
                guard let lastMessage = conversation.lastMessage,
                      lastMessage.receivedDate > newMessage.receivedDate else {
                    conversation.lastMessage = newMessage
                    return
                }
            }

            if fromLoaded {
                conversation.messages.append(contentsOf: newMessages)
            } else {
                conversation.messages.insert(contentsOf: newMessages, at: 0)
            }

            self.sortIfNeeded()

            if !fromLoaded {
                let incomingMessages = newMessages.filter({ $0.authorId != localJamiId && !$0.authorId.isEmpty })
                conversation.updateUnreadMessages(count: incomingMessages.count)
            }

            conversation.newMessages.accept(LoadedMessages(messages: newMessages, fromHistory: fromLoaded))
            result = true
        }

        return result
    }

    private func isTargetReply(messages: [MessageModel]) -> Bool {
        if let targetMessage = messages.first,
           messages.count == 1,
           self.requestedReplyTargets.contains(targetMessage.id) {
            return true
        }
        return false
    }

    private func processReplyTargetMessage(with message: MessageModel?) {
        guard let target = message else { return }
        self.updateReplyTargets(with: target)
        self.removeMessageIdFromRequestedTargets(target.id)
    }

    private func updateReplyTargets(with message: MessageModel) {
        var updatedTargets = replyTargets.value
        if !updatedTargets.contains(where: { $0.id == message.id }) {
            updatedTargets.append(message)
            self.replyTargets.accept(updatedTargets)
        }
    }

    private func removeMessageIdFromRequestedTargets(_ messageId: String) {
        self.requestedReplyTargets.removeAll { $0 == messageId }
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        serialOperationQueue.async { [weak self] in
            guard let self = self else { return }
            // Process the conversation
            let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId)

            if conversation == nil {
                var currentConversations = self.conversations.value
                self.addSwarm(conversationId: conversationId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
                self.sortAndUpdate(conversations: &currentConversations)

                DispatchQueue.main.async {
                    var data = [String: Any]()
                    data[ConversationNotificationsKeys.conversationId.rawValue] = conversationId
                    data[ConversationNotificationsKeys.accountId.rawValue] = accountId
                    NotificationCenter.default.post(name: NSNotification.Name(ConversationNotifications.conversationReady.rawValue), object: nil, userInfo: data)
                }

                self.loadConversationMessages(conversationId: conversationId, accountId: accountId, from: "", size: 2)
                self.sortIfNeeded()
                self.conversationReady.accept(conversationId)
                return
            }

            if let info = self.conversationsAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
               let participantsInfo = self.conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) {
                conversation?.updateInfo(info: info)
                if let prefsInfo = self.getConversationPreferences(accountId: accountId, conversationId: conversationId) {
                    conversation?.updatePreferences(preferences: prefsInfo)
                }
                conversation?.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
                self.updateUnreadMessages(conversation: conversation!, accountId: accountId)
                self.loadConversationMessages(conversationId: conversationId, accountId: accountId, from: "", size: 2)
                self.sortIfNeeded()
            }

            self.conversationReady.accept(conversationId)
        }
    }

    func getConversationInfo(conversationId: String, accountId: String) -> [String: String] {
        return conversationsAdapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String] ?? [String: String]()
    }

    func saveJamsConversation(for jamiId: String, accountId: String, refreshConversations: Bool) {
        if self.getConversationForParticipant(jamiId: jamiId, accountId: accountId) != nil { return }
        let contactUri = JamiURI(schema: .ring, infoHash: jamiId)
        guard let contactUriString = contactUri.uriString else { return }
        let conversationId = dbManager.createConversationsFor(contactUri: contactUriString, accountId: accountId)
        if !refreshConversations { return }
        if conversationId.isEmpty || conversationId == "-1" { return }
        let conversationModel = ConversationModel(withParticipantUri: contactUri,
                                                  accountId: accountId)
        conversationModel.type = .jams
        conversationModel.id = conversationId
        var conversations = self.conversations.value
        conversations.append(conversationModel)
        self.conversations.accept(conversations)
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        guard let index = self.conversations.value.firstIndex(where: { conversationModel in
            conversationModel.id == conversationId && conversationModel.accountId == accountId
        }) else { return }
        var conversations = self.conversations.value
        conversations.remove(at: index)
        self.conversations.accept(conversations)
        let serviceEventType: ServiceEventType = .conversationRemoved
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func conversationMemberEvent(conversationId: String, accountId: String, memberUri: String, event: ConversationMemberEvent, accountURI: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId),
              let participantsInfo = conversationsAdapter.getConversationMembers(accountId, conversationId: conversationId) else { return }
        conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
        let serviceEventType: ServiceEventType = .conversationMemberEvent
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func reactionAdded(conversationId: String, accountId: String, messageId: String, reaction: [String: String]) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        conversation.reactionAdded(messageId: messageId, reaction: reaction)
    }

    func reactionRemoved(conversationId: String, accountId: String, messageId: String, reactionId: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        conversation.reactionRemoved(messageId: messageId, reactionId: reactionId)
    }

    struct TypingStatus {
        let from: String
        let status: Int
        let conversationId: String
    }

    func composingStatusChanged(accountId: String, conversationId: String, from: String, status: Int) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else {
            return
        }

        let typingStatus = TypingStatus(from: from, status: status, conversationId: conversationId)

        typingStatusSubject.onNext(typingStatus)
    }

    let typingStatusSubject = ReplaySubject<TypingStatus>.create(bufferSize: 1)

    var typingStatusStream: Observable<TypingStatus> {
        return typingStatusSubject.asObservable()
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap, localJamiId: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        conversation.messageUpdated(swarmMessage: message, localJamiId: localJamiId)
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
                    let hash = JamiURI(from: recipientURI).hash
                    /// append new message so it can be found if a status update is received before the DB finishes reload
                    if shouldRefreshConversations, let conversation = self.conversations.value
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
                        self.sortIfNeeded()
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
        let schema: URIType = conversation.type == .sip ? .sip : .ring
        guard let uri = JamiURI(schema: schema, infoHash: jamiId).uriString else { return }
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
        if !self.conversations.value.map({ $0.id }).contains(conversationId) {
            /// new conversation. Need to update conversation list
            self.dbManager
                .getConversationsObservable(for: accountId)
                .subscribe { [weak self] conversationModels in
                    self?.conversations.accept(conversationModels)
                    self?.sortIfNeeded()
                } onError: { _ in
                }
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: helpers

    func getConversationForParticipant(jamiId: String, accountId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.getParticipants().first?.jamiId == jamiId && conversation.isDialog() && conversation.accountId == accountId
        }.first
    }

    func getConversationForId(conversationId: String, accountId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.id == conversationId && conversation.accountId == accountId
        }.first
    }

    func addSwarmConversationId(conversationId: String, accountId: String, jamiId: String) {
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil { return }
        var conversations = self.conversations.value
        let conversation = ConversationModel(withId: conversationId, accountId: accountId)
        conversation.type = .oneToOne
        conversation.addParticipant(jamiId: jamiId)
        conversations.append(conversation)
        self.conversations.accept(conversations)
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
                    let hash = JamiURI(from: contactUri).hash
                    if updateConversation, let conversation = self.conversations.value
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
                        self.sortIfNeeded()
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
            conversationUnwraped = self.getConversationForParticipant(jamiId: jamiId, accountId: accountId)
        }
        guard let conversation = conversationUnwraped else { return }
        let messages = conversation.messages
        if let message = messages.first(where: { messageModel in
            messageModel.id == interactionId
        }) {
            message.transferStatus = transferStatus
        }
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
        conversation.messageStatusUpdated(status: status, messageId: messageId, jamiId: jamiId)
    }

    func conversationProfileUpdated(conversationId: String, accountId: String, profile: [String: String]) {
        guard let conversation = self.conversations.value.filter({ conversation in
            return  conversation.id == conversationId && conversation.accountId == accountId
        }).first else { return }
        conversation.updateProfile(profile: profile)
        let serviceEventType: ServiceEventType = .conversationProfileUpdated
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func conversationPreferencesUpdated(conversationId: String, accountId: String, preferences: [String: String]) {
        guard let conversation = self.conversations.value.filter({ conversation in
            return  conversation.id == conversationId && conversation.accountId == accountId
        }).first else { return }
        conversation.updatePreferences(preferences: preferences)
        let serviceEventType: ServiceEventType = .conversationPreferencesUpdated
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func getConversationPreferences(accountId: String, conversationId: String) -> [String: String]? {
        return self.conversationsAdapter.getConversationPreferences(forAccount: accountId, conversationId: conversationId) as? [String: String]
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
