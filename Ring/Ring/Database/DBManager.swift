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

    init(status: MessageStatus) {
        switch status {
        case .unknown:
            self = .unknown
        case .sending:
            self = .sending
        case .sent:
            self = .succeed
        case .read:
            self = .read
        case .failure:
            self = .failed
        }
    }
}

enum DBBridgingError: Error {
    case saveMessageFailed
    case getConversationFailed
    case updateMessageStatusFailed
    case deleteConversationFailed
}

enum InteractionType: String {
    case invalid = "INVALID"
    case text    = "TEXT"
    case call    = "CALL"
    case contact = "CONTACT"
}

class DBManager {

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

    func saveMessage(for accountUri: String, with contactUri: String, message: MessageModel, type: MessageDirection) -> Completable {

        //create completable which will be executed on background thread
        return Completable.create { [weak self] completable in
            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DataAccessError.datastoreConnectionError
                }

                //use transaction to lock access to db from other threads while the following queries are executed
                try dataBase.transaction {

                    //profile for account should be creating when creating account
                    guard let accountProfile = try self?.getProfile(for: accountUri, createIfNotExists: false) else {
                        throw DBBridgingError.saveMessageFailed
                    }

                    guard let contactProfile = try self?.getProfile(for: contactUri, createIfNotExists: true) else {
                        throw DBBridgingError.saveMessageFailed
                    }

                    var author: Int64
                    switch type {
                    case .incoming:
                        author = contactProfile.id
                    case .outgoing:
                        author = accountProfile.id
                    }

                    guard let conversationsID = try self?.getConversationsIDBetween(accountProfileID: accountProfile.id,
                                                                                    contactProfileID: contactProfile.id,
                                                                                    createIfNotExists: true),
                        !conversationsID.isEmpty else {
                            throw DBBridgingError.saveMessageFailed
                    }
                    // for now we have only one conversation between two persons(with group chat could be many)
                    if let success = self?.addMessageTo(conversation: conversationsID.first!, account: accountProfile.id, author: author, message: message), success {
                        completable(.completed)
                    } else {
                        completable(.error(DBBridgingError.saveMessageFailed))
                    }
                }
            } catch {
                completable(.error(DBBridgingError.saveMessageFailed))
            }
            return Disposables.create { }
            }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func getConversationsObservable(for accountID: String, accountURI: String) -> Observable<[ConversationModel]> {

        return Observable.create { observable in

            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DBBridgingError.getConversationFailed
                }
                try dataBase.transaction {
                    let conversations = try self.buildConversationsForAccount(accountUri: accountURI, accountID: accountID)
                    observable.onNext(conversations)
                    observable.on(.completed)
                }
            } catch {
                observable.on(.error(DBBridgingError.getConversationFailed))
            }
            return Disposables.create { }
            }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func updateMessageStatus(daemonID: String, withStatus status: MessageStatus) -> Completable {
        return Completable.create { [unowned self] completable in
            let success = self.interactionHepler
                .updateInteractionWithDaemonID(interactionDaemonID: daemonID,
                                         interactionStatus: InteractionStatus(status: status).rawValue)
            if success {
                completable(.completed)
            } else {
                completable(.error(DBBridgingError.updateMessageStatusFailed))
            }

            return Disposables.create { }
            }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func setMaesagesAsRead(messagesIDs: [Int64], withStatus status: MessageStatus) -> Completable {
        return Completable.create { [unowned self] completable in

            var success = true
            for messageId in messagesIDs {
                if !self.interactionHepler
                    .updateInteractionWithID(interactionID: messageId,
                                             interactionStatus: InteractionStatus(status: status).rawValue) {
                    success = false
                }

            }
            if success {
                completable(.completed)
            } else {
                completable(.error(DBBridgingError.saveMessageFailed))
            }

            return Disposables.create { }
            }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func removeConversationBetween(accountUri: String, and participantUri: String) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DBBridgingError.deleteConversationFailed
                }
                try dataBase.transaction {

                    guard let accountProfile = try self.getProfile(for: accountUri, createIfNotExists: false) else {
                        throw DBBridgingError.deleteConversationFailed
                    }

                    guard let contactProfile = try self.getProfile(for: participantUri, createIfNotExists: false) else {
                        throw DBBridgingError.deleteConversationFailed
                    }

                    guard let conversationsID = try self.getConversationsIDBetween(accountProfileID: accountProfile.id, contactProfileID: contactProfile.id, createIfNotExists: true),
                        !conversationsID.isEmpty else {
                            throw DBBridgingError.deleteConversationFailed
                    }

                    let sucessInteraction = self.interactionHepler
                        .deleteInteractionsForConversation(convID: conversationsID.first!)
                    if sucessInteraction {
                        let sucessConversations = self.conversationHelper
                            .deleteConversations(conversationID: conversationsID.first!)
                        if sucessConversations {
                            completable(.completed)
                        } else {
                            completable(.error(DBBridgingError.deleteConversationFailed))
                        }
                    } else {
                        completable(.error(DBBridgingError.deleteConversationFailed))
                    }
                }
            } catch {
                completable(.error(DBBridgingError.deleteConversationFailed))
            }
            return Disposables.create { }

            }
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    // MARK: Private functions

    private func buildConversationsForAccount(accountUri: String, accountID: String) throws -> [ConversationModel] {

        var conversationsToReturn = [ConversationModel]()

        guard let accountProfile = try self.getProfile(for: accountUri, createIfNotExists: false) else {
            throw DBBridgingError.getConversationFailed
        }
        guard let conversationsID = try self.selectConversationsForAccount(accountProfile: accountProfile.id),
            !conversationsID.isEmpty else {
                // if there is no conversation for account return empty list
                return conversationsToReturn
        }
        for conversationID in conversationsID {
            guard let participants = try self.getParticipantsForConversation(conversationID: conversationID),
                !participants.isEmpty else {
                    throw DBBridgingError.getConversationFailed
            }
            guard let participant =
                self.filterPartiipantsfor(account: accountProfile.id,
                                          participants: participants) else {
                                            throw DBBridgingError.getConversationFailed
            }
            guard let participantProfile = try self.profileHepler.selectProfile(profileId: participant) else {
                throw DBBridgingError.getConversationFailed
            }
            let conversationModel1 = ConversationModel(withRecipientRingId: participantProfile.uri,
                                                       accountId: accountID, accountUri: accountUri)
            conversationModel1.participantProfile = participantProfile
            var messages = [MessageModel]()
            guard let interactions = try self.interactionHepler
                .selectInteractionsForConversationWithAccount(conversationID: conversationID,
                                                              accountProfileID: accountProfile.id),
                !interactions.isEmpty else {
                    throw DBBridgingError.getConversationFailed
            }
            for interaction in interactions {
                var author = accountProfile.uri
                if interaction.authorID == participantProfile.id {
                    author = participantProfile.uri
                }
                if let message = self.convertToMessage(interaction: interaction, author: author) {
                    messages.append(message)
                }

            }
            conversationModel1.messages = messages
            conversationsToReturn.append(conversationModel1)
        }
        return conversationsToReturn
    }

    private func selectConversationsForAccount(accountProfile: Int64)throws -> [Int64]? {
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
        // for now we does not support group chat, so we have only two participant for each conversation
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

    private func convertToMessage(interaction: Interaction, author: String) -> MessageModel? {
        let date = Date(timeIntervalSince1970: TimeInterval(interaction.timestamp))
        let message = MessageModel(withId: interaction.daemonID,
                                   receivedDate: date,
                                   content: interaction.body,
                                   author: author)
        message.isGenerated = self.isGenerated(message: message)
        if let status: InteractionStatus = InteractionStatus(rawValue: interaction.status) {
            message.status = status.toMessageStatus()
        }
        return message
    }

    private func addMessageTo(conversation conversationID: Int64,
                              account accountProfileID: Int64,
                              author authorProfileID: Int64,
                              message: MessageModel) -> Bool {
        let timeInterval = message.receivedDate.timeIntervalSince1970
        let interaction = Interaction(defaultID, accountProfileID, authorProfileID,
                                      conversationID, Int64(timeInterval),
                                      message.content, InteractionType.text.rawValue,
                                      InteractionStatus.unknown.rawValue, message.daemonId)
        return self.interactionHepler.insert(item: interaction)
    }

    func getProfile(for profileUri: String, createIfNotExists: Bool) throws -> Profile? {
        if let profile = try self.profileHepler.selectProfile(accountURI: profileUri) {
            return profile
        }
        if !createIfNotExists {
            return nil
        }
        // for now we use template profile
        let profile = self.createTemplateRingProfile(account: profileUri)
        if self.profileHepler.insert(item: profile) {
            return try self.profileHepler.selectProfile(accountURI: profileUri)
        }
        return nil
    }

    private func createTemplateRingProfile(account uri: String) -> Profile {
        return Profile(defaultID, uri, nil, nil, ProfileType.ring.rawValue,
                       ProfileStatus.untrasted.rawValue)
    }

    private func getConversationsIDBetween(accountProfileID: Int64,
                                           contactProfileID: Int64,
                                           createIfNotExists: Bool) throws -> [Int64]? {
        if let accountConversations = try self.conversationHelper
            .selectConversationsForProfile(profileId: accountProfileID) {
            if let contactConversations = try self.conversationHelper
                .selectConversationsForProfile(profileId: contactProfileID) {

                let result = Array(Set(accountConversations.map({$0.id}))
                    .intersection(Set(contactConversations.map({$0.id}))))
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

        _ = self.conversationHelper.insert(item: conversationForAccount)
        _ = self.conversationHelper.insert(item: conversationForContact)

        guard let accountConversations = try self.conversationHelper
            .selectConversationsForProfile(profileId: accountProfileID) else {
                return nil
        }
        guard let contactConversations = try self.conversationHelper
            .selectConversationsForProfile(profileId: contactProfileID) else {
                return nil
        }
        return Array(Set(accountConversations.map({$0.id}))
            .intersection(Set(contactConversations.map({$0.id}))))
    }
}
