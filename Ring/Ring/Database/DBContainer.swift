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

    let documentsPath = {
        return NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first
    }()

    func removeDBForAccount(account: String) {
        connections[account] = nil
        self.removeDBNamed(dbName: "\(account).db")
    }

    func forAccount(account: String) -> Connection? {
        if connections[account] != nil {
            return connections[account] ?? nil
        }
        guard let dbPath = accountDbPath(accountId: account) else { return nil }
        do {
            self.connectionsSemaphore.wait()
            connections[account] = try Connection(dbPath)
            connections[account]??.userVersion = dbVersions.last
            self.connectionsSemaphore.signal()
            return connections[account] ?? nil
        } catch {
            self.connectionsSemaphore.signal()
            log.error("Unable to open database")
            return nil
        }
    }

    // MARK: paths

    private func accountFolderPath(accountId: String) -> String {
        guard let documents = documentsPath else { return "" }
        return documents + "/" + "\(accountId)" + "/"
    }

    private func accountDbPath(accountId: String) -> String? {
        let accountFolder = accountFolderPath(accountId: accountId)
        return accountFolder.isEmpty ? nil : accountFolder + "\(accountId).db"
    }

    private func profilesFolderPath(accountId: String) -> String {
        let accountFolder = accountFolderPath(accountId: accountId)
        return accountFolder.isEmpty ? "" : accountFolder + "profiles/"
    }

    func getPathForAccountContacts(accountId: String, createIfNotExists: Bool) -> String {
        let profilesFolder = profilesFolderPath(accountId: accountId)
        if profilesFolder.isEmpty {
            return ""
        }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: profilesFolder) {
            return profilesFolder
        }
        if !createIfNotExists {
            return ""
        }

        do {
            try fileManager.createDirectory(atPath: profilesFolder,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
        } catch {
            return ""
        }
        return fileManager.fileExists(atPath: profilesFolder) ? profilesFolder : ""
    }

    private func isDBExistsInAccountFolder(accountId: String) -> Bool {
        guard let path = accountDbPath(accountId: accountId) else { return false }
        return fileExist(path: path)
    }

    private func fileExist(path: String) -> Bool {
        if path.isEmpty {
            return false
        }
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }

    func contactProfilePath(accountId: String, profileURI: String, createifNotExists: Bool) -> String? {
        let profilesFolder = getPathForAccountContacts(accountId: accountId, createIfNotExists: createifNotExists)
        return profilesFolder.isEmpty ? nil : profilesFolder + "\(profileURI.toBase64()).vcf"
    }

    func accountProfilePath(accountId: String) -> String? {
        let accountFolder = accountFolderPath(accountId: accountId)
        return accountFolder.isEmpty ? nil : accountFolder + "profile.vcf"
    }

    func accountProfileExists(accountId: String) -> Bool {
        guard let path = accountProfilePath(accountId: accountId) else { return false }
        return fileExist(path: path)
    }

    func contactProfileExists(accountId: String, profileURI: String) -> Bool {
        guard let path = contactProfilePath(accountId: accountId, profileURI: profileURI, createifNotExists: false) else { return false }
        return fileExist(path: path)
    }

    func needMigrateToDbVersion2(for accountId: String) -> Bool {
        if !isDBExistsInAccountFolder(accountId: accountId) { return true }
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
        guard let dbPath = documentsPath else { return }
        let url = NSURL(fileURLWithPath: dbPath)
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
        let accountFolder = accountFolderPath(accountId: accountId)
        if accountFolder.isEmpty { return }
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
        if isDBExistsInAccountFolder(accountId: accountId) { return true }
        guard let dbPath = documentsPath else { return false }
        let url = NSURL(fileURLWithPath: dbPath)
        guard let oldPath = url.appendingPathComponent("/" + "\(accountId).db") else { return false}
        guard let newPath = accountDbPath(accountId: accountId) else { return false }
        let fileManager = FileManager.default
        do {
            try fileManager.copyItem(atPath: oldPath.path, toPath: newPath)
            return fileManager.fileExists(atPath: newPath)
        } catch _ as NSError {
            return false
        }
    }

    func removeAllContects(accountId: String) {
        let contacts = self.profilesFolderPath(accountId: accountId)
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: contacts)
        } catch _ as NSError {}
    }
}

extension Connection {
    public var userVersion: Int? {
        get {
            if let version = try? scalar("PRAGMA user_version"),
                let intVersion =  version as? Int64 {return Int(intVersion)}
            return nil
        }
        set {
            if let version = newValue {_ = try? run("PRAGMA user_version = \(version)")}
        }
    }
}
