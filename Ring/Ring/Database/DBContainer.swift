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
    private let dbVersions = [1, 2]

    func removeDBForAccount(account: String, removeFolder: Bool) {
        self.connectionsSemaphore.wait()
        connections[account] = nil
        self.connectionsSemaphore.signal()
        if !removeFolder { return }
        self.removeAccountFolder(accountId: account)
    }

    func removeDBForAccount(account: String) {
        self.connectionsSemaphore.wait()
        connections[account] = nil
        self.connectionsSemaphore.signal()
        self.removeDBNamed(dbName: "\(account).db")
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
            connections[account]??.userVersion = dbVersions.last
            return connections[account] ?? nil
        } catch {
            log.error("Unable to open database")
            return nil
        }
    }

    // MARK: paths

    private func accountFolderPath(accountId: String) -> String? {
        guard let documents = Constants.documentsPath else { return nil }
        return documents.path + "/" + "\(accountId)" + "/"
    }

    private func accountDbPath(accountId: String) -> String? {
        guard let accountFolder = accountFolderPath(accountId: accountId) else { return nil }
        return accountFolder + "\(accountId).db"
    }

    func contactsPath(accountId: String, createIfNotExists: Bool) -> String? {
        guard let accountFolder = accountFolderPath(accountId: accountId) else { return nil }
        let profilesFolder = accountFolder + "profiles/"
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: profilesFolder) { return profilesFolder }
        if !createIfNotExists { return nil }
        do {
            try fileManager.createDirectory(atPath: profilesFolder,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        } catch {
            return nil
        }
        return fileManager.fileExists(atPath: profilesFolder) ? profilesFolder : nil
    }

    private func isDbExists(accountId: String) -> Bool {
        guard let path = accountDbPath(accountId: accountId) else { return false }
        return isFileExists(path: path)
    }

    private func isFileExists(path: String) -> Bool {
        if path.isEmpty {
            return false
        }
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }

    func contactProfilePath(accountId: String, profileURI: String, createifNotExists: Bool) -> String? {
        guard let profilesFolder = contactsPath(accountId: accountId,
                                                createIfNotExists: createifNotExists) else { return nil }
        return profilesFolder + "\(profileURI.toBase64()).vcf"
    }

    func accountProfilePath(accountId: String) -> String? {
        guard let accountFolder = accountFolderPath(accountId: accountId) else { return nil }
        return accountFolder + "profile.vcf"
    }

    func isAccountProfileExists(accountId: String) -> Bool {
        guard let path = accountProfilePath(accountId: accountId) else { return false }
        return isFileExists(path: path)
    }

    func isContactProfileExists(accountId: String, profileURI: String) -> Bool {
        guard let path = contactProfilePath(accountId: accountId, profileURI: profileURI, createifNotExists: false) else { return false }
        return isFileExists(path: path)
    }

    func removeProfile(accountId: String, profileURI: String) {
        guard let path = contactProfilePath(accountId: accountId, profileURI: profileURI, createifNotExists: false) else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch _ as NSError {}
    }

    func isMigrationToDBv2Needed(for accountId: String) -> Bool {
        if !isDbExists(accountId: accountId) { return true }
        guard let dbase = self.forAccount(account: accountId) else {
            return true
        }
        let table = Table("profiles")
        do {
            try _ = dbase.scalar(table.exists)
            return true
        } catch {
            return false
        }
    }

    private func removeDBNamed(dbName: String) {
        guard let dbPath = Constants.documentsPath else { return }
        let url = NSURL(fileURLWithPath: dbPath.path)
        guard let pathComponent = url
                .appendingPathComponent("/" + dbName) else {
            return
        }
        let filePath = pathComponent.path
        let filemManager = FileManager.default
        do {
            let fileURL = NSURL(fileURLWithPath: filePath)
            try filemManager.removeItem(at: fileURL as URL)
            print("old database deleted")
        } catch {
            print("Error on delete old database!!!")
        }
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

    func copyDbToAccountFolder(for accountId: String) -> Bool {
        if isDbExists(accountId: accountId) { return true }
        guard let dbPath = Constants.documentsPath else { return false }
        let url = NSURL(fileURLWithPath: dbPath.path)
        guard let oldPath = url.appendingPathComponent("/" + "\(accountId).db") else { return false }
        guard let newPath = accountDbPath(accountId: accountId) else { return false }
        let fileManager = FileManager.default
        do {
            try fileManager.copyItem(atPath: oldPath.path, toPath: newPath)
            return fileManager.fileExists(atPath: newPath)
        } catch _ as NSError {
            return false
        }
    }

    func removeContacts(accountId: String) {
        guard let contacts = self.contactsPath(accountId: accountId, createIfNotExists: false) else { return }
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: contacts)
        } catch _ as NSError {}
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
