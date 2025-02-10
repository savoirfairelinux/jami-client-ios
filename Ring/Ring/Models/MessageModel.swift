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

enum MessageAttributes: String {
    case interactionId = "id"
    case type = "type"
    case invited = "invited"
    case fileId = "fileId"
    case displayName = "displayName"
    case body = "body"
    case author = "author"
    case uri = "uri"
    case timestamp = "timestamp"
    case parent = "linearizedParent"
    case action = "action"
    case duration = "duration"
    case reply = "reply-to"
    case react = "react-to"
    case totalSize = "totalSize"
}

enum MessageType: Equatable {
    case text
    case fileTransfer
    case contact(ContactAction)
    case call
    case merge
    case initial
    case profile

    var rawValue: String {
        switch self {
        case .text: return "text/plain"
        case .fileTransfer: return "application/data-transfer+json"
        case .contact: return "member"
        case .call: return "application/call-history+json"
        case .merge: return "merge"
        case .initial: return "initial"
        case .profile: return "application/update-profile"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "text/plain": self = .text
        case "application/data-transfer+json": self = .fileTransfer
        case "member": self = .contact(.add)
        case "application/call-history+json": self = .call
        case "merge": self = .merge
        case "initial": self = .initial
        case "application/update-profile": self = .profile
        default: return nil
        }
    }

    static func == (lhs: MessageType, rhs: MessageType) -> Bool {
        switch (lhs, rhs) {
        case (.text, .text),
             (.fileTransfer, .fileTransfer),
             (.call, .call),
             (.merge, .merge),
             (.initial, .initial),
             (.contact, .contact),
             (.profile, .profile):
            return true
        default:
            return false
        }
    }

    var isContact: Bool {
        if case .contact = self { return true }
        return false
    }

    func getInteractionString(name: String, isIncoming: Bool) -> String? {
        if case .contact(let action) = self {
            return action.getInteractionString(name: name, isIncomig: isIncoming)
        }
        return nil
    }
}

enum ContactAction: String {
    case add
    case remove
    case join
    case banned
    case unban

    func getInteractionString(name: String, isIncomig: Bool) -> String {
        switch self {
        case .add:
            return isIncomig ? L10n.GeneratedMessage.invitationReceived(name) :
                L10n.GeneratedMessage.contactAdded
        case .join:
            return isIncomig ? L10n.GeneratedMessage.invitationAccepted(name) : L10n.GeneratedMessage.youJoined
        case .remove:
            return L10n.GeneratedMessage.contactLeftConversation(name)
        case.banned:
            return L10n.GeneratedMessage.contactBlocked(name)
        case .unban:
            return L10n.GeneratedMessage.contactUnblocked(name)
        }
    }
}

class MessageAction: Identifiable, Equatable, Hashable {
    var id: String = ""
    var author: String = ""
    var content: String = ""

    init(withInfo info: [String: String]) {
        if let interactionId = info[MessageAttributes.interactionId.rawValue] {
            self.id = interactionId
        }
        if let content = info[MessageAttributes.body.rawValue] {
            self.content = content
        }

        if let author = info[MessageAttributes.author.rawValue] {
            self.author = author
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MessageAction, rhs: MessageAction) -> Bool {
        return lhs.id == rhs.id
    }
}

public class MessageModel {

    var id: String = ""
    /// daemonId for dht messages, file transfer id for datatransfer
    var daemonId: String = ""
    var receivedDate: Date = Date()
    /// message to display for text, call and contact message. File name for swarm data transfer. file name with identifier from photo library for non swarm file transfer
    var content: String = ""
    /// jamiId for sender. For outgoing message authorId is empty
    var authorId: String = ""
    var uri: String = ""
    var status: MessageStatus = .sending
    var transferStatus: DataTransferStatus = .unknown
    var incoming: Bool
    var parentId: String = ""
    var type: MessageType = .text
    var reply: String = ""
    var react: String = ""
    var totalSize: Int = 0
    var parents = [String]()
    var reactions = Set<MessageAction>()
    var editions = Set<MessageAction>()
    var statusForParticipant = [String: MessageStatus]()
    var accessibilityLabelValue: String = ""
    
    init(withId id: String, receivedDate: Date, content: String, authorURI: String, incoming: Bool) {
        self.daemonId = id
        self.receivedDate = receivedDate
        self.content = content
        self.authorId = authorURI
        self.incoming = incoming
    }

    convenience init (with swarmMessage: SwarmMessageWrap, localJamiId: String) {
        self.init(withInfo: swarmMessage.body, localJamiId: localJamiId)
        for reaction in swarmMessage.reactions {
            self.reactions.insert(MessageAction(withInfo: reaction))
        }
        for edition in swarmMessage.editions {
            self.editions.insert(MessageAction(withInfo: edition))
        }

        self.updateStatus(with: swarmMessage, localJamiId: localJamiId)
    }

    func updateStatus(with swarmMessage: SwarmMessageWrap, localJamiId: String) {
        let filteredStatus = swarmMessage.status.filter { $0.key != localJamiId }

        for (key, value) in filteredStatus {
            if let status = MessageStatus(rawValue: value.int32Value) {
                statusForParticipant[key] = status
                /*
                 The message status is set to 'displayed' if at least one participant
                 has seen the message, and it is set to 'sent' if at least one participant
                 has received the message.
                 */
                if status == .displayed {
                    self.status = .displayed
                } else if status == .sent && self.status != .displayed {
                    self.status = .sent
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    init(withInfo info: [String: String], localJamiId: String) {
        if let interactionId = info[MessageAttributes.interactionId.rawValue] {
            self.id = interactionId
        }
        if let author = info[MessageAttributes.author.rawValue], author != localJamiId {
            self.authorId = author
        }
        if let uri = info[MessageAttributes.uri.rawValue] {
            self.uri = uri
        }
        if let type = info[MessageAttributes.type.rawValue],
           let messageType = MessageType(rawValue: type) {
            self.type = messageType
        }
        if let content = info[MessageAttributes.body.rawValue], self.type == MessageType.text {
            self.content = content
        }
        if let reply = info[MessageAttributes.reply.rawValue] {
            self.reply = reply
        }
        if let react = info[MessageAttributes.react.rawValue] {
            self.react = react
        }
        incoming = self.uri.isEmpty ? !self.authorId.isEmpty : self.uri != localJamiId
        if let parent = info[MessageAttributes.parent.rawValue] {
            self.parentId = parent
        }
        if let parents = info["parents"]?.components(separatedBy: ",").filter({ parentId in
            !parentId.isEmpty
        }) {
            self.parents.append(contentsOf: parents)
        }
        if let totalSizeString = info[MessageAttributes.totalSize.rawValue],
           let totalSize = Int(totalSizeString) {
            self.totalSize = totalSize
        }
        if let timestamp = info[MessageAttributes.timestamp.rawValue],
           let timestampDouble = Double(timestamp) {
            let receivedDate = Date.init(timeIntervalSince1970: timestampDouble)
            self.receivedDate = receivedDate
        }
        switch self.type {
        case .text:
            if let timestamp = info[MessageAttributes.timestamp.rawValue],
               let timestampDouble = Double(timestamp) {
                let receivedDate = Date(timeIntervalSince1970: timestampDouble)

                if let content = info[MessageAttributes.body.rawValue] {
                    self.content = content
                    self.accessibilityLabelValue = "\(content), \(self.incoming ? "Message received" : "Message sent") on \(receivedDate.conversationTimestamp())."
                } else {
                    self.content = "Text Message"
                    self.accessibilityLabelValue = "Text message received on \(receivedDate.conversationTimestamp()), content not available."
                }
            }
        case .call:
            if let timestamp = info[MessageAttributes.timestamp.rawValue],
               let timestampDouble = Double(timestamp) {
                let receivedDate = Date(timeIntervalSince1970: timestampDouble)

                if let duration = info[MessageAttributes.duration.rawValue],
                   let durationDouble = Double(duration) {
                    if durationDouble < 0 {
                        self.content = self.incoming ? "Incoming Call" : "Outgoing Call"
                        self.accessibilityLabelValue = self.incoming
                            ? "Incoming call on \(receivedDate.conversationTimestamp()), no duration available."
                            : "Outgoing call on \(receivedDate.conversationTimestamp()), no duration available."
                    } else {
                        let durationSeconds = durationDouble * 0.001
                        let time = Date.convertSecondsToTimeString(seconds: durationSeconds)
                        self.content = self.incoming ? "Incoming Call - \(time)" : "Outgoing Call - \(time)"
                        self.accessibilityLabelValue = self.incoming
                            ? "Incoming call on \(receivedDate.conversationTimestamp()), lasted \(time)."
                            : "Outgoing call on \(receivedDate.conversationTimestamp()), lasted \(time)."
                    }
                } else {
                    self.content = self.incoming ? "Missed Incoming Call" : "Missed Outgoing Call"
                    self.accessibilityLabelValue = self.incoming
                        ? "Missed incoming call on \(receivedDate.conversationTimestamp()), no answer."
                        : "Missed outgoing call on \(receivedDate.conversationTimestamp()), no answer."
                }
            }
        case .contact:
            if let action = info[MessageAttributes.action.rawValue],
               let contactAction = ContactAction(rawValue: action) {
                self.type = .contact(contactAction)
            }
        case .fileTransfer:
            if let timestamp = info[MessageAttributes.timestamp.rawValue],
               let timestampDouble = Double(timestamp) {
                let receivedDate = Date(timeIntervalSince1970: timestampDouble)
                
                if let fileid = info[MessageAttributes.fileId.rawValue] {
                    self.daemonId = fileid
                }
                
                if let displayName = info[MessageAttributes.displayName.rawValue] {
                    self.content = displayName
                    self.accessibilityLabelValue = "\(content), \(self.incoming ? "File received" : "File sent") on \(receivedDate.conversationTimestamp())."
                } else {
                    self.content = "File Transfer"
                    self.accessibilityLabelValue = "File received on \(receivedDate.conversationTimestamp()), name not available."
                }
            }
        case .initial:
            self.type = .initial
            self.content = L10n.GeneratedMessage.swarmCreated
        default:
            break
        }
        
        if !self.incoming {
            switch self.status {
            case .displayed:
                self.accessibilityLabelValue += ", Read by recipient"
            case .sent:
                self.accessibilityLabelValue += ", Unread by recipient"
            default:
                break
            }
        }

        if self.isMessageEdited() {
            self.accessibilityLabelValue += ", Edited"
        }

        if self.isMessageDeleted() {
            self.accessibilityLabelValue = "Message deleted"
        }

        if self.isReply() {
            self.accessibilityLabelValue += ", In reply to a message"
        }
    }

    func getContactInteractionString(name: String) -> String? {
        return self.type.getInteractionString(name: name, isIncoming: incoming)
    }

    func updateFrom(info: [String: String]) {
        if let content = info[MessageAttributes.body.rawValue], self.type == .text {
            self.content = content
        }
        if let timestamp = info[MessageAttributes.timestamp.rawValue],
           let timestampDouble = Double(timestamp) {
            let receivedDate = Date.init(timeIntervalSince1970: timestampDouble)
            self.receivedDate = receivedDate
        }
        if let parent = info[MessageAttributes.parent.rawValue] {
            self.parentId = parent
        }
        if let parents = info["parents"]?.components(separatedBy: ",").filter({ parentId in
            !parentId.isEmpty
        }) {
            self.parents.append(contentsOf: parents)
        }
    }

    func isReply() -> Bool {
        return !self.reply.isEmpty
    }

    func reactionAdded(reaction: [String: String]) {
        self.reactions.insert(MessageAction(withInfo: reaction))
    }

    func reactionRemoved(reactionId: String) {
        if let reactionToRemove = self.reactions.first(where: { $0.id == reactionId }) {
            self.reactions.remove(reactionToRemove)
        }
    }

    func isMessageDeleted() -> Bool {
        return self.content.isEmpty && !self.editions.isEmpty
    }

    func isMessageEdited() -> Bool {
        return !self.editions.isEmpty
    }

    func messageUpdated(message: SwarmMessageWrap, localJamiId: String) {
        self.editions = Set<MessageAction>()
        self.reactions = Set<MessageAction>()
        self.updateFrom(info: message.body)
        for reaction in message.reactions {
            self.reactions.insert(MessageAction(withInfo: reaction))
        }
        for edition in message.editions {
            self.editions.insert(MessageAction(withInfo: edition))
        }
        self.updateStatus(with: message, localJamiId: localJamiId)
    }

    func messageStatusUpdated(status: MessageStatus, messageId: String, jamiId: String) {
        self.statusForParticipant[jamiId] = status
        if status.rawValue <= MessageStatus.displayed.rawValue && self.status.rawValue < status.rawValue {
            self.status = status
        }
    }

    func isSending() -> Bool {
        guard !self.incoming else { return false }

        switch self.type {
        case .text:
            return self.status == .sending
        case .fileTransfer:
            return ![.success, .canceled, .error].contains(self.transferStatus)
        default:
            return false
        }
    }

    func isDelivered() -> Bool {
        guard !self.incoming else { return false }

        switch self.type {
        case .text:
            return self.status == .sent || self.status == .displayed
        case .fileTransfer:
            return [.success].contains(self.transferStatus)
        default:
            return false
        }
    }

    func reactionsMessageIdsBySender(jamiId: String) -> [String] {
        return Array(self.reactions.filter({ item in item.author == jamiId }).map({ item in item.id }))
    }
}
