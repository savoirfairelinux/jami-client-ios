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
import RxRelay

class RequestModel {
    var conversationId = ""
    let accountId: String
    var name: String = ""
    var receivedDate: Date = .init()
    var avatar: Data?
    var participants = [ConversationParticipant]()
    var conversationType: ConversationType = .nonSwarm
    var type: RequestType

    enum RequestKey: String {
        case payload
        case title
        case description
        case avatar
        case mode
        case conversationId = "id"
        case from
        case received
    }

    enum RequestType {
        case contact
        case conversation
    }

    init(conversation: ConversationModel) {
        conversationId = conversation.id
        accountId = conversation.accountId
        conversationType = conversation.type
        type = .conversation
        participants = conversation.getParticipants()
    }

    init(
        with jamiId: String,
        accountId: String,
        withPayload payload: Data,
        receivedDate: Date,
        type: RequestType,
        conversationId: String
    ) {
        self.accountId = accountId
        self.conversationId = conversationId
        self.type = type
        participants = [ConversationParticipant(jamiId: jamiId)]
        self.receivedDate = receivedDate
        if let profile = VCardUtils.parseToProfile(data: payload) {
            if let photo = profile.photo {
                avatar = NSData(
                    base64Encoded: photo,
                    options: NSData.Base64DecodingOptions.ignoreUnknownCharacters
                ) as? Data
            }
            if let name = profile.alias {
                self.name = name
            }
        }
    }

    init(withDictionary dictionary: [String: String], accountId: String, type: RequestType) {
        self.accountId = accountId
        self.type = type
        if self.type == .contact {
            guard let jamiId = dictionary[RequestKey.from.rawValue] else { return }
            participants = [ConversationParticipant(jamiId: jamiId)]

            if let vCardString = dictionary[RequestKey.payload.rawValue],
               let data = vCardString.data(using: String.Encoding.utf8), !data.isEmpty,
               let profile = VCardUtils.parseToProfile(data: data) {
                if let photo = profile.photo {
                    avatar = NSData(
                        base64Encoded: photo,
                        options: NSData.Base64DecodingOptions.ignoreUnknownCharacters
                    ) as? Data
                }
                if let name = profile.alias {
                    self.name = name
                }
            }
            if let receivedDateString = dictionary[RequestKey.received.rawValue],
               let timestamp = Double(receivedDateString) {
                receivedDate = Date(timeIntervalSince1970: timestamp)
            }
            if let conversationId = dictionary["conversationId"] {
                self.conversationId = conversationId
            }
        } else {
            updatefrom(dictionary: dictionary)
        }
    }

    func updatefrom(dictionary: [String: String]) {
        if let type = dictionary[ConversationAttributes.mode.rawValue],
           let typeInt = Int(type),
           let conversationType = ConversationType(rawValue: typeInt) {
            self.conversationType = conversationType
        }

        if conversationType == .nonSwarm {
            type = .contact
        }
        if let conversationId = dictionary[RequestKey.conversationId.rawValue] {
            self.conversationId = conversationId
        }
        if let from = dictionary[RequestKey.from.rawValue] {
            participants.append(ConversationParticipant(jamiId: from))
        }
        if let title = dictionary[RequestKey.title.rawValue] {
            name = title
        }
        if let avatar = dictionary[RequestKey.avatar.rawValue], !avatar.isEmpty {
            self.avatar = Data(base64Encoded: avatar,
                               options: Data.Base64DecodingOptions.ignoreUnknownCharacters)
        }
        if let timestamp = dictionary[RequestKey.received.rawValue],
           let timestampDouble = Double(timestamp) {
            let receivedDate = Date(timeIntervalSince1970: timestampDouble)
            self.receivedDate = receivedDate
        }
    }

    convenience init(
        withDictionary dictionary: [String: String],
        accountId: String,
        type: RequestType,
        conversationId: String
    ) {
        self.init(withDictionary: dictionary, accountId: accountId, type: type)
        self.conversationId = conversationId
    }

    func getIdentifier() -> String {
        if type == .conversation {
            return conversationId
        } else {
            return participants.first?.jamiId ?? ""
        }
    }

    func isCoredialog() -> Bool {
        return conversationType == .nonSwarm || conversationType == .oneToOne
    }

    func isDialog() -> Bool {
        return participants.count == 1
    }
}
