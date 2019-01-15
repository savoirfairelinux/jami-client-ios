/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

enum InteractionStatus: String {
    case invalid = "INVALID"
    case unknown = "UNKNOWN"
    case sending = "SENDING"
    case failed = "FAILED"
    case succeed = "SUCCEED"
    case read = "READ"
    case unread = "UNREAD"
    case transferCreated = "TRANSFER_CREATED"
    case transferAwaiting = "TRANSFER_AWAITING"
    case transferCanceled = "TRANSFER_CANCELED"
    case transferOngoing = "TRANSFER_ONGOING"
    case transferSuccess = "TRANSFER_FINISHED"
    case transferError = "TRANSFER_ERROR"

    func toMessageStatus() -> MessageStatus {
        switch self {
        case .invalid: return MessageStatus.unknown
        case .unknown: return MessageStatus.unknown
        case .sending: return MessageStatus.sending
        case .failed: return MessageStatus.failure
        case .succeed: return MessageStatus.sent
        case .read: return MessageStatus.read
        case .unread: return MessageStatus.unknown
        default: return MessageStatus.unknown
        }
    }

    init(status: MessageStatus) {
        switch status {
        case .unknown: self = .unknown
        case .sending: self = .sending
        case .sent: self = .succeed
        case .read: self = .read
        case .failure: self = .failed
        }
    }

    func toDataTransferStatus() -> DataTransferStatus {
        switch self {
        case .transferCreated: return DataTransferStatus.created
        case .transferAwaiting: return DataTransferStatus.awaiting
        case .transferCanceled: return DataTransferStatus.canceled
        case .transferOngoing: return DataTransferStatus.ongoing
        case .transferSuccess: return DataTransferStatus.success
        case .transferError: return DataTransferStatus.error
        default: return DataTransferStatus.unknown
        }
    }

    init(status: DataTransferStatus) {
        switch status {
        case .created: self = .transferCreated
        case .awaiting: self = .transferAwaiting
        case .canceled: self = .transferCanceled
        case .ongoing: self = .transferOngoing
        case .success: self = .transferSuccess
        case .error: self = .transferError
        case .unknown: self = .unknown
        }
    }
}

enum DBBridgingError: Error {
    case saveMessageFailed
    case getConversationFailed
    case updateMessageStatusFailed
    case deleteConversationFailed
    case getProfileFailed
}

enum InteractionType: String {
    case invalid    = "INVALID"
    case text       = "TEXT"
    case call       = "CALL"
    case contact    = "CONTACT"
    case iTransfer  = "INCOMING_DATA_TRANSFER"
    case oTransfer  = "OUTGOING_DATA_TRANSFER"
}

typealias SavedMessageForConversation = (messageID: Int64, conversationID: Int64)

class DBManager {

    let profileHepler: ProfileDataHelper
    let conversationHelper: ConversationDataHelper
    let interactionHepler: InteractionDataHelper

    // used to create object to save to db. When inserting in table defaultID will be replaced by autoincrementedID
    let defaultID: Int64 = 1

    init(profileHepler: ProfileDataHelper, conversationHelper: ConversationDataHelper,
         interactionHepler: InteractionDataHelper) {
        self.profileHepler = profileHepler
        self.conversationHelper = conversationHelper
        self.interactionHepler = interactionHepler
    }

    func start() throws {
        try profileHepler.createTable()
        try conversationHelper.createTable()
        try interactionHepler.createTable()
    }

    func saveMessage(for accountUri: String, with contactUri: String, message: MessageModel, incoming: Bool, interactionType: InteractionType) -> Observable<SavedMessageForConversation> {

        //create completable which will be executed on background thread
        return Observable.create { [weak self] observable in
            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DataAccessError.datastoreConnectionError
                }

                //use transaction to lock access to db from other threads while the following queries are executed
                try dataBase.transaction {

                    guard let accountProfile = try self?.getProfile(for: accountUri, createIfNotExists: true) else {
                        throw DBBridgingError.saveMessageFailed
                    }

                    guard let contactProfile = try self?.getProfile(for: contactUri, createIfNotExists: true) else {
                        throw DBBridgingError.saveMessageFailed
                    }

                    var author: Int64

                    if incoming {
                       author = contactProfile.id
                    } else {
                       author = accountProfile.id
                    }

                    guard let conversationsID = try self?.getConversationsIDBetween(accountProfileID: accountProfile.id,
                                                                                    contactProfileID: contactProfile.id,
                                                                                    createIfNotExists: true),
                        !conversationsID.isEmpty else {
                            throw DBBridgingError.saveMessageFailed
                    }

                    guard let conversationID = conversationsID.first else {
                            throw DBBridgingError.saveMessageFailed
                    }
                    var result: Int64?
                    switch interactionType {
                    case .contact:
                        result = self?.addInteractionContactTo(conversation: conversationID, account: accountProfile.id, author: author, message: message)
                    case .text, .call, .iTransfer, .oTransfer:
                        // for now we have only one conversation between two persons(with group chat could be many)
                        result = self?.addMessageTo(conversation: conversationID, account: accountProfile.id, author: author, interactionType: interactionType, message: message)
                    default:
                        result = nil
                    }
                    if let messageID = result {
                        let savedMessage = SavedMessageForConversation(messageID, conversationID)
                        observable.onNext(savedMessage)
                        observable.on(.completed)
                    } else {
                        observable.on(.error(DBBridgingError.saveMessageFailed))
                    }
                }
            } catch {
                observable.on(.error(DBBridgingError.saveMessageFailed))
            }
            return Disposables.create { }
            }
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
    }

    func updateFileName(interactionID: Int64, name: String) -> Completable {
        return Completable.create { [unowned self] completable in
            let success = self.interactionHepler
                .updateInteractionWithID(interactionID: interactionID, content: name)
            if success {
                completable(.completed)
            } else {
                completable(.error(DBBridgingError.updateMessageStatusFailed))
            }

            return Disposables.create { }
        }
    }

    func updateTransferStatus(daemonID: String, withStatus transferStatus: DataTransferStatus) -> Completable {
        return Completable.create { [unowned self] completable in
            let success = self.interactionHepler
                .updateInteractionWithDaemonID(interactionDaemonID: daemonID,
                                               interactionStatus: InteractionStatus(status: transferStatus).rawValue)
            if success {
                completable(.completed)
            } else {
                completable(.error(DBBridgingError.updateMessageStatusFailed))
            }

            return Disposables.create { }
        }
    }

    func setMessagesAsRead(messagesIDs: [Int64], withStatus status: MessageStatus) -> Completable {
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
    }

    func removeConversationBetween(accountUri: String, and participantUri: String, keepAddContactEvent: Bool) -> Completable {
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

                    if keepAddContactEvent {
                        let successInteraction = self.interactionHepler
                            .deleteMessageAndCallInteractions(convID: conversationsID.first!)
                        if successInteraction {
                            completable(.completed)
                        }
                    } else {
                        let successInteraction = self.interactionHepler
                            .deleteAllIntercations(convID: conversationsID.first!)
                        if successInteraction {
                            let successConversations = self.conversationHelper
                                .deleteConversations(conversationID: conversationsID.first!)
                            if successConversations {
                                completable(.completed)
                            } else {
                                completable(.error(DBBridgingError.deleteConversationFailed))
                            }
                        } else {
                            completable(.error(DBBridgingError.deleteConversationFailed))
                        }
                    }
                }
            } catch {
                completable(.error(DBBridgingError.deleteConversationFailed))
            }
            return Disposables.create { }

        }
    }

    func profileObservable(for profileUri: String, createIfNotExists: Bool) -> Observable<Profile> {
        return Observable.create { observable in
            do {
                if let profile = try self.getProfile(for: profileUri, createIfNotExists: createIfNotExists) {
                    observable.onNext(profile)
                    observable.on(.completed)
                }
            } catch {
                observable.on(.error(DBBridgingError.getProfileFailed))
            }
            return Disposables.create { }
        }
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
                    continue
            }
            guard let participant =
                self.filterParticipantsFor(account: accountProfile.id,
                                          participants: participants) else {
                                            throw DBBridgingError.getConversationFailed
            }
            guard let participantProfile = try self.profileHepler.selectProfile(profileId: participant) else {
                continue
            }
            let conversationModel = ConversationModel(withRecipientRingId: participantProfile.uri,
                                                       accountId: accountID, accountUri: accountUri)
            conversationModel.participantProfile = participantProfile
            conversationModel.conversationId = String(conversationID)
            var messages = [MessageModel]()
            guard let interactions = try self.interactionHepler
                .selectInteractionsForConversationWithAccount(conversationID: conversationID,
                                                              accountProfileID: accountProfile.id),
                !interactions.isEmpty else {
                    continue
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
            conversationModel.messages = messages
            conversationsToReturn.append(conversationModel)
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

    private func filterParticipantsFor(account profileID: Int64, participants: [Int64]) -> Int64? {
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

    private func convertToMessage(interaction: Interaction, author: String) -> MessageModel? {
        if interaction.type != InteractionType.text.rawValue &&
            interaction.type != InteractionType.contact.rawValue &&
            interaction.type != InteractionType.call.rawValue &&
            interaction.type != InteractionType.iTransfer.rawValue &&
            interaction.type != InteractionType.oTransfer.rawValue {
            return nil
        }
        let date = Date(timeIntervalSince1970: TimeInterval(interaction.timestamp))
        let message = MessageModel(withId: interaction.daemonID,
                                   receivedDate: date,
                                   content: interaction.body,
                                   author: author,
                                   incoming: interaction.incoming)
        let isTransfer =    interaction.type == InteractionType.iTransfer.rawValue ||
                            interaction.type == InteractionType.oTransfer.rawValue
        if  interaction.type == InteractionType.contact.rawValue ||
            interaction.type == InteractionType.call.rawValue {
            message.isGenerated = true
        } else if isTransfer {
            message.isGenerated = false
            message.isTransfer = true
        }
        if let status: InteractionStatus = InteractionStatus(rawValue: interaction.status) {
            if isTransfer {
                message.transferStatus = status.toDataTransferStatus()
            } else {
                message.status = status.toMessageStatus()
            }
        }
        message.messageId = interaction.id
        return message
    }

    private func addMessageTo(conversation conversationID: Int64,
                              account accountProfileID: Int64,
                              author authorProfileID: Int64,
                              interactionType: InteractionType,
                              message: MessageModel) -> Int64? {
        let timeInterval = message.receivedDate.timeIntervalSince1970
        let interaction = Interaction(defaultID, accountProfileID, authorProfileID,
                                      conversationID, Int64(timeInterval),
                                      message.content, interactionType.rawValue,
                                      InteractionStatus.unknown.rawValue, message.daemonId,
                                      message.incoming)
        return self.interactionHepler.insert(item: interaction)
    }

    private func addInteractionContactTo(conversation conversationID: Int64,
                                         account accountProfileID: Int64,
                                         author authorProfileID: Int64,
                                         message: MessageModel) -> Int64? {
        let timeInterval = message.receivedDate.timeIntervalSince1970
        let interaction = Interaction(defaultID, accountProfileID, authorProfileID,
                                      conversationID, Int64(timeInterval),
                                      message.content, InteractionType.contact.rawValue,
                                      InteractionStatus.read.rawValue, message.daemonId,
                                      message.incoming)
        return self.interactionHepler.insertIfNotExist(item: interaction)
    }

    func createOrUpdateRingProfile(profileUri: String, alias: String?, image: String?, status: ProfileStatus) -> Bool {
        let profile = Profile(defaultID, profileUri, alias, image, ProfileType.ring.rawValue,
                              status.rawValue)
        do {
            try self.profileHepler.insertOrUpdateProfile(item: profile)
        } catch {
            return  false
        }
        return true
    }

    private func getProfile(for profileUri: String, createIfNotExists: Bool) throws -> Profile? {
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

        if !self.conversationHelper.insert(item: conversationForAccount) {
            return nil
        }
        if !self.conversationHelper.insert(item: conversationForContact) {
            return nil
        }

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
