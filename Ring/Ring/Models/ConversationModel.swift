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

enum ParticipantRole: Int {
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
        if let ignoreNotifications = info[ConversationPreferenceAttributes.ignoreNotifications.rawValue] {
            self.ignoreNotifications = (ignoreNotifications as NSString).boolValue
        }
    }
}

class ConversationParticipant: Equatable, Hashable {
    var jamiId: String = ""
    var role: ParticipantRole = .member
    var lastDisplayed: String = ""
    var isLocal: Bool = false

    init (info: [String: String], isLocal: Bool) {
        self.isLocal = isLocal
        if let jamiId = info["uri"], !jamiId.isEmpty {
            self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
        }
        if let role = info["role"],
           let typeInt = Int(role),
           let memberRole = ParticipantRole(rawValue: typeInt) {
            self.role = memberRole
        }
        if let lastRead = info["lastDisplayed"] {
            self.lastDisplayed = lastRead
        }
    }

    init (jamiId: String) {
        self.jamiId = jamiId.replacingOccurrences(of: "ring:", with: "")
    }

    static func == (lhs: ConversationParticipant, rhs: ConversationParticipant) -> Bool {
        return lhs.jamiId == rhs.jamiId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(jamiId)
    }
}

class ConversationModel: Equatable {
    var newMessages = BehaviorRelay<[MessageModel]>(value: [MessageModel]())
    private var participants = [ConversationParticipant]()
    var messages = [MessageModel]()
    var hash = ""/// contact hash for dialog, conversation title for multiparticipants
    var accountId: String = ""
    var id: String = ""
    var lastMessage: MessageModel?
    var type: ConversationType = .nonSwarm
    var needsSyncing = false
    var unorderedInteractions = [String]()/// array ofr interaction id with child not currently present in messages
    let numberOfUnreadMessages = BehaviorRelay<Int>(value: 0)
    let disposeBag = DisposeBag()
    var avatar: String = ""
    var title: String = ""
    var description: String = ""
    var preferences = ConversationPreferences()

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String) {
        self.init()
        self.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = participantUri.hash ?? ""
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (withParticipantUri participantUri: JamiURI, accountId: String, hash: String) {
        self.init()
        self.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        self.hash = hash
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (withId conversationId: String, accountId: String) {
        self.init()
        self.id = conversationId
        self.accountId = accountId
        self.subscribeUnreadMessages()
    }

    convenience init (request: RequestModel) {
        self.init()
        self.id = request.conversationId
        self.accountId = request.accountId
        self.participants = request.participants
        self.type = request.conversationType
        self.avatar = request.avatar?.base64EncodedString() ?? ""
        self.title = request.name
        self.subscribeUnreadMessages()
    }

    convenience init (withId conversationId: String, accountId: String, info: [String: String]) {
        self.init()
        self.id = conversationId
        self.accountId = accountId
        if let hash = info[ConversationAttributes.title.rawValue], !hash.isEmpty {
            self.hash = hash
        }
        if let type = info[ConversationAttributes.mode.rawValue],
           let typeInt = Int(type),
           let conversationType = ConversationType(rawValue: typeInt) {
            self.type = conversationType
        }
        updateProfile(profile: info)
        self.subscribeUnreadMessages()
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
        if !lhs.isSwarm() && !rhs.isSwarm() || lhs.id.isEmpty || rhs.id.isEmpty {
            if let rParticipant = rhs.participants.first, let lParticipant = lhs.participants.first {
                return (lParticipant == rParticipant && lhs.accountId == rhs.accountId && lhs.participants.count == rhs.participants.count)
            }
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

    func setMessageAsRead(messageId: String, daemonId: String) {
        if let message = self.messages.filter({ messageModel in
            messageModel.id == messageId && messageModel.daemonId == daemonId
        }).first {
            message.status = .displayed
        }
        if !self.isSwarm() {
            let number = self.messages.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
            self.numberOfUnreadMessages.accept(number)
        }
    }

    func setAllMessagesAsRead() {
        let unreadMessages = self.messages.filter({ messages in
            return messages.status != .displayed && messages.incoming && messages.type == .text
        })
        unreadMessages.forEach { message in
            message.status = .displayed
        }
        if !self.isSwarm() {
            let number = self.messages.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
            self.numberOfUnreadMessages.accept(number)
        }
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
        return self.type == .nonSwarm || self.type == .oneToOne || self.type == .sip || self.type == .jams
    }

    func getParticipants() -> [ConversationParticipant] {
        return self.participants.filter { participant in
            !participant.isLocal
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
        return self.participants.filter { participant in
            !participant.isLocal
        }.count == 1
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
    }

    func isSwarm() -> Bool {
        return self.type != .nonSwarm && self.type != .sip && self.type != .jams
    }

    func clearMessages() {
        messages = [MessageModel]()
        newMessages.accept([MessageModel]())
        lastMessage = nil
        unorderedInteractions = [String]()
        numberOfUnreadMessages.accept(0)
    }

    func isCoreDilaog(for jamiId: String) -> Bool {
        return self.isCoredialog() && self.getParticipants().first?.jamiId == jamiId
    }
}
