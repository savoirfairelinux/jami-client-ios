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

struct ConversationParticipant: Equatable, Hashable {
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

struct ConversationState {
    var type: ConversationType
    /// contact hash for dialog, conversation title for multiparticipants
    var hash = ""
    var avatar = ""
    var title = ""
    var description = ""
    var preferences = ConversationPreferences()
    var participants = [ConversationParticipant]()
    var isSynchronizing = false

    init(type: ConversationType) {
        self.type = type
    }

    init(info: [String: String]) {
        self.init(type: ConversationState.parseType(from: info))
        self.updateInfo(info: info)
    }

    static func parseType(from info: [String: String]) -> ConversationType {
        if let mode = info[ConversationAttributes.mode.rawValue],
           let type = ConversationType(daemonMode: mode) {
            return type
        }
        // Swarm conversations default to invitesOnly when mode is missing
        return .invitesOnly
    }

    mutating func addParticipant(jamiId: String) {
        self.participants.append(ConversationParticipant(jamiId: jamiId, isLocal: false))
    }

    mutating func updateInfo(info: [String: String]) {
        if let syncing = info["syncing"], syncing == "true" {
            self.isSynchronizing = true
        } else if info[ConversationAttributes.mode.rawValue] == nil {
            self.isSynchronizing = true
        } else {
            self.isSynchronizing = false
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

    mutating func updateProfile(profile: [String: String]) {
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

    mutating func updatePreferences(preferences: [String: String]) {
        self.preferences.update(info: preferences)
    }

    mutating func addParticipantsFromArray(participantsInfo: [[String: String]], accountURI: String) {
        self.participants = [ConversationParticipant]()
        participantsInfo.forEach { participantInfo in
            guard let uri = participantInfo["uri"], !uri.isEmpty else { return }
            let isLocal = uri.replacingOccurrences(of: "ring:", with: "") == accountURI.replacingOccurrences(of: "ring:", with: "")
            let participant = ConversationParticipant(info: participantInfo, isLocal: isLocal)
            self.participants.append(participant)
        }
    }

    mutating func updateLastDisplayedMessage(participantsInfo: [[String: String]]) {
        for index in self.participants.indices {
            for info in participantsInfo {
                guard let jamiId = info["uri"],
                      let lastDisplayed = info["lastDisplayed"],
                      jamiId == self.participants[index].jamiId else { continue }
                self.participants[index].lastDisplayed = lastDisplayed
            }
        }
    }
}

final class ConversationStreams {
    let state: BehaviorRelay<ConversationState>
    let newMessages = BehaviorRelay<LoadedMessages>(value: LoadedMessages(messages: [MessageModel](), fromHistory: false))
    let messagesUpdated = PublishSubject<[MessageModel]>()
    let reactionsUpdated = PublishSubject<MessageModel>()
    let unreadMessages = BehaviorRelay<Int>(value: 0)

    init(state: ConversationState) {
        self.state = BehaviorRelay(value: state)
    }
}

class ConversationModel: Equatable {
    let id: String
    let accountId: String
    private let streams: ConversationStreams

    var state: ConversationState {
        return streams.state.value
    }

    var stateChanges: Observable<ConversationState> {
        return streams.state.asObservable()
    }

    var newMessages: Observable<LoadedMessages> {
        return streams.newMessages.asObservable()
    }

    var messagesUpdated: Observable<[MessageModel]> {
        return streams.messagesUpdated.asObservable()
    }

    var reactionsUpdated: Observable<MessageModel> {
        return streams.reactionsUpdated.asObservable()
    }

    var numberOfUnreadMessages: Observable<Int> {
        return streams.unreadMessages.asObservable()
    }

    var unreadMessagesCount: Int {
        return streams.unreadMessages.value
    }

    var hash: String {
        return state.hash
    }

    var avatar: String {
        return state.avatar
    }

    var title: String {
        return state.title
    }

    var description: String {
        return state.description
    }

    var preferences: ConversationPreferences {
        return state.preferences
    }

    var isSynchronizing: Bool {
        return state.isSynchronizing
    }

    var synchronizing: Observable<Bool> {
        return streams.state.map { $0.isSynchronizing }.distinctUntilChanged()
    }

    private var type: ConversationType {
        return state.type
    }

    private var participants: [ConversationParticipant] {
        return state.participants
    }

    init(id: String, accountId: String, streams: ConversationStreams) {
        self.id = id
        self.accountId = accountId
        self.streams = streams
    }

    convenience init(id: String = "", accountId: String = "", state: ConversationState) {
        self.init(id: id, accountId: accountId, streams: ConversationStreams(state: state))
    }

    convenience init(type: ConversationType) {
        self.init(state: ConversationState(type: type))
    }

    convenience init(withParticipantUri participantUri: JamiURI, accountId: String, type: ConversationType, isLocal: Bool = false) {
        var state = ConversationState(type: type)
        state.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "", isLocal: isLocal)]
        state.hash = participantUri.hash ?? ""
        self.init(accountId: accountId, state: state)
    }

    convenience init (withParticipantUri participantUri: JamiURI, accountId: String, hash: String, type: ConversationType) {
        var state = ConversationState(type: type)
        state.participants = [ConversationParticipant(jamiId: participantUri.hash ?? "")]
        state.hash = hash
        self.init(accountId: accountId, state: state)
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

    func getLastReadMessage() -> String? {
        return self.participants.filter { participant in
            participant.isLocal
        }.first?.lastDisplayed
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

    func isSwarm() -> Bool {
        return self.type != .nonSwarm && self.type != .sip
    }

    func isSip() -> Bool {
        return self.type == .sip
    }

}
