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

import Contacts
import SwiftyBeaver

class RequestModel {
    var conversationId = ""
    let accountId: String
    var name: String = ""
    var receivedDate: Date = Date()
    var avatar: Data = Data()
    var participants = [ConversationParticipant]()
    var conversationType: ConversationType = .nonSwarm
    var type: RequestType

    enum RequestKey: String {
        case payload = "payload"
        case title = "title"
        case description = "description"
        case avatar = "avatar"
        case mode = "mode"
        case conversationId = "id"
        case from = "from"
        case received = "received"
    }

    enum RequestType {
        case contact
        case conversation
    }

    init (with jamiId: String, accountId: String, withPayload payload: Data, receivedDate: Date, type: RequestType) {
        self.accountId = accountId
        self.type = type
        self.participants = [ConversationParticipant(uri: jamiId)]
        self.receivedDate = receivedDate
        if let contactVCard = CNContactVCardSerialization.parseToVCard(data: payload) {
            self.avatar = contactVCard.imageData ?? Data()
            self.name = VCardUtils.getName(from: contactVCard).isEmpty ? jamiId : contactVCard.familyName
        }
    }

    init(withDictionary dictionary: [String: String], accountId: String, type: RequestType) {
        self.accountId = accountId
        self.type = type
        if self.type == .contact {
            guard let jamiId = dictionary[RequestKey.from.rawValue] else { return }
            self.participants = [ConversationParticipant(uri: jamiId)]

            if let vCardString = dictionary[RequestKey.payload.rawValue],
               let data = vCardString.data(using: String.Encoding.utf8), !data.isEmpty,
               let contactVCard = CNContactVCardSerialization.parseToVCard(data: data) {
                self.avatar = contactVCard.imageData ?? Data()
                self.name = VCardUtils.getName(from: contactVCard).isEmpty ? jamiId : contactVCard.familyName
            }
            if let receivedDateString = dictionary[RequestKey.received.rawValue],
               let timestamp = Double(receivedDateString) {
                self.receivedDate = Date(timeIntervalSince1970: timestamp)
            }
        } else {
            if let conversationId = dictionary[RequestKey.conversationId.rawValue] {
                self.conversationId = conversationId
            }
            if let from = dictionary[RequestKey.from.rawValue] {
                self.participants.append(ConversationParticipant(uri: from))
            }
            if let type = dictionary[RequestKey.mode.rawValue],
               let typeInt = Int(type),
               let conversationType = ConversationType(rawValue: typeInt) {
                self.conversationType = conversationType
            }
            if let avatar = dictionary[RequestKey.avatar.rawValue] {
                self.avatar = avatar.data(using: .utf8) ?? Data()
            }
            if let timestamp = dictionary[RequestKey.received.rawValue],
               let timestampDouble = Double(timestamp) {
                let receivedDate = Date.init(timeIntervalSince1970: timestampDouble)
                self.receivedDate = receivedDate
            }
        }
    }

    convenience init(withDictionary dictionary: [String: String], accountId: String, type: RequestType, conversationId: String) {
        self.init(withDictionary: dictionary, accountId: accountId, type: type)
        self.conversationId = conversationId
    }

    func isCoredialog() -> Bool {
        return self.conversationType == .nonSwarm || self.conversationType == .oneToOne
    }
}
