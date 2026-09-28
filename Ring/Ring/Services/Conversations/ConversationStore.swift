/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import RxRelay

struct TypingStatus {
    let from: String
    let status: Int
    let conversationId: String
}

private final class ConversationRecord {
    let conversation: ConversationModel
    let state: BehaviorRelay<ConversationState>
    var messages = [MessageModel]()
    var lastMessage: MessageModel?

    init(conversation: ConversationModel, state: BehaviorRelay<ConversationState>) {
        self.conversation = conversation
        self.state = state
    }

    func appendNonSwarm(messages newMessages: [MessageModel]) {
        self.messages.append(contentsOf: newMessages)
        let newestFirst = Array(newMessages.reversed())
        self.conversation.newMessages.accept(LoadedMessages(messages: newestFirst, fromHistory: false))
        self.updateNonSwarmUnreadCount()
    }

    func reconcile(with stored: StoredConversation) {
        let knownIds = Set(self.messages.map { $0.id })
        let missing = stored.messages
            .filter { !knownIds.contains($0.id) }
            .sorted { $0.receivedDate < $1.receivedDate }
        if let oldestMissing = missing.first {
            let newestKnown = self.messages.map { $0.receivedDate }.max()
            if newestKnown.map({ $0 <= oldestMissing.receivedDate }) ?? true {
                self.appendNonSwarm(messages: missing)
            } else {
                self.messages = (self.messages + missing).sorted { $0.receivedDate < $1.receivedDate }
                self.conversation.newMessages.accept(LoadedMessages(messages: [MessageModel](), fromHistory: false,
                                                                    reset: true))
                self.conversation.newMessages.accept(LoadedMessages(messages: Array(self.messages.reversed()),
                                                                    fromHistory: true))
                self.updateNonSwarmUnreadCount()
            }
        }
        if let storedLast = stored.lastMessage,
           self.lastMessage.map({ $0.receivedDate < storedLast.receivedDate }) ?? true {
            self.lastMessage = storedLast
        }
    }

    private func updateNonSwarmUnreadCount() {
        guard !self.conversation.isSwarm() else { return }
        let unread = self.messages.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
        self.conversation.numberOfUnreadMessages.accept(unread)
    }

    func clearMessages() {
        self.messages = [MessageModel]()
        self.conversation.newMessages.accept(LoadedMessages(messages: [MessageModel](), fromHistory: false,
                                                            reset: true))
        self.lastMessage = nil
        self.conversation.numberOfUnreadMessages.accept(0)
    }

    func setAllMessagesAsRead() {
        var updated = [MessageModel]()
        for index in self.messages.indices where self.messages[index].status != .displayed &&
            self.messages[index].incoming && self.messages[index].type == .text {
            updated.append(self.updateMessage(at: index, { $0.status = .displayed }))
        }
        if !updated.isEmpty {
            self.conversation.messagesUpdated.onNext(updated)
        }
        self.conversation.numberOfUnreadMessages.accept(0)
    }

    func reactionAdded(messageId: String, reaction: [String: String]) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.reactionAdded(reaction: reaction)
        }) else { return }
        self.conversation.reactionsUpdated.onNext(message)
    }

    func reactionRemoved(messageId: String, reactionId: String) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.reactionRemoved(reactionId: reactionId)
        }) else { return }
        self.conversation.reactionsUpdated.onNext(message)
    }

    func messageUpdated(swarmMessage: SwarmMessageWrap, localJamiId: String) {
        guard let message = self.updateMessage(messageId: swarmMessage.id, {
            $0.messageUpdated(message: swarmMessage, localJamiId: localJamiId)
        }) else { return }
        self.conversation.messagesUpdated.onNext([message])
    }

    func messageStatusUpdated(status: MessageStatus, messageId: String, jamiId: String) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.messageStatusUpdated(status: status, jamiId: jamiId)
        }) else { return }
        self.conversation.messagesUpdated.onNext([message])
    }

    func transferStatusUpdated(status: DataTransferStatus, messageId: String, transferId: String) {
        guard let index = self.messages.firstIndex(where: { message in
            (!messageId.isEmpty && message.id == messageId) ||
                (message.type == .fileTransfer && message.daemonId == transferId)
        }) else { return }
        self.conversation.messagesUpdated.onNext([self.updateMessage(at: index, { $0.transferStatus = status })])
    }

    func updateUnreadMessages(count: Int) {
        self.conversation.numberOfUnreadMessages.accept(self.conversation.numberOfUnreadMessages.value + count)
    }

    private func updateMessage(messageId: String, _ change: (inout MessageData) -> Void) -> MessageModel? {
        guard let index = self.messages.firstIndex(where: { $0.id == messageId }) else { return nil }
        return self.updateMessage(at: index, change)
    }

    private func updateMessage(at index: Int, _ change: (inout MessageData) -> Void) -> MessageModel {
        let message = self.messages[index].updating(change)
        self.messages[index] = message
        if self.lastMessage?.id == message.id {
            self.lastMessage = message
        }
        return message
    }
}

// swiftlint:disable type_body_length
final class ConversationStore {

    private let conversations = BehaviorRelay(value: [ConversationModel]())
    private var records = [ObjectIdentifier: ConversationRecord]()
    private var loadGeneration = 0
    private let conversationReady = BehaviorRelay(value: "")
    let typingStatus = ReplaySubject<TypingStatus>.create(bufferSize: 1)

    private let adapter: ConversationsAdapter
    private let dbManager: DBManager
    private let queue: DispatchQueue
    private let replyTargets: ReplyTargetRegistry
    private let responseStream: PublishSubject<ServiceEvent>
    private let disposeBag = DisposeBag()

    init(adapter: ConversationsAdapter,
         dbManager: DBManager,
         queue: DispatchQueue,
         replyTargets: ReplyTargetRegistry,
         responseStream: PublishSubject<ServiceEvent>) {
        self.adapter = adapter
        self.dbManager = dbManager
        self.queue = queue
        self.replyTargets = replyTargets
        self.responseStream = responseStream
    }

    // MARK: lookup

    var conversationsStream: Observable<[ConversationModel]> {
        return conversations.asObservable()
    }

    var currentConversations: [ConversationModel] {
        return conversations.value
    }

    var conversationReadyStream: Observable<String> {
        return conversationReady.asObservable()
    }

    func getConversationForParticipant(jamiId: String, accountId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.getParticipants().first?.jamiId == jamiId && conversation.isCoredialog() && conversation.accountId == accountId
        }.first
    }

    func getConversationForId(conversationId: String, accountId: String) -> ConversationModel? {
        return self.conversations.value.filter { conversation in
            conversation.id == conversationId && conversation.accountId == accountId
        }.first
    }

    // MARK: loading

    func loadConversations(accountId: String, accountURI: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        var currentConversations = [ConversationModel]()
        self.loadGeneration += 1
        let generation = self.loadGeneration
        self.conversations.accept(currentConversations)
        var conversationToLoad = [String]() // list of swarm conversation we need to load first message
        // get swarms conversations
        if let swarmIds = self.adapter.getSwarmConversations(forAccount: accountId) as? [String] {
            conversationToLoad = swarmIds
            for swarmId in swarmIds {
                self.addSwarm(conversationId: swarmId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            }
        }
        // get conversations from db
        self.dbManager.getConversationsObservable(for: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
            .subscribe(onNext: { [weak self] storedConversations in
                self?.queue.async {
                    guard let self = self, generation == self.loadGeneration else { return }
                    let oneToOne = currentConversations.filter { conv in
                        conv.isCoredialog()
                    }
                    .map { conv in
                        return conv.getParticipants().first?.jamiId
                    }
                    /// filter out contact requests
                    let conversationsFromDB = storedConversations.filter { conversation in
                        !(conversation.messages.count == 1 && conversation.messages.first!.content == L10n.GeneratedMessage.nonSwarmInvitationReceived)
                    }
                    /// Filter out conversations that already added to swarm
                    .filter { conversation in
                        guard let jamiId = conversation.participantUri.hash else { return true }
                        return !oneToOne.contains(jamiId)
                    }
                    .map { self.makeConversation(from: $0) }
                    currentConversations.append(contentsOf: conversationsFromDB)
                    self.sortAndUpdate(conversations: &currentConversations)
                    self.removeUnpublishedRecords()
                    self.loadLatestMessages(swarmIds: conversationToLoad, accountId: accountId)
                    self.scheduleUnreadCounts(for: currentConversations, accountId: accountId)
                }
            }, onError: { [weak self] _ in
                self?.queue.async {
                    guard let self = self, generation == self.loadGeneration else { return }
                    self.conversations.accept(currentConversations)
                    self.removeUnpublishedRecords()
                    self.loadLatestMessages(swarmIds: conversationToLoad, accountId: accountId)
                    self.scheduleUnreadCounts(for: currentConversations, accountId: accountId)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func clearConversationsData(accountId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        self.conversations.value.forEach { conversation in
            self.adapter.clearCashe(forConversationId: conversation.id, accountId: accountId)
        }
    }

    func addConversationFromAcceptedRequest(conversationId: String, accountId: String, accountURI: String, type: ConversationType) {
        dispatchPrecondition(condition: .onQueue(queue))
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil {
            return
        }

        guard let info = self.adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
              let participantsInfo = self.adapter.getConversationMembers(accountId, conversationId: conversationId) else {
            // Adapter data not ready yet; daemon's conversationReady will handle it later
            return
        }

        var state = ConversationState(type: type)
        state.updateInfo(info: info)
        state.updateProfile(profile: info)
        self.configure(&state, accountId: accountId, conversationId: conversationId, participantsInfo: participantsInfo, accountURI: accountURI)
        let conversation = self.makeConversation(id: conversationId, accountId: accountId, state: state)

        var currentConversations = self.conversations.value
        currentConversations.append(conversation)
        self.publishNewConversation(conversationId: conversationId, accountId: accountId, conversations: &currentConversations)
    }

    func replaceConversations(with storedConversations: [StoredConversation]) {
        dispatchPrecondition(condition: .onQueue(queue))
        self.loadGeneration += 1
        self.conversations.accept(storedConversations.map { self.makeConversation(from: $0) })
        self.removeUnpublishedRecords()
    }

    func removeConversation(_ conversation: ConversationModel) {
        dispatchPrecondition(condition: .onQueue(queue))
        var values = self.conversations.value
        if let index = values.firstIndex(of: conversation) {
            self.records[ObjectIdentifier(values[index])] = nil
            values.remove(at: index)
            self.conversations.accept(values)
        }
    }

    func addSwarmConversationId(conversationId: String, accountId: String, jamiId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil { return }
        var conversations = self.conversations.value
        var state = ConversationState(type: .oneToOne)
        state.addParticipant(jamiId: jamiId)
        conversations.append(self.makeConversation(id: conversationId, accountId: accountId, state: state))
        self.conversations.accept(conversations)
    }

    // MARK: libjami conversation signals

    /**
     Insert swarm messages to conversation.
     @param messages.  New messages to insert
     @param accountId.
     @param conversationId.
     @param fromLoaded. Indicates where it is a new received interactions or existiong interactions from loaded conversatio
     @return inserted. Returns true if at least one message was inserted.
     */
    func insertMessages(messages: [MessageModel], accountId: String, localJamiId: String, conversationId: String, fromLoaded: Bool) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId),
              let record = self.record(for: conversation) else { return false }

        if self.isTargetReply(messages: messages) {
            self.processReplyTargetMessage(with: messages.first)
            return true
        }

        // If all the loaded messages are of type .merge or .profile or have already been added, we need to load the next set of messages.
        let filtered = messages.filter { newMessage in newMessage.type != .merge && newMessage.type != .profile && !record.messages.contains(where: { message in
            message.id == newMessage.id
        })
        }

        if fromLoaded && filtered.isEmpty {
            if let lastMessage = messages.last?.id {
                self.loadMessages(conversationId: conversationId, accountId: accountId, from: lastMessage)
            }
            return false
        }

        var newMessages = [MessageModel]()
        filtered.forEach { newMessage in
            newMessages.append(newMessage)
            guard let lastMessage = record.lastMessage,
                  lastMessage.receivedDate > newMessage.receivedDate else {
                record.lastMessage = newMessage
                return
            }
        }

        if fromLoaded {
            record.messages.append(contentsOf: newMessages)
        } else {
            record.messages.insert(contentsOf: newMessages, at: 0)
        }

        self.scheduleSort()

        if !fromLoaded {
            let incomingMessages = newMessages.filter({ $0.authorId != localJamiId && !$0.authorId.isEmpty })
            record.updateUnreadMessages(count: incomingMessages.count)
        }

        conversation.newMessages.accept(LoadedMessages(messages: newMessages, fromHistory: fromLoaded))
        return true
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else {
            var currentConversations = self.conversations.value
            self.addSwarm(conversationId: conversationId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            self.publishNewConversation(conversationId: conversationId, accountId: accountId, conversations: &currentConversations)
            return
        }

        if let info = self.adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = self.adapter.getConversationMembers(accountId, conversationId: conversationId) {
            let prefsInfo = self.getConversationPreferences(accountId: accountId, conversationId: conversationId)
            self.update(conversation) { state in
                state.updateInfo(info: info)
                if let prefsInfo = prefsInfo {
                    state.updatePreferences(preferences: prefsInfo)
                }
                state.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            }
            self.scheduleUnreadCount(for: conversation, accountId: accountId)
            self.loadMessages(conversationId: conversationId, accountId: accountId, from: "", size: 2)
            self.scheduleSort()
        }

        self.conversationReady.accept(conversationId)
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let index = self.conversations.value.firstIndex(where: { conversationModel in
            conversationModel.id == conversationId && conversationModel.accountId == accountId
        }) else { return }
        var conversations = self.conversations.value
        self.records[ObjectIdentifier(conversations[index])] = nil
        conversations.remove(at: index)
        self.conversations.accept(conversations)
        let serviceEventType: ServiceEventType = .conversationRemoved
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func conversationMemberEvent(conversationId: String, accountId: String, accountURI: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId),
              let members = adapter.getConversationMembers(accountId, conversationId: conversationId) else { return }
        self.update(conversation) { $0.addParticipantsFromArray(participantsInfo: members, accountURI: accountURI) }
        var serviceEvent = ServiceEvent(withEventType: .conversationMemberEvent)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func reactionAdded(conversationId: String, accountId: String, messageId: String, reaction: [String: String]) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        self.record(for: conversation)?.reactionAdded(messageId: messageId, reaction: reaction)
    }

    func reactionRemoved(conversationId: String, accountId: String, messageId: String, reactionId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        self.record(for: conversation)?.reactionRemoved(messageId: messageId, reactionId: reactionId)
    }

    func composingStatusChanged(accountId: String, conversationId: String, from: String, status: Int) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil else {
            return
        }

        let typingStatus = TypingStatus(from: from, status: status, conversationId: conversationId)

        self.typingStatus.onNext(typingStatus)
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap, localJamiId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        self.record(for: conversation)?.messageUpdated(swarmMessage: message, localJamiId: localJamiId)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.conversations.value.filter({ conversation in
            if !conversationId.isEmpty {
                return  conversation.id == conversationId &&
                    conversation.accountId == accountId
            }
            return conversation.getParticipants().first?.jamiId == jamiId &&
                conversation.accountId == accountId
        }).first else { return }
        self.record(for: conversation)?.messageStatusUpdated(status: status, messageId: messageId, jamiId: jamiId)
    }

    func conversationProfileUpdated(conversationId: String, accountId: String, profile: [String: String]) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.conversations.value.filter({ conversation in
            return  conversation.id == conversationId && conversation.accountId == accountId
        }).first else { return }
        self.update(conversation) { $0.updateProfile(profile: profile) }
        let serviceEventType: ServiceEventType = .conversationProfileUpdated
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    func conversationPreferencesUpdated(conversationId: String, accountId: String, preferences: [String: String]) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let conversation = self.conversations.value.filter({ conversation in
            return  conversation.id == conversationId && conversation.accountId == accountId
        }).first else { return }
        self.update(conversation) { $0.updatePreferences(preferences: preferences) }
        let serviceEventType: ServiceEventType = .conversationPreferencesUpdated
        var serviceEvent = ServiceEvent(withEventType: serviceEventType)
        serviceEvent.addEventInput(.conversationId, value: conversationId)
        serviceEvent.addEventInput(.accountId, value: accountId)
        self.responseStream.onNext(serviceEvent)
    }

    // MARK: messages

    func messages(of conversation: ConversationModel) -> [MessageModel] {
        dispatchPrecondition(condition: .onQueue(queue))
        return self.record(for: conversation)?.messages ?? []
    }

    func appendNonSwarm(message: MessageModel, to conversation: ConversationModel) {
        dispatchPrecondition(condition: .onQueue(queue))
        self.record(for: conversation)?.appendNonSwarm(messages: [message])
    }

    func updateLastMessageIfNewer(_ message: MessageModel, in conversation: ConversationModel) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let record = self.record(for: conversation) else { return }
        if let lastMessage = record.lastMessage, lastMessage.receivedDate >= message.receivedDate {
            return
        }
        record.lastMessage = message
    }

    func clearMessages(of conversation: ConversationModel) {
        dispatchPrecondition(condition: .onQueue(queue))
        self.record(for: conversation)?.clearMessages()
    }

    func setAllMessagesAsRead(in conversation: ConversationModel) {
        dispatchPrecondition(condition: .onQueue(queue))
        self.record(for: conversation)?.setAllMessagesAsRead()
    }

    // MARK: file transfer

    func transferStatusChanged(_ transferStatus: DataTransferStatus,
                               for transferId: String,
                               conversationId: String,
                               interactionId: String,
                               accountId: String,
                               to jamiId: String) {
        dispatchPrecondition(condition: .onQueue(queue))
        var conversationUnwraped: ConversationModel?
        if !conversationId.isEmpty {
            conversationUnwraped = self.getConversationForId(conversationId: conversationId, accountId: accountId)
        } else {
            conversationUnwraped = self.getConversationForParticipant(jamiId: jamiId, accountId: accountId)
        }
        guard let conversation = conversationUnwraped else { return }
        self.record(for: conversation)?.transferStatusUpdated(status: transferStatus, messageId: interactionId,
                                                              transferId: transferId)
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

    // MARK: ordering

    /**
     after adding new interactions for conversation we check if conversation order need to be changed
     */
    func sortIfNeeded() {
        dispatchPrecondition(condition: .onQueue(queue))
        let receivedDates = self.conversations.value.map({ conv in
            return self.record(for: conv)?.lastMessage?.receivedDate ?? Date()
        })
        if !receivedDates.isDescending() {
            var currentConversations = self.conversations.value
            self.sortAndUpdate(conversations: &currentConversations)
        }
    }

    private func scheduleSort() {
        queue.async { [weak self] in
            self?.sortIfNeeded()
        }
    }

    /**
     Sort conversations and emit updates for conversations
     */
    private func sortAndUpdate(conversations: inout [ConversationModel]) {
        /// sort conversaton by last message date
        let sorted = conversations.sorted(by: { conversation1, conversations2 in
            let record1 = self.record(for: conversation1)
            let record2 = self.record(for: conversations2)
            guard let lastMessage1 = record1?.lastMessage,
                  let lastMessage2 = record2?.lastMessage else {
                return (record1?.messages.count ?? 0) > (record2?.messages.count ?? 0)
            }
            return lastMessage1.receivedDate > lastMessage2.receivedDate
        })
        self.conversations.accept(sorted)
    }

    // MARK: helpers

    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ConversationModel]) {
        if let info = adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            var state = ConversationState(info: info)
            self.configure(&state, accountId: accountId, conversationId: conversationId, participantsInfo: participantsInfo, accountURI: accountURI)
            conversations.append(self.makeConversation(id: conversationId, accountId: accountId, state: state))
        }
    }

    private func configure(_ state: inout ConversationState, accountId: String, conversationId: String, participantsInfo: [[String: String]], accountURI: String) {
        if let prefsInfo = getConversationPreferences(accountId: accountId, conversationId: conversationId) {
            state.updatePreferences(preferences: prefsInfo)
        }
        state.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
        state.updateLastDisplayedMessage(participantsInfo: participantsInfo)
    }

    private func makeConversation(id: String, accountId: String, state: ConversationState) -> ConversationModel {
        if let record = self.existingRecord(id: id, accountId: accountId) {
            record.state.accept(state)
            return record.conversation
        }
        let relay = BehaviorRelay(value: state)
        let conversation = ConversationModel(id: id, accountId: accountId, state: relay)
        self.records[ObjectIdentifier(conversation)] = ConversationRecord(conversation: conversation, state: relay)
        return conversation
    }

    private func makeConversation(from stored: StoredConversation) -> ConversationModel {
        if let record = self.existingRecord(id: stored.id, accountId: stored.accountId) {
            record.reconcile(with: stored)
            return record.conversation
        }
        var state = ConversationState(type: stored.type)
        state.participants = [ConversationParticipant(jamiId: stored.participantUri.hash ?? "", isLocal: false)]
        state.hash = stored.participantUri.hash ?? ""
        let conversation = self.makeConversation(id: stored.id, accountId: stored.accountId, state: state)
        let record = self.record(for: conversation)
        record?.messages = stored.messages
        record?.lastMessage = stored.lastMessage
        return conversation
    }

    private func existingRecord(id: String, accountId: String) -> ConversationRecord? {
        return self.records.values.first { $0.conversation.id == id && $0.conversation.accountId == accountId }
    }

    private func record(for conversation: ConversationModel) -> ConversationRecord? {
        return self.records[ObjectIdentifier(conversation)]
    }

    private func removeUnpublishedRecords() {
        let published = Set(self.conversations.value.map { ObjectIdentifier($0) })
        self.records = self.records.filter { published.contains($0.key) }
    }

    private func update(_ conversation: ConversationModel, _ change: (inout ConversationState) -> Void) {
        guard let record = self.records[ObjectIdentifier(conversation)] else { return }
        var state = record.state.value
        change(&state)
        record.state.accept(state)
    }

    private func publishNewConversation(conversationId: String, accountId: String, conversations: inout [ConversationModel]) {
        self.sortAndUpdate(conversations: &conversations)

        if let conversation = conversations.first(where: { $0.id == conversationId }) {
            self.scheduleUnreadCount(for: conversation, accountId: accountId)
        }

        DispatchQueue.main.async {
            var data = [String: Any]()
            data[ConversationNotificationsKeys.conversationId.rawValue] = conversationId
            data[ConversationNotificationsKeys.accountId.rawValue] = accountId
            NotificationCenter.default.post(name: NSNotification.Name(ConversationNotifications.conversationReady.rawValue), object: nil, userInfo: data)
        }

        self.loadMessages(conversationId: conversationId, accountId: accountId, from: "", size: 2)
        self.scheduleSort()
        self.conversationReady.accept(conversationId)
    }

    private func loadLatestMessages(swarmIds: [String], accountId: String) {
        for swarmId in swarmIds {
            self.loadMessages(conversationId: swarmId, accountId: accountId, from: "", size: 1)
        }
    }

    private func scheduleUnreadCounts(for conversations: [ConversationModel], accountId: String) {
        for conversation in conversations where conversation.isSwarm() {
            self.scheduleUnreadCount(for: conversation, accountId: accountId)
        }
    }

    private func scheduleUnreadCount(for conversation: ConversationModel, accountId: String) {
        queue.async { [weak self] in
            self?.updateUnreadMessages(conversation: conversation, accountId: accountId)
        }
    }

    private func updateUnreadMessages(conversation: ConversationModel, accountId: String) {
        if let lastRead = conversation.getLastReadMessage(), let jamiId = conversation.getLocalParticipants()?.jamiId {
            let unreadInteractions = self.adapter.countInteractions(accountId, conversationId: conversation.id, from: lastRead, to: "", authorUri: jamiId)
            conversation.numberOfUnreadMessages.accept(Int(unreadInteractions))
        }
    }

    func loadMessages(conversationId: String, accountId: String, from: String, size: Int = 40) {
        DispatchQueue.global(qos: .background).async {
            self.adapter.loadConversationMessages(accountId, conversationId: conversationId, from: from, size: size)
        }
    }

    func getConversationPreferences(accountId: String, conversationId: String) -> [String: String]? {
        return self.adapter.getConversationPreferences(forAccount: accountId, conversationId: conversationId) as? [String: String]
    }

    private func isTargetReply(messages: [MessageModel]) -> Bool {
        if let targetMessage = messages.first,
           messages.count == 1,
           self.replyTargets.isRequested(targetMessage.id) {
            return true
        }
        return false
    }

    private func processReplyTargetMessage(with message: MessageModel?) {
        guard let target = message else { return }
        self.replyTargets.resolve(target)
    }
}
// swiftlint:enable type_body_length
