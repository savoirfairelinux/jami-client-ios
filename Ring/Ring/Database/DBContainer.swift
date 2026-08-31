/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
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

import SQLite
import SwiftyBeaver

// ================================================================================
// jami files structure
//
// Jami Documents folder
// └──{ account_id }
// ├── config.yml
// ├── contacts
// ├── archive.gz
// ├── incomingTrustRequests
// ├── knownDevicesNames
// ├── { account_id }.db < --conversations and interactions database
// ├── profile.vcf < --account vcard
// ├── profiles < --account contact vcards
// │   │──{ contact_uri }.vcf
// │   └── ...
// ├── ring_device.crt
// └── ring_device.key
// ================================================================================

enum DataAccessError: Error {
    case datastoreConnectionError
    case databaseMigrationError
    case databaseError
}

final class DBContainer {
    var jamiDB: Connection?
    private var connections = [String: Connection?]()
    var connectionsSemaphore = DispatchSemaphore(value: 1)
    private let log = SwiftyBeaver.self
    private let dbVersion = 2
    private let provisionalProfilesLock = NSLock()

    func removeDBForAccount(account: String, removeFolder: Bool) {
        self.connectionsSemaphore.wait()
        connections[account] = nil
        self.connectionsSemaphore.signal()
        if !removeFolder { return }
        self.removeAccountFolder(accountId: account)
    }

    func forAccount(account: String) -> Connection? {
        self.connectionsSemaphore.wait()
        defer {
            self.connectionsSemaphore.signal()
        }
        if connections[account] != nil {
            return connections[account] ?? nil
        }
        guard let dbPath = accountDbPath(accountId: account) else { return nil }
        do {
            connections[account] = try Connection(dbPath)
            connections[account]??.userVersion = dbVersion
            return connections[account] ?? nil
        } catch {
            log.error("Unable to open database")
            return nil
        }
    }

    // MARK: paths

    private func accountFolderPath(accountId: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.accountFolderPath(accountId: accountId, documents: documents)
    }

    private func accountDbPath(accountId: String) -> String? {
        guard let accountFolder = accountFolderPath(accountId: accountId) else { return nil }
        return accountFolder + "\(accountId).db"
    }

    func contactsPath(accountId: String, createIfNotExists: Bool) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.contactsPath(accountId: accountId,
                                              documents: documents,
                                              createIfNotExists: createIfNotExists)
    }

    private func isFileExists(path: String) -> Bool {
        if path.isEmpty {
            return false
        }
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }

    func existingContactProfilePath(accountId: String, profileURI: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.existingContactProfilePath(accountId: accountId,
                                                            contactId: profileURI,
                                                            documents: documents)
    }

    func contactProfilePath(accountId: String, profileURI: String) -> String? {
        guard let documents = Constants.documentsPath,
              let path = ProfilePathHelper.contactProfilePath(accountId: accountId,
                                                              contactId: profileURI,
                                                              documents: documents),
              FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    func legacyContactProfilePath(accountId: String, profileURI: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.profileURICandidates(for: profileURI)
            .compactMap {
                ProfilePathHelper.legacyContactProfilePath(accountId: accountId,
                                                           profileURI: $0,
                                                           documents: documents)
            }
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    func contactProfileOverridePath(accountId: String,
                                    profileURI: String,
                                    createIfNotExists: Bool) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.contactProfileOverridePath(accountId: accountId,
                                                            profileURI: profileURI,
                                                            documents: documents,
                                                            createIfNotExists: createIfNotExists)
    }

    func accountProfilePath(accountId: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return ProfilePathHelper.accountProfilePath(accountId: accountId, documents: documents)
    }

    func isAccountProfileExists(accountId: String) -> Bool {
        guard let path = accountProfilePath(accountId: accountId) else { return false }
        return isFileExists(path: path)
    }

    func removeProfile(accountId: String, profileURI: String) {
        if let documents = Constants.documentsPath {
            // The canonical raw-hash vCard is owned by libjami. Remove only
            // obsolete URI-named copies previously created by the client.
            let paths = ProfilePathHelper.profileURICandidates(for: profileURI).map {
                ProfilePathHelper.legacyContactProfilePath(accountId: accountId,
                                                           profileURI: $0,
                                                           documents: documents)
            }
            for path in paths.compactMap({ $0 }) {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        removeProfileOverride(accountId: accountId, profileURI: profileURI)
    }

    func provisionalProfile(accountId: String, profileURI: String) -> Profile? {
        guard let documents = Constants.documentsPath,
              let path = ProfilePathHelper.provisionalProfilePath(accountId: accountId,
                                                                  profileURI: profileURI,
                                                                  documents: documents,
                                                                  createIfNotExists: false) else { return nil }
        provisionalProfilesLock.lock()
        defer { provisionalProfilesLock.unlock() }
        guard let profile = VCardUtils.parseToProfile(filePath: path), !profile.isEmpty else { return nil }
        return profile
    }

    func saveProvisionalProfile(_ profile: Profile, accountId: String) -> Bool {
        guard !profile.isEmpty,
              let documents = Constants.documentsPath,
              let path = ProfilePathHelper.provisionalProfilePath(accountId: accountId,
                                                                  profileURI: profile.uri,
                                                                  documents: documents,
                                                                  createIfNotExists: true),
              let data = VCardUtils.dataForLocalOverride(profile) else { return false }
        provisionalProfilesLock.lock()
        defer { provisionalProfilesLock.unlock() }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func removeProvisionalProfile(accountId: String, profileURI: String) {
        guard let documents = Constants.documentsPath,
              let path = ProfilePathHelper.provisionalProfilePath(accountId: accountId,
                                                                  profileURI: profileURI,
                                                                  documents: documents,
                                                                  createIfNotExists: false) else { return }
        provisionalProfilesLock.lock()
        defer { provisionalProfilesLock.unlock() }
        try? FileManager.default.removeItem(atPath: path)
    }

    private func removeProvisionalProfiles(accountId: String) {
        guard let documents = Constants.documentsPath else { return }
        let path = ProfilePathHelper.provisionalProfilesPath(accountId: accountId, documents: documents)
        provisionalProfilesLock.lock()
        defer { provisionalProfilesLock.unlock() }
        try? FileManager.default.removeItem(atPath: path)
    }

    func removeProfileOverride(accountId: String, profileURI: String) {
        guard let path = contactProfileOverridePath(accountId: accountId,
                                                    profileURI: profileURI,
                                                    createIfNotExists: false) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    func createAccountfolder(for accountId: String) {
        guard let accountFolder = accountFolderPath(accountId: accountId) else { return }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: accountFolder) { return }
        do {
            try fileManager.createDirectory(atPath: accountFolder,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        } catch {
            return
        }
    }

    func removeContacts(accountId: String) {
        if let contacts = self.contactsPath(accountId: accountId, createIfNotExists: false) {
            try? FileManager.default.removeItem(atPath: contacts)
        }
        removeProvisionalProfiles(accountId: accountId)
    }

    func removeAccountFolder(accountId: String) {
        guard let account = self.accountFolderPath(accountId: accountId) else { return }
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: account)
        } catch _ as NSError {}
    }
}

extension Connection {
    public var userVersion: Int? {
        get {
            if let version = try? scalar("PRAGMA user_version"),
               let intVersion = version as? Int64 { return Int(intVersion) }
            return nil
        }
        set {
            if let version = newValue { _ = try? run("PRAGMA user_version = \(version)") }
        }
    }
}
