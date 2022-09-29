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
    case timestamp = "timestamp"
    case parent = "linearizedParent"
    case action = "action"
    case duration = "duration"
}

enum MessageType: String {
    case text = "text/plain"
    case fileTransfer = "application/data-transfer+json"
    case contact = "member"
    case call = "application/call-history+json"
    case location = "location"
    case merge = "merge"
    case initial = "initial"
}

enum ContactAction: String {
    case add
    case remove
    case join
    case banned
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
    var status: MessageStatus = .unknown
    var transferStatus: DataTransferStatus = .unknown
    var incoming: Bool
    var parentId: String = ""
    var type: MessageType = .text

    init(withId id: String, receivedDate: Date, content: String, authorURI: String, incoming: Bool) {
        self.daemonId = id
        self.receivedDate = receivedDate
        self.content = content
        self.authorId = authorURI
        self.incoming = incoming
    }
    // swiftlint:disable:next cyclomatic_complexity
    init(withInfo info: [String: String], accountJamiId: String) {
        if let interactionId = info[MessageAttributes.interactionId.rawValue] {
            self.id = interactionId
        }
        if let author = info[MessageAttributes.author.rawValue], author != accountJamiId {
            self.authorId = author
        }
        if let type = info[MessageAttributes.type.rawValue],
           let messageType = MessageType(rawValue: type) {
            self.type = messageType
        }
        if let content = info[MessageAttributes.body.rawValue], self.type == .text {
            self.content = content
        }
        incoming = !self.authorId.isEmpty
        if let parent = info[MessageAttributes.parent.rawValue] {
            self.parentId = parent
        }
        if let timestamp = info[MessageAttributes.timestamp.rawValue],
           let timestampDouble = Double(timestamp) {
            let receivedDate = Date.init(timeIntervalSince1970: timestampDouble)
            self.receivedDate = receivedDate
        }
        switch self.type {
        case .text:
            if let content = info[MessageAttributes.body.rawValue] {
                self.content = content
            }
        case .call:
            if let duration = info[MessageAttributes.duration.rawValue],
               let durationDouble = Double(duration) {
                if durationDouble < 0 {
                    self.content = self.incoming ? L10n.GeneratedMessage.incomingCall : L10n.GeneratedMessage.outgoingCall
                } else {
                    let durationSeconds = durationDouble * 0.001
                    let time = Date.convertSecondsToTimeString(seconds: durationSeconds)
                    self.content = self.incoming ? L10n.GeneratedMessage.incomingCall + " - " + time : L10n.GeneratedMessage.outgoingCall + " - " + time
                }
            } else {
                self.content = self.incoming ? L10n.GeneratedMessage.missedIncomingCall : L10n.GeneratedMessage.missedOutgoingCall
            }
        case .contact:
            if let action = info[MessageAttributes.action.rawValue],
               let contactAction = ContactAction(rawValue: action) {
                switch contactAction {
                case .add:
                    self.content = self.incoming ? L10n.GeneratedMessage.invitationReceived : L10n.GeneratedMessage.contactAdded
                case .join:
                    self.content = L10n.GeneratedMessage.invitationAccepted
                case .remove:
                    self.content = L10n.GeneratedMessage.contactLeftConversation
                default:
                    break
                }
            }
        case .fileTransfer:
            if let fileid = info[MessageAttributes.fileId.rawValue] {
                self.daemonId = fileid
            }
            if let displayName = info[MessageAttributes.displayName.rawValue] {
                self.content = displayName
            }
        case .initial:
            self.type = .contact
            self.content = self.incoming ? "Invitation received" : "Contact added"
        default:
            break
        }
    }
}
