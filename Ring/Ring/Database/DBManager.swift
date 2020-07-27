/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
        case .displayed: return DataTransferStatus.success
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
    case deleteMessageFailed
}

enum InteractionType: String {
    case invalid    = "INVALID"
    case text       = "TEXT"
    case call       = "CALL"
    case contact    = "CONTACT"
    case iTransfer  = "INCOMING_DATA_TRANSFER"
    case oTransfer  = "OUTGOING_DATA_TRANSFER"
    case location   = "LOCATION"
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

    func isMigrationToDBv2Needed(accountId: String) -> Bool {
        return self.dbConnections.isMigrationToDBv2Needed(for: accountId)
    }

    func migrateToDbVersion2(accountId: String, accountURI: String) -> Bool {
        if !accountURI.contains("ring:") {
            self.dbConnections.createAccountfolder(for: accountId)
        }
        if !self.dbConnections.copyDbToAccountFolder(for: accountId) {
            return false
        }
        guard let newDB = self.dbConnections.forAccount(account: accountId) else {
            return false
        }
        // move profiles to vcards
        do {
            try newDB.transaction { [weak self] in
                guard let self = self else { throw DataAccessError.databaseError }
                if try !self.migrateAccountToVCard(for: accountId, accountURI: accountURI, dataBase: newDB) {
                    throw DataAccessError.databaseError
                }
                if try !self.migrateProfilesToVCards(for: accountId, dataBase: newDB) {
                    throw DataAccessError.databaseError
                }
                // remove db from documents folder
                self.dbConnections.removeDBForAccount(account: accountId)
                newDB.userVersion = 2
            }
        } catch _ as NSError {
            return false
        }
        return true
    }

    func createDatabaseForAccount(accountId: String, createFolder: Bool = false) throws -> Bool {
        if createFolder {
            self.dbConnections.createAccountfolder(for: accountId)
        }
        guard let newDB = self.dbConnections.forAccount(account: accountId) else {
            return false
        }
        do {
            try newDB.transaction {
                conversationHelper.createTable(accountDb: newDB)
                interactionHepler.createTable(accountDb: newDB)
            }
        } catch {
            throw DataAccessError.databaseError
        }
        return true
    }

    func migrateProfilesToVCards(for accountId: String, dataBase: Connection) throws -> Bool {
        guard let profiles = try? self.profileHepler.selectAll(dataBase: dataBase) else {
            return false
        }
        for profile in profiles {
            if self.dbConnections.isContactProfileExists(accountId: accountId, profileURI: profile.uri) {
                continue
            }
            guard let profilePath = self.dbConnections.contactProfilePath(accountId: accountId, profileURI: profile.uri, createifNotExists: true) else { return false }
            try self.saveProfile(profile: profile, path: profilePath)
            if !self.dbConnections.isContactProfileExists(accountId: accountId, profileURI: profile.uri) {
                return false
            }
        }
        self.profileHepler.dropProfileTable(accountDb: dataBase)
        return true
    }

    func migrateAccountToVCard(for accountId: String, accountURI: String, dataBase: Connection) throws -> Bool {
        if self.dbConnections.isAccountProfileExists(accountId: accountId) { return true }
        guard let accountProfile = self.profileHepler.getAccountProfile(dataBase: dataBase) else {
            return self.dbConnections.isAccountProfileExists(accountId: accountId)
        }
        guard let path = self.dbConnections.accountProfilePath(accountId: accountId) else { return false }
        let type = accountURI.contains("ring:") ? URIType.ring : URIType.sip
        let profile = Profile(accountURI, accountProfile.alias, accountProfile.photo, type.getString())
        try self.saveProfile(profile: profile, path: path)
        if !self.dbConnections.isAccountProfileExists(accountId: accountId) {
            return false
        }
        self.profileHepler.dropAccountTable(accountDb: dataBase)
        return true
    }

    func removeDBForAccount(accountId: String, removeFolder: Bool) {
        self.dbConnections.removeDBForAccount(account: accountId, removeFolder: removeFolder)
    }

    func createConversationsFor(contactUri: String, accountId: String) {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return
        }
        do {
            try _ = self.getConversationsFor(contactUri: contactUri,
                                         createIfNotExists: true,
                                         dataBase: dataBase, accountId: accountId)
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
                                                                             dataBase: dataBase, accountId: accountId) else {
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

    func getProfilesForAccount(accountId: String) -> [Profile]? {
        var profiles = [Profile]()
        do {
            guard let path = self.dbConnections.contactsPath(accountId: accountId,
                                                             createIfNotExists: true) else { return nil }
            guard let documentURL = URL(string: path) else { return nil }
            let directoryContents = try FileManager.default.contentsOfDirectory(at: documentURL, includingPropertiesForKeys: nil, options: [])
            for url in directoryContents {
                if let profile = getProfileFromPath(path: url.path) {
                    profiles.append(profile)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return profiles
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

    func deleteMessage(messagesId: Int64, accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            if let dataBase = self.dbConnections.forAccount(account: accountId) {
                if self.interactionHepler.delete(interactionId: messagesId, dataBase: dataBase) {
                    completable(.completed)
                } else {
                    completable(.error(DBBridgingError.deleteMessageFailed))
                }
            } else {
                completable(.error(DBBridgingError.deleteMessageFailed))
            }
            return Disposables.create { }
        }
    }

    func clearAllHistoryFor(accountId: String) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
                    throw DBBridgingError.deleteConversationFailed
                }
                try dataBase.transaction {
                    if !self.interactionHepler
                        .deleteAll(dataBase: dataBase) {
                        completable(.error(DBBridgingError.deleteConversationFailed))
                    }
                    if !self.conversationHelper
                        .deleteAll(dataBase: dataBase) {
                        completable(.error(DBBridgingError.deleteConversationFailed))
                    }
                    self.dbConnections.removeContacts(accountId: accountId)
                    completable(.completed)
                }
            } catch {
                completable(.error(DBBridgingError.deleteConversationFailed))
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
                    guard (try self.getProfile(for: participantUri, createIfNotExists: false, accountId: accountId)) != nil else {
                        throw DBBridgingError.deleteConversationFailed
                    }
                    guard let conversationsId = try self.getConversationsFor(contactUri: participantUri,
                                                                             createIfNotExists: true,
                                                                             dataBase: dataBase, accountId: accountId) else {
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
                            .deleteAllInteractions(conv: conversationsId, dataBase: dataBase) {
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
                                                     accountId: accountId) {
                    observable.onNext(profile)
                    observable.on(.completed)
                }
            } catch {
                observable.on(.error(DBBridgingError.getProfileFailed))
            }
            return Disposables.create { }
        }
    }

    func accountProfileObservable(for accountId: String) -> Observable<Profile> {
        return Observable.create { observable in
            guard let profile = self.accountProfile(for: accountId) else {
                observable.on(.error(DBBridgingError.getProfileFailed))
                return Disposables.create { }
            }
            observable.onNext(profile)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func accountProfile(for accountId: String) -> Profile? {
        guard let path = self.dbConnections.accountProfilePath(accountId: accountId) else { return nil }
        return self.getProfileFromPath(path: path)
    }

    func accountVCard(for accountId: String) -> CNContact? {
        guard let path = self.dbConnections.accountProfilePath(accountId: accountId),
            let data = FileManager.default.contents(atPath: path) else { return nil }
        return CNContactVCardSerialization.parseToVCard(data: data)
    }

    func createOrUpdateRingProfile(profileUri: String, alias: String?, image: String?, accountId: String) -> Bool {
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip
        if type == ProfileType.sip {
            self.dbConnections.createAccountfolder(for: accountId)
        }
        guard let path = self.dbConnections.contactProfilePath(accountId: accountId, profileURI: profileUri, createifNotExists: true) else { return false }

        let profile = Profile(profileUri, alias, image, ProfileType.ring.rawValue)

        do {
            try self.saveProfile(profile: profile, path: path)
        } catch {
            return false
        }
        return self.dbConnections.isContactProfileExists(accountId: accountId, profileURI: profileUri)
    }

    func saveAccountProfile(alias: String?, photo: String?, accountId: String, accountURI: String) -> Bool {
        let type = accountURI.contains("ring") ? ProfileType.ring : ProfileType.sip
        if type == ProfileType.sip {
            self.dbConnections.createAccountfolder(for: accountId)
        }
        guard let path = self.dbConnections.accountProfilePath(accountId: accountId) else { return false }
        let profile = Profile(accountURI, alias, photo, type.rawValue)
        do {
            try self.saveProfile(profile: profile, path: path)
            return self.dbConnections.isAccountProfileExists(accountId: accountId)
        } catch {
            return false
        }
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
        for conversationID in conversations.map({ $0.id }) {
            guard let participants = try self.getParticipantsForConversation(conversationID: conversationID,
                dataBase: dataBase),
                let participant = participants.first else {
                    continue
            }
            let type = participant.contains("ring:") ? URIType.ring : URIType.sip
            let uri = JamiURI.init(schema: type, infoHach: participant)
            let conversationModel = ConversationModel(withParticipantUri: uri,
                                                      accountId: accountId)
            if let participantProfile = try self.getProfile(for: participant, createIfNotExists: false, accountId: accountId) {
                conversationModel.participantProfile = participantProfile
            }
            conversationModel.conversationId = String(conversationID)
            var messages = [MessageModel]()
            guard let interactions = try self.interactionHepler
                .selectInteractionsForConversation(
                    conv: conversationID,
                    dataBase: dataBase) else {
                        continue
            }
            for interaction in interactions {
                let author = interaction.author == participant
                    ? participant : ""
                if let message = self.convertToMessage(interaction: interaction, author: author) {
                    messages.append(message)
                    let displayedMessage = author.isEmpty && message.status == .displayed
                    let isLater = conversationModel
                        .lastDisplayedMessage.id == -1 ||
                        conversationModel
                            .lastDisplayedMessage.timestamp < message.receivedDate
                    if displayedMessage && isLater {
                        conversationModel
                            .lastDisplayedMessage = (message.messageId,
                                                     message.receivedDate)
                    }
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
        return conversations.map({ $0.participant })
    }

    private func convertToMessage(interaction: Interaction, author: String) -> MessageModel? {
        if interaction.type != InteractionType.text.rawValue &&
            interaction.type != InteractionType.contact.rawValue &&
            interaction.type != InteractionType.call.rawValue &&
            interaction.type != InteractionType.iTransfer.rawValue &&
            interaction.type != InteractionType.oTransfer.rawValue &&
            interaction.type != InteractionType.location.rawValue {
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
        let isTransfer = interaction.type == InteractionType.iTransfer.rawValue ||
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
        if interaction.type == InteractionType.location.rawValue {
            message.isLocationSharing = true
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

    func getProfile(for profileUri: String, createIfNotExists: Bool, accountId: String) throws -> Profile? {
        let type = profileUri.contains("ring") ? ProfileType.ring : ProfileType.sip
        if createIfNotExists && type == ProfileType.sip {
            self.dbConnections.createAccountfolder(for: accountId)
        }
        guard let profilePath = self.dbConnections
            .contactProfilePath(accountId: accountId,
                                profileURI: profileUri,
                                createifNotExists: createIfNotExists) else { return nil }
        if self.dbConnections
            .isContactProfileExists(accountId: accountId,
                                  profileURI: profileUri) || !createIfNotExists {
            return getProfileFromPath(path: profilePath)
        }
        let profile = Profile(profileUri, nil, nil, type.rawValue)
        try self.saveProfile(profile: profile, path: profilePath)
        return getProfileFromPath(path: profilePath)
    }

    private func getProfileFromPath(path: String) -> Profile? {
        guard let data = FileManager.default.contents(atPath: path),
            let vCard = CNContactVCardSerialization.parseToVCard(data: data) else {
                return nil
        }
        let profileURI = vCard.phoneNumbers.isEmpty ? "" : vCard.phoneNumbers[0].value.stringValue
        let type = profileURI.contains("ring") ? ProfileType.ring : ProfileType.sip
        let imageString = {(data: Data?) -> String in
            guard let data = data else { return "" }
            return data.base64EncodedString()
        }(vCard.imageData)
        let profile = Profile(profileURI, vCard.familyName, imageString, type.rawValue)
        return profile
    }

    private func saveProfile(profile: Profile, path: String) throws {
        let url = URL(fileURLWithPath: path)
        let contactCard = CNMutableContact()
        if let name = profile.alias {
            contactCard.familyName = name
        }
        contactCard.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberiPhone, value: CNPhoneNumber(stringValue: profile.uri))]
        if let photo = profile.photo {
            contactCard.imageData = NSData(base64Encoded: photo,
            options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
        }
        let data = try CNContactVCardSerialization.dataWithImageAndUUID(from: contactCard, andImageCompression: 40000)
        try data.write(to: url)
    }

    private func getConversationsFor(contactUri: String,
                                     createIfNotExists: Bool, dataBase: Connection, accountId: String) throws -> Int64? {
        if let contactConversations = try self.conversationHelper
            .selectConversationsForProfile(profileUri: contactUri, dataBase: dataBase),
            let conv = contactConversations.first {
            return conv.id
        }
        if !createIfNotExists {
            return nil
        }
        let conversationID = Int64(arc4random_uniform(10000000))
        do {
        _ = try self.getProfile(for: contactUri, createIfNotExists: true, accountId: accountId)
        } catch {}
        let conversationForContact = Conversation(conversationID, contactUri)
        if !self.conversationHelper.insert(item: conversationForContact, dataBase: dataBase) {
            return nil
        }
        return try self.conversationHelper
            .selectConversationsForProfile(profileUri: contactUri, dataBase: dataBase)?.first?.id
    }

    // MARK: Location sharing
    func isFirstLocationIncomingUpdate(incoming: Bool, peerUri: String, accountId: String) -> Bool? {
        do {
            guard let dataBase = self.dbConnections.forAccount(account: accountId) else { return nil }

            let conversationId = try self.getConversationsFor(contactUri: peerUri, createIfNotExists: true, dataBase: dataBase, accountId: accountId)
            let interactions = try self.interactionHepler.selectInteractionsForConversation(conv: conversationId!, dataBase: dataBase)

            var isFirst = true
            for (interaction) in interactions! where interaction.type == InteractionType.location.rawValue && interaction.incoming == incoming {
                isFirst = false
                break
            }
            return isFirst
        } catch {
            return nil
        }
    }

    func deleteLocationUpdates(incoming: Bool, peerUri: String, accountId: String) -> Completable {
        return Completable.create(subscribe: { [weak self] completable in
            do {
                guard let self = self, let dataBase = self.dbConnections.forAccount(account: accountId) else { throw DataAccessError.datastoreConnectionError }
                let conversationId = try self.getConversationsFor(contactUri: peerUri, createIfNotExists: true, dataBase: dataBase, accountId: accountId)

                let predicat: Expression<Bool> = (self.interactionHepler.conversation == conversationId! &&
                                                  self.interactionHepler.type == InteractionType.location.rawValue &&
                                                  self.interactionHepler.incoming == incoming)

                _ = try self.interactionHepler.deleteInteractions(where: predicat, dataBase: dataBase)
                completable(.completed)
            } catch {
                completable(.error(DBBridgingError.deleteMessageFailed))
            }
            return Disposables.create { }
        })
    }

    func deleteAllLocationUpdates(accountIds: [String]) -> Bool {
        var didNotFailOnce = true
        for accountId in accountIds {
            do {
                guard let dataBase = self.dbConnections.forAccount(account: accountId) else { throw DataAccessError.datastoreConnectionError }

                let predicat: Expression<Bool> = (self.interactionHepler.type == InteractionType.location.rawValue)

                _ = try self.interactionHepler.deleteInteractions(where: predicat, dataBase: dataBase)
            } catch {
                didNotFailOnce = false
            }
        }
        return didNotFailOnce
    }
}
