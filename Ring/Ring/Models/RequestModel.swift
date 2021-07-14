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
import RxRelay

class RequestModel {
    var conversationId = ""
    let accountId: String
    var name: String = ""
    var receivedDate: Date = Date()
    var avatar: Data = Data()
    var participants = [ConversationParticipant]()
    var conversationType: ConversationType = .nonSwarm
    var type: RequestType
    var synchronizing = BehaviorRelay<Bool>(value: false)

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

    init (with jamiId: String, accountId: String, withPayload payload: Data, receivedDate: Date, type: RequestType, conversationId: String) {
        self.accountId = accountId
        self.conversationId = conversationId
        self.type = type
        self.participants = [ConversationParticipant(jamiId: jamiId)]
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
            self.participants = [ConversationParticipant(jamiId: jamiId)]

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
            if let conversationId = dictionary["conversationId"] {
                self.conversationId = conversationId
            }
        } else {
            self.conversationType = .oneToOne
            if let conversationId = dictionary[RequestKey.conversationId.rawValue] {
                self.conversationId = conversationId
            }
            if let from = dictionary[RequestKey.from.rawValue] {
                self.participants.append(ConversationParticipant(jamiId: from))
            }
            if let title = dictionary[RequestKey.title.rawValue] {
               self.name = title
            }
            if let avatar = dictionary[RequestKey.avatar.rawValue] {
                self.avatar = NSData(base64Encoded: avatar,
                                     options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? ?? Data()
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
