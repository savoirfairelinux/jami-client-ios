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
//    case from = "from"
//    case received = "received"
}

enum ParticipantRole: Int {
    case invited
    case admin
    case member
    case banned
}

struct ConversationParticipant: Equatable {
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
}

class ConversationModel: Equatable {
    var messages = BehaviorRelay<[MessageModel]>(value: [MessageModel]())
    private var participants = [ConversationParticipant]()
    var hash = ""/// contact hash for dialog, conversation title for multiparticipants
    var accountId: String = ""
    var id: String = ""
    var lastDisplayedMessage: (id: String, timestamp: Date) = ("", Date())
    var type: ConversationType = .nonSwarm
    var needsSyncing = false
    var parentsId = [String: String]()/// dictionary of [parentId, interactionId] for interaction with parent not currently present in messages
    let numberOfUnreadMessages = BehaviorRelay<Int>(value: 0)
    let disposeBag = DisposeBag()

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
        self.subscribeUnreadMessages()
    }

    static func == (lhs: ConversationModel, rhs: ConversationModel) -> Bool {
        if !lhs.isSwarm() && !rhs.isSwarm() || lhs.id.isEmpty || rhs.id.isEmpty {
            return (lhs.participants[0] == rhs.participants[0] && lhs.accountId == rhs.accountId && lhs.participants.count == rhs.participants.count)
        }
        return lhs.id == rhs.id
    }

    private func subscribeUnreadMessages() {
        if self.isSwarm() { return }
        self.messages.asObservable()
            .subscribe { [weak self] messages in
                guard let self = self else { return }
                let number = messages.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
                self.numberOfUnreadMessages.accept(number)

            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    func getMessage(withDaemonID daemonID: String) -> MessageModel? {
        return self.messages.value.filter({ message in
           return message.daemonId == daemonID
        }).first
    }

    func getLastReadMessage() -> String? {
        return self.participants.filter { participant in
            participant.isLocal
        }.first?.lastDisplayed
    }

    func getLastDisplayedMessageForDialog() -> String? {
        return self.participants.filter { participant in
            !participant.isLocal
        }.first?.lastDisplayed
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
        if let message = self.messages.value.filter({ messageModel in
            messageModel.id == messageId && messageModel.daemonId == daemonId
        }).first {
            message.status = .displayed
        }
        if !self.isSwarm() {
            let number = self.messages.value.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
            self.numberOfUnreadMessages.accept(number)
        }
    }

    func setAllMessagesAsRead() {
        let unreadMessages = self.messages.value.filter({ messages in
            return messages.status != .displayed && messages.incoming && messages.type == .text
        })
        unreadMessages.forEach { message in
            message.status = .displayed
        }
        if !self.isSwarm() {
            let number = self.messages.value.filter({ $0.status != .displayed && $0.type == .text && $0.incoming }).count
            self.numberOfUnreadMessages.accept(number)
        }
    }

    func updateLastDisplayedMessage(participantsInfo: [[String: String]]) {
        guard let accountURI = self.participants.filter({ $0.isLocal }).first?.jamiId else { return }
        self.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
    }

    func isCoredialog() -> Bool {
        return self.type == .nonSwarm || self.type == .oneToOne || self.type != .sip || self.type != .jams
    }

    func getParticipants() -> [ConversationParticipant] {
        return self.participants.filter { participant in
            !participant.isLocal
        }
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
        guard let firstMessage = self.messages.value.first else { return false }
        return firstMessage.parentId.isEmpty
    }

    func appendNonSwarm(message: MessageModel) {
        var values = self.messages.value
        values.append(message)
        self.messages.accept(values)
    }

    func isSwarm() -> Bool {
        return self.type != .nonSwarm && self.type != .sip && self.type != .jams
    }

    func isLastDisplayed(messageId: String, peerJamiId: String) -> Bool {
        return messageId == self.lastDisplayedMessage.id
    }
}
