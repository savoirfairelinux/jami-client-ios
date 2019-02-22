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
import SQLite
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
// swiftlint:disable file_length
// swiftlint:disable type_body_length
class DBManager {

    let profileHepler: ProfileDataHelper
    let conversationHelper: ConversationDataHelper
    let interactionHepler: InteractionDataHelper
    let accountProfileHelper: AccountProfileHelper

    // used to create object to save to db. When inserting in table defaultID will be replaced by autoincrementedID
    let defaultID: Int64 = 1

    let disposeBag = DisposeBag()

    init(profileHepler: ProfileDataHelper, conversationHelper: ConversationDataHelper,
         interactionHepler: InteractionDataHelper, accountProfileHelper: AccountProfileHelper) {
        self.profileHepler = profileHepler
        self.conversationHelper = conversationHelper
        self.interactionHepler = interactionHepler
        self.accountProfileHelper = accountProfileHelper
    }

    func start() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        // if db is empty - create tables. Migrations will be performed later if need
        do {
            try _ = dataBase.scalar(RingDB.instance.tableProfiles.exists)
            try _ = dataBase.scalar(RingDB.instance.tableConversations.exists)
            try _ = dataBase.scalar(RingDB.instance.tableInteractionss.exists)
        } catch {
            try dataBase.transaction {
                try profileHepler.createTable()
                try conversationHelper.createTable()
                try interactionHepler.createTable()
                try accountProfileHelper.createTable()
                dataBase.userVersion = RingDB.instance.dbVersion
            }
        }
    }

    func performMigrationIfNeeded() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let dataBaseVersion = dataBase.userVersion
        try dataBase.transaction {
            switch dataBaseVersion {
            case 0:
                if !migrateDBVersionFromZeroToOne(dataBase: dataBase) {
                    throw DataAccessError.databaseError
                }
            default:
                break
            }
        }
    }

    func migrateDBVersionFromZeroToOne(dataBase: Connection) -> Bool {
        do {
            try accountProfileHelper.createTable()
            dataBase.userVersion = RingDB.instance.dbVersion
            guard let delegate = UIApplication.shared.delegate as? AppDelegate else {return false}
            guard let account = delegate.injectionBag.accountService.currentAccount else {return false}
            guard let jamiId = AccountModelHelper(withAccount: account).ringId else {
                    return false
            }
            var accountProfile: Profile?
            if let profile = try self.getRingProfile(for: jamiId) {
                accountProfile = profile
            } else if let profile = try self.getRingProfile(for: account.id) {
                accountProfile = profile
                // if profile was saved with account id update row
                try profileHepler.updateURI(newURI: jamiId, for: profile.id)
            }
            guard let profile = accountProfile else {return false}
            _ = accountProfileHelper.insert(item: ProfileAccount(profile.id, account.id, true))
            //update profile image and alias
            VCardUtils.loadVCard(named: VCardFiles.myProfile.rawValue,
                                 inFolder: VCardFolders.profile.rawValue)
                .subscribe(onSuccess: { [unowned self] card in
                    let name = card.familyName
                    if let data = card.imageData {
                        _ = self.createOrUpdateRingProfile(profileUri: jamiId,
                                                           alias: name,
                                                           image: String(data: data, encoding: .utf8),
                                                           status: .trusted,
                                                           accountId: account.id,
                                                           isAccount: true)
                    }
                }).disposed(by: self.disposeBag)
            let contacts = delegate.injectionBag.contactsService.contacts.value
            for contact in contacts {
                if let profile = try self.getRingProfile(for: contact.ringId) {
                    _ = accountProfileHelper.insert(item: ProfileAccount(profile.id, account.id, false))
                }
            }
            return true
        } catch {
            return false
        }
    }

    // swiftlint:disable:next function_parameter_count
    func saveMessage(for accountUri: String,
                     accountId: String,
                     with contactUri: String,
                     message: MessageModel,
                     incoming: Bool,
                     interactionType: InteractionType) -> Observable<SavedMessageForConversation> {

        //create completable which will be executed on background thread
        return Observable.create { [weak self] observable in
            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DataAccessError.datastoreConnectionError
                }

                //use transaction to lock access to db from other threads while the following queries are executed
                try dataBase.transaction {

                    guard let accountProfile = try self?.addAndGetRingProfile(accountId: accountId, isAccount: true, profileUri: accountUri) else {
                        throw DBBridgingError.saveMessageFailed
                    }

                    guard let contactProfile = try self?.addAndGetRingProfile(accountId: accountId, isAccount: false, profileUri: contactUri) else {
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

    func clearHistoryBetween(accountUri: String,
                             and participantUri: String,
                             keepConversation: Bool) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                guard let dataBase = RingDB.instance.ringDB else {
                    throw DBBridgingError.deleteConversationFailed
                }
                try dataBase.transaction {

                    guard let accountProfile = try self.getRingProfile(for: accountUri) else {
                        throw DBBridgingError.deleteConversationFailed
                    }

                    guard let contactProfile = try self.getRingProfile(for: participantUri) else {
                        throw DBBridgingError.deleteConversationFailed
                    }

                    guard let conversationsID = try self.getConversationsIDBetween(accountProfileID: accountProfile.id, contactProfileID: contactProfile.id, createIfNotExists: true),
                        let conversationID =  conversationsID.first else {
                            throw DBBridgingError.deleteConversationFailed
                    }

                    guard let interactions = try self.interactionHepler
                        .selectConversationInteractions(
                            conversationID: conversationsID.first!,
                            accountProfileID: accountProfile.id) else {
                                throw DBBridgingError.deleteConversationFailed
                    }
                    if !interactions.isEmpty {
                        if !self.interactionHepler
                            .deleteAllIntercations(convID: conversationID) {
                            completable(.error(DBBridgingError.deleteConversationFailed))
                        }
                    }
                    if keepConversation {
                        completable(.completed)
                    } else {
                        let successConversations = self.conversationHelper
                            .deleteConversations(conversationID: conversationsID.first!)
                        if successConversations {
                            completable(.completed)
                        } else {
                            completable(.error(DBBridgingError.deleteConversationFailed))
                        }
                        // }
                    }
                }
            } catch {
                completable(.error(DBBridgingError.deleteConversationFailed))
            }
            return Disposables.create { }
        }
    }

    func getProfileObservable(for profileUri: String) -> Observable<Profile> {
        return Observable.create { observable in
            do {
                if let profile = try self.getRingProfile(for: profileUri) {
                    observable.onNext(profile)
                    observable.on(.completed)
                }
            } catch {
                observable.on(.error(DBBridgingError.getProfileFailed))
            }
            return Disposables.create { }
        }
    }

    func addAndGetProfileObservable(for profileUri: String, accountId: String, isAccount: Bool) -> Observable<Profile> {
        return Observable.create { observable in
            do {
                if let profile = try self.addAndGetRingProfile(accountId: accountId, isAccount: isAccount, profileUri: profileUri) {
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

        guard let accountProfile = try self.getRingProfile(for: accountUri) else {
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
                .selectConversationInteractions(
                    conversationID: conversationID,
                    accountProfileID: accountProfile.id) else {
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

    // swiftlint:disable:next function_parameter_count
    func createOrUpdateRingProfile(profileUri: String,
                                   alias: String?,
                                   image: String?,
                                   status: ProfileStatus,
                                   accountId: String,
                                   isAccount: Bool) -> Bool {
        let profile = Profile(defaultID, profileUri, alias, image, ProfileType.ring.rawValue,
                              status.rawValue)
        do {
            try self.profileHepler.insertOrUpdateProfile(item: profile)
            if let profile = try self.profileHepler.selectProfile(accountURI: profileUri) {
                accountProfileHelper.insert(item: ProfileAccount(profile.id, accountId, isAccount))
            }
        } catch {
            return  false
        }
        return true
    }

    private func addAndGetRingProfile(accountId: String, isAccount: Bool, profileUri: String) throws -> Profile? {
        if let profile = try self.profileHepler.selectProfile(accountURI: profileUri) {
            return profile
        }
        var profile = self.createTemplateRingProfile(account: profileUri)
        if isAccount {
            profile.status = ProfileStatus.trusted.rawValue
        }
        if self.profileHepler.insert(item: profile) {
            if let profile = try self.profileHepler.selectProfile(accountURI: profileUri) {
                accountProfileHelper.insert(item: ProfileAccount(profile.id, accountId, isAccount))
                return profile
            }
        }
        return nil
    }

    private func getRingProfile(for profileUri: String) throws -> Profile? {
        if let profile = try self.profileHepler.selectProfile(accountURI: profileUri) {
            return profile
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
