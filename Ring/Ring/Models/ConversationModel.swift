/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

import Foundation
import RxSwift
import RxRelay

enum ConversationType: Int {
    case oneToOne = 0
    case adminInvitesOnly = 1
    case invitesOnly = 2
    case publicChat = 3
    case nonSwarm = 100
    case sip = 101

    init?(daemonMode: String) {
        guard let mode = Int(daemonMode) else { return nil }
        self.init(rawValue: mode)
    }

    var stringValue: String {
        switch self {
        case .oneToOne:
            return L10n.Swarm.oneToOne
        case .adminInvitesOnly:
            return L10n.Swarm.adminInvitesOnly
        case .invitesOnly:
            return L10n.Swarm.invitesOnly
        case .publicChat:
            return L10n.Swarm.publicChat
        default:
            return L10n.Swarm.others
        }
    }
}

enum ConversationMemberEvent: Int {
    case add
    case joins
    case leave
    case banned
}

enum FileTransferType: Int {
    case audio
    case video
    case image
    case gif
    case unknown
}
enum ConversationSchema: Int {
    case jami
    case swarm
}

enum ConversationAttributes: String {
    case title = "title"
    case description = "description"
    case avatar = "avatar"
    case mode = "mode"
    case conversationId = "id"
}

enum ConversationPreferenceAttributes: String {
    case color
    case ignoreNotifications
}

struct ConversationPreferences {
    var color: String = UIColor.defaultSwarmColorHex
    var ignoreNotifications: Bool = false

    mutating func update(info: [String: String]) {
        if let color = info[ConversationPreferenceAttributes.color.rawValue] {
            self.color = color
        }
        if let ignoreNotifications = info[ConversationPreferenceAttributes.ignoreNotifications.rawValue] {
            self.ignoreNotifications = (ignoreNotifications as NSString).boolValue
        }
    }

    func getColor() -> UIColor {
        return UIColor(hexString: color)!
    }
}

class ConversationParticipant: Equatable, Hashable {
    var jamiId: String = ""
    var role: ParticipantRole = .member
    var lastDisplayed: String = ""
    var isLocal: Bool = false

    private static func stripUriPrefix(_ uri: String) -> String {
        return uri
            .replacingOccurrences(of: "ring:", with: "")
            .replacingOccurrences(of: "jami:", with: "")
    }

    init (info: [String: String], isLocal: Bool) {
        self.isLocal = isLocal
        if let jamiId = info["uri"], !jamiId.isEmpty {
            self.jamiId = Self.stripUriPrefix(jamiId)
        }
        if let role = info["role"],
           let memberRole = ParticipantRole(rawValue: role) {
            self.role = memberRole
        }
        if let lastRead = info["lastDisplayed"] {
            self.lastDisplayed = lastRead
        }
    }

    init (jamiId: String) {
        self.jamiId = Self.stripUriPrefix(jamiId)
    }

    init (jamiId: String, isLocal: Bool) {
        self.jamiId = Self.stripUriPrefix(jamiId)
        self.isLocal = isLocal
    }

    static func == (lhs: ConversationParticipant, rhs: ConversationParticipant) -> Bool {
        return lhs.jamiId == rhs.jamiId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jamiId)
    }
}

struct LoadedMessages {
    var messages: [MessageModel]
    var fromHistory: Bool
    var reset = false
}

class ConversationModel: Equatable {
    var newMessages = BehaviorRelay<LoadedMessages>(value: LoadedMessages(messages: [MessageModel](), fromHistory: false))
    private var participants = [ConversationParticipant]()
    var messages = [MessageModel]()
    var hash = ""/// contact hash for dialog, conversation title for multiparticipants
    var accountId: String = ""
    var id: String = ""
    var lastMessage: MessageModel?
    private var type: ConversationType
    let numberOfUnreadMessages = BehaviorRelay<Int>(value: 0)
    let disposeBag = DisposeBag()
    var avatar: String = ""
    var title: String = ""
    var description: String = ""
    var preferences = ConversationPreferences()
    var synchronizing = BehaviorRelay<Bool>(value: false)
    let reactionsUpdated = PublishSubject<MessageModel>()
    let messagesUpdated = PublishSubject<[MessageModel]>()

    init(type: ConversationType) {
        self.type = type
    }

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String, type: ConversationType, isLocal: Bool = false) {
        self.init(type: type)
        self.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "", isLocal: isLocal)]
        self.hash = participantUri.hash ?? ""
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (withParticipantUri participantUri: JamiURI, accountId: String, hash: String, type: ConversationType) {
        self.init(type: type)
        self.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = hash
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (withId conversationId: String, accountId: String, type: ConversationType) {
        self.init(type: type)
        self.id = conversationId
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (request: RequestModel) {
        self.init(type: request.conversationType)
        self.id = request.conversationId
        self.accountId = request.accountId
        self.participants = request.participants
        self.avatar = request.avatar?.base64EncodedString() ?? ""
        self.title = request.name
        self.subscribeUnreadMessages()
    }

    convenience init (withId conversationId: String, accountId: String, info: [String: String]) {
        self.init(type: ConversationModel.parseType(from: info))
        self.id = conversationId
        self.accountId = accountId
        self.updateInfo(info: info)
        updateProfile(profile: info)
        self.subscribeUnreadMessages()
    }

    static func parseType(from info: [String: String]) -> ConversationType {
        if let mode = info[ConversationAttributes.mode.rawValue],
           let type = ConversationType(daemonMode: mode) {
            return type
        }
        // Swarm conversations default to invitesOnly when mode is missing
        return .invitesOnly
    }

    func addParticipant(jamiId: String) {
        let participant = ConversationParticipant(jamiId: jamiId)
        participant.isLocal = false
        self.participants.append(participant)
    }

    func updateInfo(info: [String: String]) {
        if let syncing = info["syncing"], syncing == "true" {
            self.synchronizing.accept(true)
        } else if info[ConversationAttributes.mode.rawValue] == nil {
            self.synchronizing.accept(true)
        } else {
            self.synchronizing.accept(false)
        }
        if let hash = info[ConversationAttributes.title.rawValue], !hash.isEmpty {
            self.hash = hash
        }
        updateProfile(profile: info)
        if let type = info[ConversationAttributes.mode.rawValue],
           let conversationType = ConversationType(daemonMode: type) {
            self.type = conversationType
        }
    }

    func updateProfile(profile: [String: String]) {
        if let avatar = profile[ConversationAttributes.avatar.rawValue] {
            self.avatar = avatar
        }
        if let title = profile[ConversationAttributes.title.rawValue] {
            self.title = title
        }
        if let description = profile[ConversationAttributes.description.rawValue] {
            self.description = description
        }
    }

    func updatePreferences(preferences: [String: String]) {
        self.preferences.update(info: preferences)
    }

    static func == (lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        if lhs.type != rhs.type { return false }
        /*
         Swarm conversations must have an unique id, unless it temporary oneToOne
         conversation. For non swarm conversations and for temporary swarm
         conversations check participant and accountId.
         */
        if !lhs.isSwarm() && !rhs.isSwarm() || lhs.id.isEmpty || rhs.id.isEmpty {
            if let rParticipant = rhs.getParticipants().first, let lParticipant = lhs.getParticipants().first {
                return (lParticipant == rParticipant && lhs.accountId == rhs.accountId)
            }
            return false
        }
        return lhs.id == rhs.id
    }

    private func subscribeUnreadMessages() {
        if self.isSwarm() { return }
        self.newMessages.asObservable()
            .share()
            .subscribe { [weak self] _ in
                guard let self = self else { return }
                let number = self.messages.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
                self.numberOfUnreadMessages.accept(number)
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    func getMessage(withDaemonID daemonID: String) -> MessageModel? {
        return self.messages.filter({ message in
            return message.daemonId == daemonID
        }).first
    }

    func getMessage(messageId: String) -> MessageModel? {
        return self.messages.filter({ message in
            return message.id == messageId
        }).first
    }

    func getLastReadMessage() -> String? {
        return self.participants.filter { participant in
            participant.isLocal
        }.first?.lastDisplayed
    }

    func getLastDisplayedMessageForDialog() -> String? {
        let last = self.participants.filter { participant in
            !participant.isLocal
        }.first?.lastDisplayed
        if let message = self.messages.filter({ ($0.id == last) }).first {
            if !message.incoming {
                return last
            } else if let index = self.messages.firstIndex(where: { message in
                message.id == last
            }) {
                if let newMessage = self.messages[0..<index].reversed().filter({ !$0.incoming }).first {
                    return newMessage.id
                }
            }
        }
        return last
    }

    func addParticipantsFromArray(participantsInfo: [[String: String]], accountURI: String) {
        self.participants = [ConversationParticipant]()
        participantsInfo.forEach { participantInfo in
            guard let uri = participantInfo["uri"], !uri.isEmpty else { return }
            let isLocal = uri.replacingOccurrences(of: "ring:", with: "") == accountURI.replacingOccurrences(of: "ring:", with: "")
            let participant = ConversationParticipant(info: participantInfo, isLocal: isLocal)
            self.participants.append(participant)
        }
    }

    func setAllMessagesAsRead() {
        var updated = [MessageModel]()
        for index in self.messages.indices where self.messages[index].status != .displayed &&
            self.messages[index].incoming && self.messages[index].type == .text {
            updated.append(self.updateMessage(at: index, { $0.status = .displayed }))
        }
        if !updated.isEmpty {
            messagesUpdated.onNext(updated)
        }
        self.numberOfUnreadMessages.accept(0)
    }

    func updateLastDisplayedMessage(participantsInfo: [[String: String]]) {
        self.participants.forEach { participant in
            participantsInfo.forEach { info in
                guard let jamiId = info["uri"],
                      let lastDisplayed = info["lastDisplayed"],
                      jamiId == participant.jamiId else { return }
                participant.lastDisplayed = lastDisplayed
            }
        }
    }

    func isCoredialog() -> Bool {
        if self.participants.count > 2 { return false }
        return self.type == .nonSwarm || self.type == .oneToOne || self.type == .sip
    }

    func isCoreDialogMatch(conversation: ConversationModel) -> Bool {
        return self.isCoredialog() &&
            conversation.isCoredialog() &&
            self.getParticipants().first == conversation.getParticipants().first
    }

    func getParticipants() -> [ConversationParticipant] {
        return self.participants.filter { participant in
            !participant.isLocal
        }
    }

    func getAllLocalParticipants() -> [ConversationParticipant] {
        return self.participants.filter { participant in
            participant.isLocal
        }
    }

    func getAllParticipants() -> [ConversationParticipant] {
        return self.participants
    }

    func getLocalParticipants() -> ConversationParticipant? {
        return self.participants.filter { participant in
            participant.isLocal
        }.first
    }

    func isDialog() -> Bool {
        return self.participants.count <= 2
    }

    func isOnlyLocalParticipant() -> Bool {
        return self.participants.filter { participant in
            !participant.isLocal
        }.isEmpty
    }

    func containsParticipant(participant: String) -> Bool {
        return self.getParticipants()
            .map { participant in
                return participant.jamiId
            }
            .contains(participant)
    }

    func getConversationURI() -> String? {
        if self.type == .nonSwarm {
            guard let jamiId = self.getParticipants().first?.jamiId else { return nil }
            return "jami:" + jamiId
        }
        return "swarm:" + self.id
    }

    func allMessagesLoaded() -> Bool {
        guard let firstMessage = self.messages.first else { return false }
        return firstMessage.parentId.isEmpty
    }

    func appendNonSwarm(message: MessageModel) {
        self.messages.append(message)
        self.newMessages.accept(LoadedMessages(messages: [message], fromHistory: false))
    }

    func isSwarm() -> Bool {
        return self.type != .nonSwarm && self.type != .sip
    }

    func isSip() -> Bool {
        return self.type == .sip
    }

    func clearMessages() {
        messages = [MessageModel]()
        newMessages.accept(LoadedMessages(messages: [MessageModel](), fromHistory: false, reset: true))
        lastMessage = nil
        numberOfUnreadMessages.accept(0)
    }

    func reactionAdded(messageId: String, reaction: [String: String]) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.reactionAdded(reaction: reaction)
        }) else { return }
        reactionsUpdated.onNext(message)
    }

    func reactionRemoved(messageId: String, reactionId: String) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.reactionRemoved(reactionId: reactionId)
        }) else { return }
        reactionsUpdated.onNext(message)
    }

    func messageUpdated(swarmMessage: SwarmMessageWrap, localJamiId: String) {
        guard let message = self.updateMessage(messageId: swarmMessage.id, {
            $0.messageUpdated(message: swarmMessage, localJamiId: localJamiId)
        }) else { return }
        messagesUpdated.onNext([message])
    }

    func messageStatusUpdated(status: MessageStatus, messageId: String, jamiId: String) {
        guard let message = self.updateMessage(messageId: messageId, {
            $0.messageStatusUpdated(status: status, jamiId: jamiId)
        }) else { return }
        messagesUpdated.onNext([message])
    }

    func transferStatusUpdated(status: DataTransferStatus, messageId: String, transferId: String) {
        guard let index = self.messages.firstIndex(where: { message in
            (!messageId.isEmpty && message.id == messageId) ||
                (message.type == .fileTransfer && message.daemonId == transferId)
        }) else { return }
        messagesUpdated.onNext([self.updateMessage(at: index, { $0.transferStatus = status })])
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

    func updateUnreadMessages(count: Int) {
        var unreadMessages = numberOfUnreadMessages.value
        unreadMessages += count
        numberOfUnreadMessages.accept(unreadMessages)
    }
}
