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

// swiftlint:disable type_body_length
final class ConversationState {

    private let conversations = BehaviorRelay(value: [ConversationModel]())
    private let conversationReady = BehaviorRelay(value: "")

    private let adapter: ConversationsAdapter
    private let dbManager: DBManager
    private let queue: DispatchQueue
    private let replyTargets: ReplyTargetRegistry
    private let responseStream: PublishSubject<ServiceEvent>
    private let typingStatus: ReplaySubject<ConversationsService.TypingStatus>
    private let disposeBag = DisposeBag()

    init(adapter: ConversationsAdapter,
         dbManager: DBManager,
         queue: DispatchQueue,
         replyTargets: ReplyTargetRegistry,
         responseStream: PublishSubject<ServiceEvent>,
         typingStatus: ReplaySubject<ConversationsService.TypingStatus>) {
        self.adapter = adapter
        self.dbManager = dbManager
        self.queue = queue
        self.replyTargets = replyTargets
        self.responseStream = responseStream
        self.typingStatus = typingStatus
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
        var currentConversations = [ConversationModel]()
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
            .subscribe(onNext: { [weak self] conversationsModels in
                self?.queue.async {
                    guard let self = self else { return }
                    let oneToOne = currentConversations.filter { conv in
                        conv.isCoredialog()
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
                    self.loadLatestMessages(swarmIds: conversationToLoad, accountId: accountId)
                    self.scheduleUnreadCounts(for: currentConversations, accountId: accountId)
                }
            }, onError: { [weak self] _ in
                self?.queue.async {
                    guard let self = self else { return }
                    self.conversations.accept(currentConversations)
                    self.loadLatestMessages(swarmIds: conversationToLoad, accountId: accountId)
                    self.scheduleUnreadCounts(for: currentConversations, accountId: accountId)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func clearConversationsData(accountId: String) {
        self.conversations.value.forEach { conversation in
            self.adapter.clearCashe(forConversationId: conversation.id, accountId: accountId)
        }
    }

    func addConversationFromAcceptedRequest(conversationId: String, accountId: String, accountURI: String, type: ConversationType) {
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil {
            return
        }

        guard let info = self.adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
              let participantsInfo = self.adapter.getConversationMembers(accountId, conversationId: conversationId) else {
            // Adapter data not ready yet; daemon's conversationReady will handle it later
            return
        }

        let conversation = ConversationModel(withId: conversationId, accountId: accountId, type: type)
        conversation.updateInfo(info: info)
        conversation.updateProfile(profile: info)
        self.configureConversation(conversation, accountId: accountId, conversationId: conversationId, participantsInfo: participantsInfo, accountURI: accountURI)

        var currentConversations = self.conversations.value
        currentConversations.append(conversation)
        self.publishNewConversation(conversationId: conversationId, accountId: accountId, conversations: &currentConversations)
    }

    func replaceConversations(_ conversations: [ConversationModel]) {
        self.conversations.accept(conversations)
    }

    func removeConversation(_ conversation: ConversationModel) {
        var values = self.conversations.value
        if let index = values.firstIndex(of: conversation) {
            values.remove(at: index)
            self.conversations.accept(values)
        }
    }

    func addSwarmConversationId(conversationId: String, accountId: String, jamiId: String) {
        if self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil { return }
        var conversations = self.conversations.value
        let conversation = ConversationModel(withId: conversationId, accountId: accountId, type: .oneToOne)
        conversation.addParticipant(jamiId: jamiId)
        conversations.append(conversation)
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
        guard let conversation = self.conversations.value
                .filter({ conversation in
                    return conversation.id == conversationId && conversation.accountId == accountId
                })
                .first else { return false }

        if self.isTargetReply(messages: messages) {
            self.processReplyTargetMessage(with: messages.first)
            return true
        }

        // If all the loaded messages are of type .merge or .profile or have already been added, we need to load the next set of messages.
        let filtered = messages.filter { newMessage in newMessage.type != .merge && newMessage.type != .profile && !conversation.messages.contains(where: { message in
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

        self.scheduleSort()

        if !fromLoaded {
            let incomingMessages = newMessages.filter({ $0.authorId != localJamiId && !$0.authorId.isEmpty })
            conversation.updateUnreadMessages(count: incomingMessages.count)
        }

        conversation.newMessages.accept(LoadedMessages(messages: newMessages, fromHistory: fromLoaded))
        return true
    }

    func conversationReady(conversationId: String, accountId: String, accountURI: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else {
            var currentConversations = self.conversations.value
            self.addSwarm(conversationId: conversationId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            self.publishNewConversation(conversationId: conversationId, accountId: accountId, conversations: &currentConversations)
            return
        }

        if let info = self.adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = self.adapter.getConversationMembers(accountId, conversationId: conversationId) {
            conversation.updateInfo(info: info)
            if let prefsInfo = self.getConversationPreferences(accountId: accountId, conversationId: conversationId) {
                conversation.updatePreferences(preferences: prefsInfo)
            }
            conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            self.scheduleUnreadCount(for: conversation, accountId: accountId)
            self.loadMessages(conversationId: conversationId, accountId: accountId, from: "", size: 2)
            self.scheduleSort()
        }

        self.conversationReady.accept(conversationId)
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

    func conversationMemberEvent(conversationId: String, accountId: String, accountURI: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId),
              let members = adapter.getConversationMembers(accountId, conversationId: conversationId) else { return }
        conversation.addParticipantsFromArray(participantsInfo: members, accountURI: accountURI)
        var serviceEvent = ServiceEvent(withEventType: .conversationMemberEvent)
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

    func composingStatusChanged(accountId: String, conversationId: String, from: String, status: Int) {
        guard self.getConversationForId(conversationId: conversationId, accountId: accountId) != nil else {
            return
        }

        let typingStatus = ConversationsService.TypingStatus(from: from, status: status, conversationId: conversationId)

        self.typingStatus.onNext(typingStatus)
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap, localJamiId: String) {
        guard let conversation = self.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        conversation.messageUpdated(swarmMessage: message, localJamiId: localJamiId)
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

    // MARK: file transfer

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

    // MARK: ordering

    /**
     after adding new interactions for conversation we check if conversation order need to be changed
     */
    func sortIfNeeded() {
        let receivedDates = self.conversations.value.map({ conv in
            return conv.lastMessage?.receivedDate ?? Date()
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
            guard let lastMessage1 = conversation1.lastMessage,
                  let lastMessage2 = conversations2.lastMessage else {
                return conversation1.messages.count > conversations2.messages.count
            }
            return lastMessage1.receivedDate > lastMessage2.receivedDate
        })
        self.conversations.accept(sorted)
    }

    // MARK: helpers

    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ConversationModel]) {
        if let info = adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            let conversation = ConversationModel(withId: conversationId, accountId: accountId, info: info)
            self.configureConversation(conversation, accountId: accountId, conversationId: conversationId, participantsInfo: participantsInfo, accountURI: accountURI)
            conversations.append(conversation)
        }
    }

    private func configureConversation(_ conversation: ConversationModel, accountId: String, conversationId: String, participantsInfo: [[String: String]], accountURI: String) {
        if let prefsInfo = getConversationPreferences(accountId: accountId, conversationId: conversationId) {
            conversation.updatePreferences(preferences: prefsInfo)
        }
        conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
        conversation.updateLastDisplayedMessage(participantsInfo: participantsInfo)
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

    private func loadMessages(conversationId: String, accountId: String, from: String, size: Int = 40) {
        DispatchQueue.global(qos: .background).async {
            self.adapter.loadConversationMessages(accountId, conversationId: conversationId, from: from, size: size)
        }
    }

    private func getConversationPreferences(accountId: String, conversationId: String) -> [String: String]? {
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
