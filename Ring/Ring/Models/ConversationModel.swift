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
import RxRelay
import RxSwift

enum ConversationType: Int {
    case oneToOne
    case adminInvitesOnly
    case invitesOnly
    case publicChat
    case nonSwarm
    case sip
    case jams

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
    case title
    case description
    case avatar
    case mode
    case conversationId = "id"
}

enum ConversationPreferenceAttributes: String {
    case color
    case ignoreNotifications
}

enum ParticipantRole: String {
    case invited
    case admin
    case member
    case banned
    case unknown

    var stringValue: String {
        switch self {
        case .member:
            return L10n.Swarm.member
        case .invited:
            return L10n.Swarm.invited
        case .admin:
            return L10n.Swarm.admin
        case .banned:
            return L10n.Swarm.banned
        case .unknown:
            return L10n.Swarm.unknown
        }
    }
}

struct ConversationPreferences {
    var color: String = UIColor.defaultSwarm
    var ignoreNotifications: Bool = false

    mutating func update(info: [String: String]) {
        if let color = info[ConversationPreferenceAttributes.color.rawValue] {
            self.color = color
        }
        if let ignoreNotifications =
            info[ConversationPreferenceAttributes.ignoreNotifications.rawValue] {
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

    init(info: [String: String], isLocal: Bool) {
        self.isLocal = isLocal
        if let jamiId = info["uri"], !jamiId.isEmpty {
            self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
        }
        if let role = info["role"],
           let memberRole = ParticipantRole(rawValue: role) {
            self.role = memberRole
        }
        if let lastRead = info["lastDisplayed"] {
            lastDisplayed = lastRead
        }
    }

    init(jamiId: String) {
        self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
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
}

class ConversationModel: Equatable {
    var newMessages = BehaviorRelay<LoadedMessages>(value: LoadedMessages(
        messages: [MessageModel](),
        fromHistory: false
    ))
    private var participants = [ConversationParticipant]()
    var messages = [MessageModel]()
    var hash = "" /// contact hash for dialog, conversation title for multiparticipants
    var accountId: String = ""
    var id: String = ""
    var lastMessage: MessageModel?
    var type: ConversationType = .nonSwarm
    let numberOfUnreadMessages = BehaviorRelay<Int>(value: 0)
    let disposeBag = DisposeBag()
    var avatar: String = ""
    var title: String = ""
    var description: String = ""
    var preferences = ConversationPreferences()
    var synchronizing = BehaviorRelay<Bool>(value: false)
    let reactionsUpdated = PublishSubject<String>()
    let messageUpdated = PublishSubject<String>()

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String) {
        self.init()
        participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        hash = participantUri.hash ?? ""
        self.accountId = accountId
        subscribeUnreadMessages()
    }

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String, hash: String) {
        self.init()
        participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = hash
        self.accountId = accountId
        subscribeUnreadMessages()
    }

    convenience init(withId conversationId: String, accountId: String) {
        self.init()
        id = conversationId
        self.accountId = accountId
        subscribeUnreadMessages()
    }

    convenience init(request: RequestModel) {
        self.init()
        id = request.conversationId
        accountId = request.accountId
        participants = request.participants
        type = request.conversationType
        avatar = request.avatar?.base64EncodedString() ?? ""
        title = request.name
        subscribeUnreadMessages()
    }

    convenience init(withId conversationId: String, accountId: String, info: [String: String]) {
        self.init()
        id = conversationId
        self.accountId = accountId
        updateInfo(info: info)
        updateProfile(profile: info)
        subscribeUnreadMessages()
    }

    func updateInfo(info: [String: String]) {
        if let syncing = info["syncing"], syncing == "true" {
            synchronizing.accept(true)
        } else {
            synchronizing.accept(false)
        }
        if let hash = info[ConversationAttributes.title.rawValue], !hash.isEmpty {
            self.hash = hash
        }
        updateProfile(profile: info)
        if let type = info[ConversationAttributes.mode.rawValue],
           let typeInt = Int(type),
           let conversationType = ConversationType(rawValue: typeInt) {
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
            if let rParticipant = rhs.getParticipants().first,
               let lParticipant = lhs.getParticipants().first {
                return lParticipant == rParticipant && lhs.accountId == rhs.accountId
            }
            return false
        }
        return lhs.id == rhs.id
    }

    private func subscribeUnreadMessages() {
        if isSwarm() { return }
        newMessages.asObservable()
            .share()
            .subscribe { [weak self] _ in
                guard let self = self else { return }
                let number = self.messages
                    .filter { $0.status != .displayed && $0.type == .text && $0.incoming }.count
                self.numberOfUnreadMessages.accept(number)
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    func getMessage(withDaemonID daemonID: String) -> MessageModel? {
        return messages.filter { message in
            message.daemonId == daemonID
        }.first
    }

    func getMessage(messageId: String) -> MessageModel? {
        return messages.filter { message in
            message.id == messageId
        }.first
    }

    func getLastReadMessage() -> String? {
        return participants.filter { participant in
            participant.isLocal
        }.first?.lastDisplayed
    }

    func getLastDisplayedMessageForDialog() -> String? {
        let last = participants.filter { participant in
            !participant.isLocal
        }.first?.lastDisplayed
        if let message = messages.filter({ $0.id == last }).first {
            if !message.incoming {
                return last
            } else if let index = messages.firstIndex(where: { message in
                message.id == last
            }) {
                if let newMessage = messages[0 ..< index].reversed().filter({ !$0.incoming })
                    .first {
                    return newMessage.id
                }
            }
        }
        return last
    }

    func addParticipantsFromArray(participantsInfo: [[String: String]], accountURI: String) {
        participants = [ConversationParticipant]()
        participantsInfo.forEach { participantInfo in
            guard let uri = participantInfo["uri"], !uri.isEmpty else { return }
            let isLocal = uri.replacingOccurrences(of: "ring:", with: "") == accountURI
                .replacingOccurrences(of: "ring:", with: "")
            let participant = ConversationParticipant(info: participantInfo, isLocal: isLocal)
            self.participants.append(participant)
        }
    }

    func setMessageAsRead(messageId: String, daemonId: String) {
        if let message = messages.filter({ messageModel in
            messageModel.id == messageId && messageModel.daemonId == daemonId
        }).first {
            message.status = .displayed
        }
        if !isSwarm() {
            let number = messages
                .filter { $0.status != .displayed && $0.type == .text && $0.incoming }.count
            numberOfUnreadMessages.accept(number)
        }
    }

    func setAllMessagesAsRead() {
        let unreadMessages = messages.filter { messages in
            messages.status != .displayed && messages.incoming && messages.type == .text
        }
        for message in unreadMessages {
            message.status = .displayed
        }
        numberOfUnreadMessages.accept(0)
    }

    func updateLastDisplayedMessage(participantsInfo: [[String: String]]) {
        for participant in participants {
            participantsInfo.forEach { info in
                guard let jamiId = info["uri"],
                      let lastDisplayed = info["lastDisplayed"],
                      jamiId == participant.jamiId else { return }
                participant.lastDisplayed = lastDisplayed
            }
        }
    }

    func isCoredialog() -> Bool {
        if participants.count > 2 { return false }
        return type == .nonSwarm || type == .oneToOne || type == .sip || type == .jams
    }

    func getParticipants() -> [ConversationParticipant] {
        return participants.filter { participant in
            !participant.isLocal
        }
    }

    func getAllParticipants() -> [ConversationParticipant] {
        return participants
    }

    func getLocalParticipants() -> ConversationParticipant? {
        return participants.filter { participant in
            participant.isLocal
        }.first
    }

    func isDialog() -> Bool {
        return participants.filter { participant in
            !participant.isLocal
        }.count == 1
    }

    func containsParticipant(participant: String) -> Bool {
        return getParticipants()
            .map { participant in
                participant.jamiId
            }
            .contains(participant)
    }

    func getConversationURI() -> String? {
        if type == .nonSwarm {
            guard let jamiId = getParticipants().first?.jamiId else { return nil }
            return "jami:" + jamiId
        }
        return "swarm:" + id
    }

    func allMessagesLoaded() -> Bool {
        guard let firstMessage = messages.first else { return false }
        return firstMessage.parentId.isEmpty
    }

    func appendNonSwarm(message: MessageModel) {
        messages.append(message)
        newMessages.accept(LoadedMessages(messages: [message], fromHistory: false))
    }

    func isSwarm() -> Bool {
        return type != .nonSwarm && type != .sip && type != .jams
    }

    func clearMessages() {
        messages = [MessageModel]()
        newMessages.accept(LoadedMessages(messages: [MessageModel](), fromHistory: false))
        lastMessage = nil
        numberOfUnreadMessages.accept(0)
    }

    func reactionAdded(messageId: String, reaction: [String: String]) {
        guard let message = getMessage(messageId: messageId) else { return }
        message.reactionAdded(reaction: reaction)
        reactionsUpdated.onNext(messageId)
    }

    func reactionRemoved(messageId: String, reactionId: String) {
        guard let message = getMessage(messageId: messageId) else { return }
        message.reactionRemoved(reactionId: reactionId)
        reactionsUpdated.onNext(messageId)
    }

    func messageUpdated(swarmMessage: SwarmMessageWrap, localJamiId: String) {
        guard let message = getMessage(messageId: swarmMessage.id) else { return }
        message.messageUpdated(message: swarmMessage, localJamiId: localJamiId)
        messageUpdated.onNext(swarmMessage.id)
    }

    func messageStatusUpdated(status: MessageStatus, messageId: String, jamiId: String) {
        guard let message = getMessage(messageId: messageId) else { return }
        message.messageStatusUpdated(status: status, messageId: messageId, jamiId: jamiId)
        messageUpdated.onNext(messageId)
    }

    func updateUnreadMessages(count: Int) {
        var unreadMessages = numberOfUnreadMessages.value
        unreadMessages += count
        numberOfUnreadMessages.accept(unreadMessages)
    }
}
