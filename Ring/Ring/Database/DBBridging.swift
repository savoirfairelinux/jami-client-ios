/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
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

enum ProfileType: String {
    case ring = "RING"
    case sip = "SIP"
}

enum ProfileStatus: String {
    case trusted = "TRUSTED"
    case untrasted = "UNTRUSTED"
}

enum MessageDirection {
    case incoming
    case outgoing
}
enum InteractionStatus: String {
    case invalid = "INVALID"
    case unknown = "UNKNOWN"
    case sending = "SENDING"
    case failed = "FAILED"
    case succeed = "SUCCEED"
    case read = "READ"
    case unread = "UNREAD"

    func toMessageStatus() -> MessageStatus {
        switch self {
        case .invalid:
            return MessageStatus.unknown
        case .unknown:
            return MessageStatus.unknown
        case .sending:
            return MessageStatus.sending
        case .failed:
            return MessageStatus.failure
        case .succeed:
            return MessageStatus.sent
        case .read:
            return MessageStatus.read
        case .unread:
            return MessageStatus.unknown
        }
    }
}

enum InteractionType: String {
    case invalid = "INVALID"
    case text    = "TEXT"
    case call    = "CALL"
    case contact = "CONTACT"
}

class DBBridging {

    let profileHepler = ProfileDataHelper()
    let conversationHelper = ConversationDataHelper()
    let interactionHepler = InteractionDataHelper()

    // used to create object to save to db. When inserting in table defaultID will be replaced by autoincrementedID
    let defaultID: Int64 = 1

    func start() throws {
        do {
            try profileHepler.createTable()
            try conversationHelper.createTable()
            try interactionHepler.createTable()
        } catch {
            throw DataAccessError.datastoreConnectionError
        }
    }
    func saveMessage(for accountUri: String, with contactUri: String, message: MessageModel, type: MessageDirection) -> Bool {
        do {
            guard let accountProfile = try self.getProfile(for: accountUri) else {
                return false
            }

            guard let profile = try self.getProfile(for: contactUri, createIfNotExists: true) else {
                return false
            }

            var author: Int64
            switch type {
            case .incoming:
                author = profile.id
            case .outgoing:
                author = accountProfile.id
            }
            guard let conversationsID = try self.getConversationsBetween(accountProfileID: accountProfile.id, contactProfileID: profile.id, createIfNotExists: true), !conversationsID.isEmpty else {
                return false
            }
            // for now we supposed we have only one conversation between two person
            try self.addMessageTo(conversation: conversationsID.first!, account: accountProfile.id, author: author, message: message)
            return true

        } catch {
            return false
        }
    }

    func getConversations(for account: AccountModel) -> [ConversationModel1]? {

        let accountHelper = AccountModelHelper(withAccount: account)
        guard let accountURI = accountHelper.ringId else {
            return nil
        }
        let accountID = account.id
        var conversationsToReturn = [ConversationModel1]()

        do {
            guard let accountProfile = try self.getProfile(for: accountURI) else {
                return nil
            }
            guard let conversationsID = try self.getConversationsForAccount(accountProfile: accountProfile.id),
                !conversationsID.isEmpty else {
                    return nil
            }
            for conversationID in conversationsID {
                guard let participants = try self.getParticipantsForConversation(conversationID: conversationID),
                    !participants.isEmpty else {
                        return nil
                }

                guard let participant = self.filterPartiipantsfor(account: accountProfile.id,
                                                                  participants: participants) else {
                                                                    return nil
                }
                guard let participantProfile = try self.profileHepler.selectProfile(profileId: participant) else {
                    return nil
                }
                let conversationModel1 = ConversationModel1(withRecipientRingId: participantProfile.uri,
                                                            accountId: accountID)
                conversationModel1.participantProfile = participantProfile
                var messages = [MessageModel]()
                guard let interactions = try self.interactionHepler
                    .selectInteractionsForConversationWithAccount(conversationID: conversationID,
                                                                  accountProfileID: accountProfile.id),
                    !interactions.isEmpty else {
                        return nil
                }
                for interaction in interactions {
                    if let message = self.convertToMessage(interaction: interaction) {
                        messages.append(message)
                    }

                }
                conversationModel1.messages = messages
                conversationsToReturn.append(conversationModel1)
            }
        } catch {
            return nil
        }
        return conversationsToReturn
    }

    // MARK: Private functions

    private func getConversationsForAccount(accountProfile: Int64)throws -> [Int64]? {
        guard let accountConversations = try self.conversationHelper.selectConversationsForProfile(profileId: accountProfile) else {
            return nil
        }
        return accountConversations.map({$0.id})
    }

    private func getParticipantsForConversation(conversationID: Int64) throws -> [Int64]? {
        guard let conversations = try self.conversationHelper.selectConversations(conversationId: conversationID) else {
            return nil
        }
        return conversations.map({$0.participantID})
    }

    private func filterPartiipantsfor(account profileID: Int64, participants: [Int64]) -> Int64? {
        var participants = participants
        guard let accountProfileIndex = participants.index(of: profileID) else {
            return nil
        }
        participants.remove(at: accountProfileIndex)
        if participants.isEmpty {
            return nil
        }
        // for now we does not support group chat
        return participants.first
    }

    private func isGenerated(message: MessageModel) -> Bool {
        switch message.content {
        case GeneratedMessageType.contactRequestAccepted.rawValue:
            return true
        case GeneratedMessageType.receivedContactRequest.rawValue:
            return true
        case GeneratedMessageType.sendContactRequest.rawValue:
            return true
        default:
            return false
        }
    }

    private func convertToMessage(interaction: Interaction) -> MessageModel? {
        do {
            if let profile = try self.profileHepler.selectProfile(profileId: interaction.authorID) {
                let date = Date(timeIntervalSince1970: TimeInterval(interaction.timestamp))
                let message = MessageModel(withId: interaction.daemonID,
                                           receivedDate: date,
                                           content: interaction.body,
                                           author: profile.uri)
                message.isGenerated = self.isGenerated(message: message)
                if let status: InteractionStatus = InteractionStatus(rawValue: interaction.status) {
                    message.status = status.toMessageStatus()
                }
                return message
            }
        } catch {
            return nil
        }
        return nil
    }

    private func addMessageTo (conversation conversationID: Int64, account accountProfileID: Int64, author authorProfileID: Int64, message: MessageModel) throws {
        let timeInterval = message.receivedDate.timeIntervalSince1970
        let interaction = Interaction(1, accountProfileID, authorProfileID,
                                      conversationID, Int64(timeInterval),
                                      message.content, InteractionType.text.rawValue,
                                      InteractionStatus.unknown.rawValue, message.id)
        try _ = self.interactionHepler.insert(item: interaction)
    }

    private func beginConversationBetween(accountProfileID: Int64, contactProfileID: Int64) throws -> [Int64]? {
        let conversationID = Int64(arc4random_uniform(10000000))
        let conversationForAccount = Conversation(conversationID, accountProfileID)
        let conversationForContact = Conversation(conversationID, contactProfileID)

        try _ = self.conversationHelper.insert(item: conversationForAccount)
        try _ = self.conversationHelper.insert(item: conversationForContact)

        return try self.getConversationsBetween(accountProfileID: accountProfileID, contactProfileID: contactProfileID)
    }

    private func getConversationsBetween(accountProfileID: Int64, contactProfileID: Int64) throws -> [Int64]? {
        guard let accountConversations = try self.conversationHelper.selectConversationsForProfile(profileId: accountProfileID) else {
            return nil
        }
        guard let contactConversations = try self.conversationHelper.selectConversationsForProfile(profileId: contactProfileID) else {
            return nil
        }
        return Array(Set(accountConversations.map({$0.id})).intersection(Set(contactConversations.map({$0.id}))))
    }

    private func getProfile(for uri: String) throws -> Profile? {
        return try self.profileHepler.selectRingProfile(accountURI: uri)
    }

    func addTemplateProfile(for uri: String, type: ProfileType, status: ProfileStatus) throws -> Profile? {
        let profile = Profile(defaultID, uri, nil, nil, type.rawValue, status.rawValue)
        _ = try self.profileHepler.insert(item: profile)
        return try self.getProfile(for: uri)
    }

    private func getProfile(for profileUri: String, createIfNotExists: Bool) throws -> Profile? {
        if let profile = try self.profileHepler.selectRingProfile(accountURI: profileUri) {
            return profile
        }
        if !createIfNotExists {
            return nil
        }
        let profile = Profile(defaultID, profileUri, nil, nil, ProfileType.ring.rawValue, ProfileStatus.untrasted.rawValue)
        _ = try self.profileHepler.insert(item: profile)
        return try self.profileHepler.selectRingProfile(accountURI: profileUri)
    }

    private func getConversationsBetween(accountProfileID: Int64,
                                         contactProfileID: Int64,
                                         createIfNotExists: Bool) throws -> [Int64]? {
        if let accountConversations = try self.conversationHelper.selectConversationsForProfile(profileId: accountProfileID) {
            if let contactConversations = try self.conversationHelper.selectConversationsForProfile(profileId: contactProfileID) {
                let result = Array(Set(accountConversations.map({$0.id})).intersection(Set(contactConversations.map({$0.id}))))
                if !result.isEmpty {
                    return result
                }
            }
        }

        if !createIfNotExists {
            return nil
        }
        let conversationID = Int64(arc4random_uniform(10000000))
        let conversationForAccount = Conversation(conversationID, accountProfileID)
        let conversationForContact = Conversation(conversationID, contactProfileID)

        try _ = self.conversationHelper.insert(item: conversationForAccount)
        try _ = self.conversationHelper.insert(item: conversationForContact)

        guard let accountConversations = try self.conversationHelper.selectConversationsForProfile(profileId: accountProfileID) else {
            return nil
        }
        guard let contactConversations = try self.conversationHelper.selectConversationsForProfile(profileId: contactProfileID) else {
            return nil
        }
        return Array(Set(accountConversations.map({$0.id})).intersection(Set(contactConversations.map({$0.id}))))
    }

}
