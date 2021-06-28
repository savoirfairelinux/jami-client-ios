/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
}

enum ContactAction: String {
    case add
    case remove
    case join
    case banned
}

class MessageModel {

    var messageId: String = ""
    var daemonId: String = ""
    var receivedDate: Date = Date()
    var content: String = ""
    var authorURI: String = ""
    var status: MessageStatus = .unknown
    var transferStatus: DataTransferStatus = .unknown
   // var isGenerated: Bool = false
    // var isTransfer: Bool = false
    var incoming: Bool
   // var isLocationSharing: Bool = false
    var parentId: String = ""
    var type: MessageType = .text

    init(withId id: String, receivedDate: Date, content: String, authorURI: String, incoming: Bool) {
        self.daemonId = id
        self.receivedDate = receivedDate
        self.content = content
        self.authorURI = authorURI
        self.incoming = incoming
    }
    // swiftlint:disable:next cyclomatic_complexity
    init(withInfo info: [String: String], accountURI: String) {
        if let interactionId = info[MessageAttributes.interactionId.rawValue] {
            self.messageId = interactionId
        }
        if let author = info[MessageAttributes.author.rawValue], author.replacingOccurrences(of: "ring:", with: "") != accountURI.replacingOccurrences(of: "ring:", with: "") {
            self.authorURI = author
        }
        if let type = info[MessageAttributes.type.rawValue] {
            if let invited = info[MessageAttributes.invited.rawValue],
               type == "initial" {
                self.type = .contact
//                if invited.replacingOccurrences(of: "ring:", with: "") != accountURI.replacingOccurrences(of: "ring:", with: "") {
//                    self.authorURI = invited
//                }
                if self.authorURI.isEmpty {
                    self.content = "Contact added"
                } else {
                    self.content = "Invitation received"
                }
            } else if let messageType = MessageType(rawValue: type) {
                self.type = messageType
            }
        }
        if let content = info[MessageAttributes.body.rawValue], self.type == .text {
            self.content = content
        }
        incoming = self.authorURI.isEmpty
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
                    if self.authorURI.isEmpty {
                        self.content = "Outgoing call"
                    } else {
                        self.content = "Incoming call"
                    }
                } else {
                    let durationSeconds = durationDouble * 0.001
                    let time = Date.convertSecondsToTimeString(seconds: durationSeconds)
                    if self.authorURI.isEmpty {
                        self.content = "Outgoing call - " + time
                    } else {
                        self.content = "Incoming call - " + time
                    }
                }
            } else {
                if self.authorURI.isEmpty {
                    self.content = "Missed outgoing call"
                } else {
                    self.content = "Missed incoming call"
                }
            }
        case .contact:
            if let action = info[MessageAttributes.action.rawValue],
               let contactAction = ContactAction(rawValue: action) {
                switch contactAction {
                case .add:
                    if self.authorURI.isEmpty {
                        self.content = "Contact added"
                    } else {
                        self.content = "Invitation received"
                    }
                case .join:
                    self.content = "Invitation accepted"
                case .remove:
                    self.content = "Contact left conversation"
                default:
                    break
                }
            }
        case .fileTransfer:
            if let fileid = info[MessageAttributes.fileId.rawValue] {
                // self.isTransfer = true
            }

        default:
            break
        }
    }
}
