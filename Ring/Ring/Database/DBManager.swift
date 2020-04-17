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
import SQLite

enum ProfileType: String {
    case ring = "RING"
    case sip = "SIP"
}

enum GeneratedMessage: Int {
    case outgoingCall
    case incomingCall
    case missedOutgoingCall
    case missedIncomingCall
    case contactAdded
    case invitationReceived
    case invitationAccepted
    case unknown

    func toString() -> String {
        return String(self.rawValue)
    }
    init(from: String) {
        if let intValue = Int(from) {
            self = GeneratedMessage(rawValue: intValue) ?? .unknown
        } else {
            self =  .unknown
        }
    }
    func toMessage(with duration: Int) -> String {
        let time = Date.convertSecondsToTimeString(seconds: Double(duration))
        switch self {
        case .contactAdded:
            return L10n.GeneratedMessage.contactAdded
        case .invitationReceived:
            return L10n.GeneratedMessage.invitationReceived
        case .invitationAccepted:
            return L10n.GeneratedMessage.invitationAccepted
        case .missedOutgoingCall:
            return L10n.GeneratedMessage.missedOutgoingCall
        case .missedIncomingCall:
            return L10n.GeneratedMessage.missedIncomingCall
        case .outgoingCall:
            return L10n.GeneratedMessage.outgoingCall + " - " + time
        case .incomingCall:
            return L10n.GeneratedMessage.incomingCall + " - " + time
        default:
            return ""
        }
    }
}

enum InteractionStatus: String {
    case invalid = "INVALID"
    case unknown = "UNKNOWN"
    case sending = "SENDING"
    case failed = "FAILED"
    case succeed = "SUCCEED"
    case displayed = "DISPLAYED"
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
        case .displayed: return MessageStatus.displayed
        case .unread: return MessageStatus.unknown
        default: return MessageStatus.unknown
        }
    }

    init(status: MessageStatus) {
        switch status {
        case .unknown: self = .unknown
        case .sending: self = .sending
        case .sent: self = .succeed
        case .displayed: self = .displayed
        case .failure: self = .failed
        @unknown default:
            self = .unknown
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
    case updateIntercationFailed
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

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class DBManager {

    let profileHepler: ProfileDataHelper
    let conversationHelper: ConversationDataHelper
    let interactionHepler: InteractionDataHelper
    let dbConnections: DBContainer
    let disposeBag = DisposeBag()

    // used to create object to save to db. When inserting in table defaultID will be replaced by autoincrementedID
    let defaultID: Int64 = 1

    init(profileHepler: ProfileDataHelper, conversationHelper: ConversationDataHelper,
         interactionHepler: InteractionDataHelper, dbConnections: DBContainer) {
        self.profileHepler = profileHepler
        self.conversationHelper = conversationHelper
        self.interactionHepler = interactionHepler
        self.dbConnections = dbConnections
    }

    func isNeedMigrationToAccountDB(accountId: String) -> Bool {
        return self.dbConnections.isDBExistsFor(account: accountId)
    }

    func createDatabaseForAccount(accountId: String) throws -> Bool {
        guard let newDB = self.dbConnections.forAccount(account: accountId) else {
            return false
        }
        do {
            try newDB.transaction {
                profileHepler.createAccountTable(accountDb: newDB)
                profileHepler.createContactsTable(accountDb: newDB)
                conversationHelper.createTable(accountDb: newDB)
                interactionHepler.createTable(accountDb: newDB)
            }
        } catch {
            throw DataAccessError.databaseError
        }
        return true
    }

    func migrateToAccountDB(accountId: String, jamiId: String) throws {
        do {
            guard let newDB = self.dbConnections.forAccount(account: accountId) else {
                throw DataAccessError.datastoreConnectionError
            }
            try newDB.transaction {
                profileHepler.createAccountTable(accountDb: newDB)
                profileHepler.createContactsTable(accountDb: newDB)
                conversationHelper.createTable(accountDb: newDB)
                interactionHepler.createTable(accountDb: newDB)
                guard let oldDb = self.dbConnections.getJamiDB() else {throw DataAccessError.datastoreConnectionError}
                let profileFromJamiId = try self.profileHepler.getLegacyProfileID(profileURI: jamiId, dataBase: oldDb)
                let profileFromAccountId = try self.profileHepler.getLegacyProfileID(profileURI: accountId, dataBase: oldDb)
                let profile = profileFromJamiId != nil ? profileFromJamiId : profileFromAccountId
                guard let accountProfile = profile else {throw DataAccessError.datastoreConnectionError}
                let allProfiles = try self.profileHepler.getLegacyProfiles(accountURI: jamiId, accountId: accountId, database: oldDb)
                try profileHepler.migrateToDBForAccount(from: oldDb, to: newDB, jamiId: jamiId, accountId: accountId)
                VCardUtils.loadVCard(named: VCardFiles.myProfile.rawValue,
                                     inFolder: VCardFolders.profile.rawValue)
                    .subscribe(onSuccess: { [unowned self] card in
                        let name = card.familyName
                        let imageData: String? = card.imageData?.base64EncodedString()
                        _ = self.saveAccountProfile(alias: name, photo: imageData,
                                                    accountId: accountId)
                    }).disposed(by: self.disposeBag)
                try conversationHelper.migrateToDBForAccount(from: oldDb, to: newDB,
                                                             accountProfileId: accountProfile,
                                                             contactsMap: allProfiles)
                try interactionHepler.migrateToDBForAccount(from: oldDb, to: newDB,
                                                            accountProfileId: accountProfile,
                                                            contactsMap: allProfiles)
            }
        } catch {
            throw DataAccessError.databaseMigrationError
        }
    }

    func removeDBForAccount(accountId: String) {
        self.dbConnections.removeDBForAccount(account: accountId)
    }

    func createConversationsFor(contactUri: String, accountId: String) {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return
        }
        do {
            try _ = self.getConversationsFor(contactUri: contactUri,
                                         createIfNotExists: true,
                                         dataBase: dataBase)
        } catch {}
    }

    // swiftlint:disable:next function_parameter_count
    func saveMessage(for accountId: String, with contactUri: String,
                     message: MessageModel, incoming: Bool,
                     interactionType: InteractionType, duration: Int) -> Observable<SavedMessageForConversation> {

        //create completable which will be executed on background thread
        return Observable.create { [weak self] observable in
            do {
                guard let dataBase = self?.dbConnections.forAccount(account: accountId) else {
                    throw DataAccessError.datastoreConnectionError
                }
                try dataBase.transaction {
                    let author: String? = incoming ? contactUri : nil
                    guard let conversationID = try self?.getConversationsFor(contactUri: contactUri,
                                                                             createIfNotExists: true,
                                                                             dataBase: dataBase) else {
                            throw DBBridgingError.saveMessageFailed
                    }
                    let result = self?.addMessageTo(conversation: conversationID, author: author,
                                                    interactionType: interactionType, message: message,
                                                    duration: duration, dataBase: dataBase)
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

    func getConversationsObservable(for accountId: String) -> Observable<[ConversationModel]> {
        return Observable.create { observable in
            do {
                guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
                    throw DBBridgingError.getConversationFailed
                }
                try dataBase.transaction(Connection.TransactionMode.immediate, block: {
                    let conversations = try self.buildConversationsForAccount(accountId: accountId)
                    observable.onNext(conversations)
                    observable.on(.completed)
                })
            } catch {
                observable.on(.error(DBBridgingError.getConversationFailed))
            }
            return Disposables.create { }
            }
    }

    func updateMessageStatus(daemonID: String, withStatus status: MessageStatus, accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            if let dataBase = self.dbConnections.forAccount(account: accountId) {
                let success = self.interactionHepler
                    .updateInteractionWithDaemonID(interactionDaemonID: daemonID,
                                                   interactionStatus: InteractionStatus(status: status).rawValue,
                                                   dataBase: dataBase)
                if success {
                    completable(.completed)
                } else {
                    completable(.error(DBBridgingError.updateIntercationFailed))
                }
            } else {
                completable(.error(DBBridgingError.updateIntercationFailed))
            }
            return Disposables.create { }
        }
    }

    func getProfilesForAccount(accountID: String) -> [Profile]? {
        guard let database = self.dbConnections.forAccount(account: accountID) else {
            return nil
        }
        do {
            return try self.profileHepler.selectAll(dataBase: database)
        } catch {
            return nil
        }
    }

    func updateFileName(interactionID: Int64, name: String, accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            if let dataBase = self.dbConnections.forAccount(account: accountId) {
                let success = self.interactionHepler
                    .updateInteractionContentWithID(interactionID: interactionID, content: name, dataBase: dataBase)
                if success {
                    completable(.completed)
                } else {
                    completable(.error(DBBridgingError.updateIntercationFailed))
                }
            } else {
                completable(.error(DBBridgingError.updateIntercationFailed))
            }
            return Disposables.create { }
        }
    }

    func updateTransferStatus(daemonID: String, withStatus transferStatus: DataTransferStatus, accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            if let dataBase = self.dbConnections.forAccount(account: accountId) {
                let success = self.interactionHepler
                    .updateInteractionWithDaemonID(interactionDaemonID: daemonID,
                                                   interactionStatus: InteractionStatus(status: transferStatus).rawValue,
                                                   dataBase: dataBase)
                if success {
                    completable(.completed)
                } else {
                    completable(.error(DBBridgingError.updateIntercationFailed))
                }
            } else {
                completable(.error(DBBridgingError.updateIntercationFailed))
            }
            return Disposables.create { }
        }
    }

    func setMessagesAsRead(messagesIDs: [Int64], withStatus status: MessageStatus, accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            if let dataBase = self.dbConnections.forAccount(account: accountId) {
                var success = true
                for messageId in messagesIDs {
                    if !self.interactionHepler
                        .updateInteractionStatusWithID(interactionID: messageId,
                                                 interactionStatus: InteractionStatus(status: status).rawValue,
                                                 dataBase: dataBase) {
                        success = false
                    }
                }
                if success {
                    completable(.completed)
                } else {
                    completable(.error(DBBridgingError.saveMessageFailed))
                }
            } else {
                completable(.error(DBBridgingError.saveMessageFailed))
            }
            return Disposables.create { }
        }
    }

    func clearHistoryFor(accountId: String,
                         and participantUri: String,
                         keepConversation: Bool) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
                    throw DBBridgingError.deleteConversationFailed
                }
                try dataBase.transaction {
                    guard (try self.getProfile(for: participantUri, createIfNotExists: false, accounId: accountId)) != nil else {
                        throw DBBridgingError.deleteConversationFailed
                    }
                    guard let conversationsId = try self.getConversationsFor(contactUri: participantUri,
                                                                             createIfNotExists: true,
                                                                             dataBase: dataBase) else {
                            throw DBBridgingError.deleteConversationFailed
                    }
                    guard let interactions = try self.interactionHepler
                        .selectInteractionsForConversation(
                            conv: conversationsId,
                            dataBase: dataBase) else {
                                throw DBBridgingError.deleteConversationFailed
                    }
                    if !interactions.isEmpty {
                        if !self.interactionHepler
                            .deleteAllIntercations(conv: conversationsId, dataBase: dataBase) {
                            completable(.error(DBBridgingError.deleteConversationFailed))
                        }
                    }
                    if keepConversation {
                        completable(.completed)
                    } else {
                        let successConversations = self.conversationHelper
                            .deleteConversations(conversationID: conversationsId, dataBase: dataBase)
                        if successConversations {
                            completable(.completed)
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

    func profileObservable(for profileUri: String, createIfNotExists: Bool, accountId: String) -> Observable<Profile> {
        return Observable.create { observable in
            do {
                if let profile = try self.getProfile(for: profileUri,
                                                     createIfNotExists: createIfNotExists,
                                                     accounId: accountId) {
                    observable.onNext(profile)
                    observable.on(.completed)
                }
            } catch {
                observable.on(.error(DBBridgingError.getProfileFailed))
            }
            return Disposables.create { }
        }
    }

    func accountProfileObservable(for accountId: String) -> Observable<AccountProfile> {
        return Observable.create { observable in
            guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
                observable.on(.error(DBBridgingError.getProfileFailed))
                return Disposables.create { }
            }
            guard let profile = self.profileHepler.getAccountProfile(dataBase: dataBase) else {
                observable.on(.error(DBBridgingError.getProfileFailed))
                return Disposables.create { }
            }
            observable.onNext(profile)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func accountProfile(for accountId: String) -> AccountProfile? {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return nil
        }
        return self.profileHepler.getAccountProfile(dataBase: dataBase)
    }

    func createOrUpdateRingProfile(profileUri: String, alias: String?, image: String?, accountId: String) -> Bool {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return false
        }
        let profile = Profile(profileUri, alias, image, ProfileType.ring.rawValue)
        do {
            try self.profileHepler.insertOrUpdateProfile(item: profile, dataBase: dataBase)
        } catch {
            return  false
        }
        return true
    }

    func saveAccountProfile(alias: String?, photo: String?, accountId: String) -> Bool {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return false
        }
        return self.profileHepler.updateAccountProfile(accountAlias: alias,
                                                       accountPhoto: photo,
                                                       dataBase: dataBase)
    }

    // MARK: Private functions
    private func buildConversationsForAccount(accountId: String) throws -> [ConversationModel] {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            throw DBBridgingError.getConversationFailed
        }
        var conversationsToReturn = [ConversationModel]()

        guard let conversations = try self.conversationHelper.selectAll(dataBase: dataBase),
            !conversations.isEmpty else {
                // if there is no conversation for account return empty list
                return conversationsToReturn
        }
        for conversationID in conversations.map({$0.id}) {
            guard let participants = try self.getParticipantsForConversation(conversationID: conversationID,
                dataBase: dataBase),
                let partisipant = participants.first else {
                    continue
            }
            guard let participantProfile = try self.profileHepler.selectProfile(profileURI: partisipant,
                                                                                dataBase: dataBase) else {
                continue
            }
            let type = participantProfile.uri.contains("sip:") ? URIType.sip : URIType.ring
            let uri = JamiURI.init(schema: type, infoHach: participantProfile.uri)
            let conversationModel = ConversationModel(withParticipantUri: uri,
                                                      accountId: accountId)
            conversationModel.participantProfile = participantProfile
            conversationModel.conversationId = String(conversationID)
            var messages = [MessageModel]()
            guard let interactions = try self.interactionHepler
                .selectInteractionsForConversation(
                    conv: conversationID,
                    dataBase: dataBase) else {
                        continue
            }
            for interaction in interactions {
                let author = interaction.author == participantProfile.uri
                    ? participantProfile.uri : ""
                if let message = self.convertToMessage(interaction: interaction, author: author) {
                    messages.append(message)
                }
            }
            conversationModel.messages = messages
            conversationsToReturn.append(conversationModel)
        }
        return conversationsToReturn
    }

    private func getParticipantsForConversation(conversationID: Int64, dataBase: Connection) throws -> [String]? {
        guard let conversations = try self.conversationHelper
            .selectConversations(conversationId: conversationID,
                                 dataBase: dataBase) else {
            return nil
        }
        return conversations.map({$0.participant})
    }

    private func convertToMessage(interaction: Interaction, author: String) -> MessageModel? {
        if interaction.type != InteractionType.text.rawValue &&
            interaction.type != InteractionType.contact.rawValue &&
            interaction.type != InteractionType.call.rawValue &&
            interaction.type != InteractionType.iTransfer.rawValue &&
            interaction.type != InteractionType.oTransfer.rawValue {
            return nil
        }
        let content = (interaction.type == InteractionType.call.rawValue
        || interaction.type == InteractionType.contact.rawValue) ?
            GeneratedMessage.init(from: interaction.body).toMessage(with: Int(interaction.duration))
            : interaction.body
        let date = Date(timeIntervalSince1970: TimeInterval(interaction.timestamp))
        let message = MessageModel(withId: interaction.daemonID,
                                   receivedDate: date,
                                   content: content,
                                   authorURI: author,
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

    // swiftlint:disable:next function_parameter_count
    private func addMessageTo(conversation conversationID: Int64,
                              author: String?,
                              interactionType: InteractionType,
                              message: MessageModel,
                              duration: Int,
                              dataBase: Connection) -> Int64? {
        var status = InteractionStatus.unknown.rawValue
        if interactionType == .oTransfer {
            status = InteractionStatus(status: message.transferStatus).rawValue
        }
        let timeInterval = message.receivedDate.timeIntervalSince1970
        let interaction = Interaction(defaultID, author,
                                      conversationID, Int64(timeInterval), Int64(duration),
                                      message.content, interactionType.rawValue,
                                     status, message.daemonId,
                                      message.incoming)
        return self.interactionHepler.insert(item: interaction, dataBase: dataBase)
    }

    func getProfile(for profileUri: String, createIfNotExists: Bool, accounId: String) throws -> Profile? {
        guard let dataBase = self.dbConnections.forAccount(account: accounId) else {
            throw DataAccessError.datastoreConnectionError
        }
        if let profile = try self.profileHepler.selectProfile(profileURI: profileUri, dataBase: dataBase) {
            return profile
        }
        if !createIfNotExists {
            return nil
        }
        // for now we use template profile
        let profile = self.createTemplateProfile(uri: profileUri)
        if self.profileHepler.insert(item: profile, dataBase: dataBase) {
            return try self.profileHepler.selectProfile(profileURI: profileUri, dataBase: dataBase)
        }
        return nil
    }

    private func createTemplateProfile(uri: String) -> Profile {
        let type = uri.contains("ring") ? ProfileType.ring : ProfileType.sip
        return Profile(uri, nil, nil, type.rawValue)
    }

    private func getConversationsFor(contactUri: String,
                                     createIfNotExists: Bool, dataBase: Connection) throws -> Int64? {
        if let contactConversations = try self.conversationHelper
            .selectConversationsForProfile(profileUri: contactUri, dataBase: dataBase),
            let conv = contactConversations.first {
            return conv.id
        }
        if !createIfNotExists {
            return nil
        }
        let conversationID = Int64(arc4random_uniform(10000000))
        _ = self.profileHepler.insert(item: self.createTemplateProfile(uri: contactUri), dataBase: dataBase)
        let conversationForContact = Conversation(conversationID, contactUri)
        if !self.conversationHelper.insert(item: conversationForContact, dataBase: dataBase) {
            return nil
        }
        return try self.conversationHelper
            .selectConversationsForProfile(profileUri: contactUri, dataBase: dataBase)?.first?.id
    }
}
