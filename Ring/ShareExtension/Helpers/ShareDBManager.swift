/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import Foundation
import RxSwift
import SQLite

typealias SavedMessageForConversation = (messageID: String, conversationID: String)

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class ShareDBManager {

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
        let profile = Profile(uri: accountURI, alias: accountProfile.alias, photo: accountProfile.photo, type: type.getString())
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

    func createConversationsFor(contactUri: String, accountId: String) -> String {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            return ""
        }
        do {
            let result = try self.getConversationsFor(contactUri: contactUri,
                                                      createIfNotExists: true,
                                                      dataBase: dataBase, accountId: accountId)
            return "\(result ?? -1)"
        } catch {}
        return ""
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

    // MARK: Private functions
    private func buildConversationsForAccount(accountId: String) throws -> [ShareConversationModel] {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            throw DBBridgingError.getConversationFailed
        }
        var conversationsToReturn = [ShareConversationModel]()

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
            let uri = ShareJamiURI.init(schema: type, infoHash: participant)
            let conversationModel = ShareConversationModel(withParticipantUri: uri,
                                                           accountId: accountId)
            if type == .sip {
                conversationModel.type = .sip
            }
            conversationModel.id = String(conversationID)
            var messages = [ShareMessageModel]()
            guard let interactions = try self.interactionHepler
                    .selectInteractionsForConversation(
                        conv: conversationID,
                        dataBase: dataBase) else {
                continue
            }
            var lastMessage: ShareMessageModel?
            for interaction in interactions {
                let author = interaction.author == participant
                    ? participant : ""
                if let message = self.convertToMessage(interaction: interaction, author: author) {
                    messages.append(message)
                    if let last = lastMessage {
                        if last.receivedDate < message.receivedDate {
                            lastMessage = message
                        }

                    } else {
                        lastMessage = message
                    }
                }
            }
            conversationModel.messages = messages
            conversationModel.lastMessage = lastMessage
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

    private func convertToMessage(interaction: Interaction, author: String) -> ShareMessageModel? {
        if interaction.type != InteractionType.text.rawValue &&
            interaction.type != InteractionType.contact.rawValue &&
            interaction.type != InteractionType.call.rawValue &&
            interaction.type != InteractionType.iTransfer.rawValue &&
            interaction.type != InteractionType.oTransfer.rawValue {
            return nil
        }
        let content = (interaction.type == InteractionType.call.rawValue
                        || interaction.type == InteractionType.contact.rawValue) ?
            GeneratedMessage(from: interaction.body).toMessage(with: Int(interaction.duration))
            : interaction.body
        let date = Date(timeIntervalSince1970: TimeInterval(interaction.timestamp))
        var message = ShareMessageModel(withId: interaction.daemonID,
                                        content: content, receivedDate: date)
        let isTransfer = interaction.type == InteractionType.iTransfer.rawValue ||
            interaction.type == InteractionType.oTransfer.rawValue
        message.messageType = InteractionType(rawValue: interaction.type)?.toMessageType() ?? .text
        message.id = String(interaction.id)
        return message
    }

    func getProfile(for profileUri: String, createIfNotExists: Bool, accountId: String,
                    alias: String? = nil, photo: String? = nil) throws -> Profile? {
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
        let profile = Profile(uri: profileUri, alias: alias, photo: photo, type: type.rawValue)
        try self.saveProfile(profile: profile, path: profilePath)
        return getProfileFromPath(path: profilePath)
    }

    private func getProfileFromPath(path: String) -> Profile? {
        guard let data = FileManager.default.contents(atPath: path),
              let profile = VCardUtils.parseToProfile(data: data) else {
            return nil
        }
        return profile
    }

    private func saveProfile(profile: Profile, path: String) throws {
        let url = URL(fileURLWithPath: path)
        let data = try VCardUtils.dataWithImageAndUUID(from: profile)
        try data?.write(to: url)
    }

    func getConversationsFor(contactUri: String, accountId: String) throws -> Int64? {
        guard let dataBase = self.dbConnections.forAccount(account: accountId) else {
            throw DBBridgingError.getConversationFailed
        }
        if let contactConversations = try self.conversationHelper
            .selectConversationsForProfile(profileUri: contactUri, dataBase: dataBase),
           let conv = contactConversations.first {
            return conv.id
        }
        return nil
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
        let conversationID = Int64.random(in: 0...10000000)
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
}
