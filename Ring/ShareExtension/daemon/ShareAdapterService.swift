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

import RxCocoa
import RxSwift
import UIKit
import MobileCoreServices
import Photos
import os
import SwiftyBeaver

class ShareAdapterService {

    private let log = SwiftyBeaver.self

    private let maxSizeForAutoaccept = 20 * 1024 * 1024

    private var adapter: ShareAdapter!

    let dbManager: ShareDBManager

    // Account Service
    private var accountList: [ShareAccountModel] = [] {
        didSet {
            self.currentAccount = self.accountList.first
        }
    }
    var currentAccount: ShareAccountModel?
    var accountsObservable = BehaviorRelay<[ShareAccountModel]>(value: [ShareAccountModel]())
    // Conversation Service
    var conversations = BehaviorRelay(value: [("", [ShareConversationModel]())])
    private var conversationList: [(String, [ShareConversationModel])] = []
    // Profile Service
    var profiles = [String: ReplaySubject<Profile>]()

    private var disposeBag = DisposeBag()

    init(withAdapter adapter: ShareAdapter, dbManager: ShareDBManager) {
        self.adapter = adapter
        self.dbManager = dbManager
    }

    func start() {
        self.adapter.start()
    }

    func removeDelegate() {
        self.adapter = nil
    }

    func stop() {
        self.adapter.stop()
        removeDelegate()
    }

    // MARK: - Account Service

    private func loadAccountsFromDaemon() {
        let selectedAccount = self.currentAccount
        self.accountList.removeAll()
        for accountId in adapter.getAccountList() {
            if  let id = accountId as? String {
                self.accountList.append(ShareAccountModel(withAccountId: id))
            }
        }
        self.reloadAccounts()
        accountsObservable.accept(self.accountList)
        if selectedAccount != nil {
            let currentAccount = self.accountList.filter({ account in
                return account == selectedAccount
            }).first
            if let currentAccount = currentAccount,
               let index = self.accountList.firstIndex(of: currentAccount) {
                self.accountList.remove(at: index)
                self.accountList.insert(currentAccount, at: 0)
            }
        }
    }

    private func reloadAccounts() {
        conversationList = []
        var currentConversations = [ShareConversationModel]()
        for account in accountList {
            account.details = self.getAccountDetails(fromAccountId: account.id)
            var accountName = ShareAccountModelHelper(withAccount: account).displayName ?? account.jamiId

            getConversationsForAccount(accountName: accountName, accountId: account.id, accountURI: account.jamiId)
        }

        conversations.accept(conversationList)
    }

    func loadAccounts() -> Single<[ShareAccountModel]> {
        return Single<[ShareAccountModel]>.just({
            loadAccountsFromDaemon()
            return accountList
        }())
    }
}

// MARK: Account Service
extension ShareAdapterService {
    func isJams(for accountId: String) -> Bool {
        guard let account = self.getAccount(fromAccountId: accountId) else { return false }
        return account.isJams
    }

    /**
     Gets an account from the list of accounts handled by the application.

     - Parameter id: the id of the account to get.

     - Returns: the account if found, nil otherwise.
     */
    func getAccount(fromAccountId id: String) -> ShareAccountModel? {
        for account in self.accountList
        where id.compare(account.id) == ComparisonResult.orderedSame {
            return account
        }
        return nil
    }

    /**
     Gets all the details of an account from the daemon.

     - Parameter id: the id of the account.

     - Returns: the details of the account.
     */
    func getAccountDetails(fromAccountId id: String) -> AccountConfigModel {
        let details: NSDictionary = adapter.getAccountDetails(id) as NSDictionary
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        return accountDetails
    }
}

// MARK: - Converstion Service
extension ShareAdapterService {
    private func addSwarm(conversationId: String, accountId: String, accountURI: String, to conversations: inout [ShareConversationModel]) {
        if let info = adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String],
           let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            let conversation = ShareConversationModel(withId: conversationId, accountId: accountId, info: info)
            conversation.addParticipantsFromArray(participantsInfo: participantsInfo, accountURI: accountURI)
            conversations.append(conversation)
        }
    }

    /**
     Called when application starts and when  account changed
     */
    func getConversationsForAccount(accountName: String, accountId: String, accountURI: String) {
        /* if we don't have conversation that could mean the app
         just launched and we need symchronize messages status
         */
        var currentConversations = [ShareConversationModel]()
        // get swarms conversations
        if let swarmIds = adapter.getSwarmConversations(forAccount: accountId) as? [String] {
            for swarmId in swarmIds {
                self.addSwarm(conversationId: swarmId, accountId: accountId, accountURI: accountURI, to: &currentConversations)
            }
        }
        conversationList.append((accountName, currentConversations))
    }

    func getSwarmMembers(conversationId: String, accountId: String, accountURI: String) -> [ShareParticipantInfo] {
        if let participantsInfo = adapter.getConversationMembers(accountId, conversationId: conversationId) {
            return participantsInfo.compactMap({ info in
                if let jamiId = info["uri"],
                   let roleText = info["role"] {
                    var role = ParticipantRole.member
                    switch roleText {
                    case "admin":
                        role = .admin
                    case "member":
                        role = .member
                    case "invited":
                        role = .invited
                    case "banned":
                        role = .banned
                    default:
                        role = .unknown
                    }
                    return ShareParticipantInfo(jamiId: jamiId, role: role)
                }
                return nil
            })
        }
        return []
    }

    func getConversationInfo(conversationId: String, accountId: String) -> [String: String] {
        return adapter.getConversationInfo(forAccount: accountId, conversationId: conversationId) as? [String: String] ?? [String: String]()
    }
}

// MARK: - Profile Service
extension ShareAdapterService {
    func getProfile(uri: String, createIfNotexists: Bool, accountId: String) -> Observable<Profile> {
        if let profile = self.profiles[uri] {
            return profile.asObservable().share()
        }
        let profileObservable = ReplaySubject<Profile>.create(bufferSize: 1)
        self.profiles[uri] = profileObservable
        return profileObservable.share()
    }
}

// MARK: - Send Message and File
extension ShareAdapterService {
    func sendFile(conversation: ShareConversationModel, filePath: String, displayName: String, localIdentifier: String?) {
        self.adapter.sendSwarmFile(withName: displayName,
                                   accountId: conversation.accountId,
                                   conversationId: conversation.id,
                                   withFilePath: filePath,
                                   parent: "")
    }

    func sendAndSaveFile(displayName: String, conversation: ShareConversationModel, imageData: Data) {
        var fileUrl: URL?
        if !conversation.isSwarm() {
            fileUrl = self.getFilePathForTransfer(forFile: displayName, accountID: conversation.accountId, conversationID: conversation.id)
        } else {
            fileUrl = self.createFileUrlForSwarm(fileName: displayName, accountID: conversation.accountId, conversationID: conversation.id)
        }
        guard let imagePath = fileUrl else {
            self.log.error("Failed to create file URL")
            return
        }
        // Check if the file's directory exists, and if not, create it.
        let directoryPath = imagePath.deletingLastPathComponent().path
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory)
        if !directoryExists || !isDirectory.boolValue {
            do {
                try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                self.log.error("Failed to create directory at path: \(directoryPath), error: \(error)")
                return
            }
        }
        // Now write the image data to the file.
        do {
            try imageData.write(to: imagePath, options: .atomic)
        } catch {
            self.log.error("Couldn't write image data to file at path: \(imagePath.path), error: \(error)")
            return
        }
        self.sendFile(conversation: conversation, filePath: imagePath.path, displayName: displayName, localIdentifier: nil)
    }

    private func getFilePathForTransfer(forFile fileName: String, accountID: String, conversationID: String) -> URL? {
        return self.createFileUrlForDirectory(directory: Directories.downloads.rawValue,
                                              fileName: fileName,
                                              accountID: accountID,
                                              conversationID: conversationID)
    }

    /// create url to save file before sending for swarm conversation
    func createFileUrlForSwarm(fileName: String, accountID: String, conversationID: String) -> URL? {
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(accountID)
            .appendingPathComponent(Directories.conversation_data.rawValue)
            .appendingPathComponent(conversationID)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            // check if file exists, if so add " (<duplicates+1>)" or "_<duplicates+1>"
            // first check /.../AppData/Documents/directory/<fileNameOnly>.<fileExtensionOnly>
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                // check /.../AppData/Documents/directory/<fileNameOnly>_<duplicates>.<fileExtensionOnly>
                finalFileName = fileNameOnly + "_" + String(duplicates) + "." + fileExtensionOnly
                filePathCheck = directoryURL.appendingPathComponent(finalFileName)
                fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
                duplicates += 1
            }
            return filePathCheck
        }
        return nil
    }

    /// create url to save file before sending for non swarm conversation
    private func createFileUrlForDirectory(directory: String, fileName: String, accountID: String, conversationID: String) -> URL? {
        let folderName = directory
        let fileNameOnly = (fileName as NSString).deletingPathExtension
        let fileExtensionOnly = (fileName as NSString).pathExtension
        var filePathUrl: URL?
        guard let documentsURL = Constants.documentsPath else {
            return nil
        }
        let directoryURL = documentsURL.appendingPathComponent(folderName)
            .appendingPathComponent(accountID)
            .appendingPathComponent(conversationID)
        var isDirectory = ObjCBool(false)
        let directoryExists = FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        if directoryExists && isDirectory.boolValue {
            if directory == Directories.recorded.rawValue {
                return directoryURL.appendingPathComponent(fileName, isDirectory: false)
            }
            // check if file exists, if so add " (<duplicates+1>)" or "_<duplicates+1>"
            // first check /.../AppData/Documents/directory/<fileNameOnly>.<fileExtensionOnly>
            var finalFileName = fileNameOnly + "." + fileExtensionOnly
            var filePathCheck = directoryURL.appendingPathComponent(finalFileName)
            var fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
            var duplicates = 2
            while fileExists {
                // check /.../AppData/Documents/directory/<fileNameOnly>_<duplicates>.<fileExtensionOnly>
                finalFileName = fileNameOnly + "_" + String(duplicates) + "." + fileExtensionOnly
                filePathCheck = directoryURL.appendingPathComponent(finalFileName)
                fileExists = FileManager.default.fileExists(atPath: filePathCheck.path, isDirectory: &isDirectory)
                duplicates += 1
            }
            return filePathCheck
        }
        // need to create dir
        do {
            try FileManager.default.createDirectory(atPath: directoryURL.path, withIntermediateDirectories: true, attributes: nil)
            filePathUrl = directoryURL.appendingPathComponent(fileName, isDirectory: false)
            return filePathUrl
        } catch _ as NSError {
            self.log.error("DataTransferService: error creating dir")
            return nil
        }
    }
}
