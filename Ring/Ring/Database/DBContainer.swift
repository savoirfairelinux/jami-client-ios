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
    private let jamiDBName = "ring.db"
    private let path: String?
    private let dbVersions = [1, 2]

    init() {
        path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first
    }

    func getJamiDB() -> Connection? {
        if jamiDB != nil {
            return jamiDB
        }
        guard let dbPath = path else { return nil }
        do {
            jamiDB = try Connection("\(dbPath)/" + jamiDBName)
        } catch {
            jamiDB = nil
            log.error("Unable to open database")
        }
        return jamiDB
    }

    func removeJamiDB() {
        self.removeDBNamed(dbName: jamiDBName)
    }

    func removeDBForAccount(account: String) {
        connections[account] = nil
        self.removeDBNamed(dbName: "\(account).db")
    }

    func forAccount(account: String) -> Connection? {
        if connections[account] != nil {
            return connections[account] ?? nil
        }
        let accountDBPath = accountDbPath(account: account)
        if accountDBPath.isEmpty { return nil }
        do {
            self.connectionsSemaphore.wait()
            connections[account] = try Connection(accountDBPath)
            connections[account]??.userVersion = dbVersions.last
            self.connectionsSemaphore.signal()
            return connections[account] ?? nil
        } catch {
            self.connectionsSemaphore.signal()
            log.error("Unable to open database")
            return nil
        }
    }

    func accountFolderPath(account: String) -> String {
        guard let jamiFolder = path else { return "" }
        return jamiFolder + "/" + "\(account)" + "/"
    }

    func accountDbPath(account: String) -> String {
        let accountFolder = accountFolderPath(account: account)
        if accountFolder.isEmpty {
            return ""
        }
        return accountFolder + "\(account).db"
    }

    func accountProfilePath(account: String) -> String {
        let accountFolder = accountFolderPath(account: account)
        if accountFolder.isEmpty {
            return ""
        }
        return accountFolder + "profile.vcf"
    }

    func contactProfilePath(account: String, profileURI: String) -> String {
        let accountFolder = profilesFolderPath(account: account)
        if accountFolder.isEmpty {
            return ""
        }
        return accountFolder + "\(profileURI.toBase64()).vcf"
    }

    func contactProfilePath(account: String, profileURI: String, createifNotExists: Bool) -> String? {
        let profilesFolder = getPathForAccountContacts(accountID: account, createIfNotExists: createifNotExists)
        if profilesFolder.isEmpty {
            return nil
        }
        return profilesFolder + "\(profileURI.toBase64()).vcf"
    }

    func profilesFolderPath(account: String) -> String {
        let accountFolder = accountFolderPath(account: account)
        if accountFolder.isEmpty {
            return ""
        }
        return accountFolder + "profiles/"
    }

    func isDBExistsFor(account: String) -> Bool {
        guard let dbPath = path else { return false }
        let url = NSURL(fileURLWithPath: dbPath)
        guard let pathComponent = url.appendingPathComponent("/" + "\(account).db") else {
            return false
        }
        let filePath = pathComponent.path
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: filePath)
    }

    func isDBExistsInAccountFolder(account: String) -> Bool {
        let path = accountDbPath(account: account)
        return fileExist(path: path)
    }

    func accountProfileExists(account: String) -> Bool {
        let path = accountProfilePath(account: account)
        return fileExist(path: path)
    }

    func contactProfileExists(account: String, profileURI: String) -> Bool {
        let path = contactProfilePath(account: account, profileURI: profileURI)
        return fileExist(path: path)
    }

    func fileExist(path: String) -> Bool {
        if path.isEmpty {
            return false
        }
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: path)
    }

    func needMigrateToDB2(for accountID: String) -> Bool {
        guard let dbase = self.forAccount(account: accountID) else {
            return true
        }
        let table = Table("profiles")
        do {
            try dbase.scalar(table.exists)
            return true
        } catch {
            return false
        }
    }

    func dbMovedToAccountFolder(for accountID: String) -> Bool {
        return isDBExistsInAccountFolder(account: accountID)
    }

    func needMigrateToDB1(for accountID: String) -> Bool {
        return !isDBExistsFor(account: accountID) && !isDBExistsInAccountFolder(account: accountID)
    }

    private func removeDBNamed(dbName: String) {
        guard let dbPath = path else { return }
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

//    func getDBPathForAccount(accountID: String) -> String {
//        var dbPathForAccount = ""
//        guard let dbPath = path else { return dbPathForAccount }
//        let url = NSURL(fileURLWithPath: dbPath)
//        guard let pathComponent = url
//            .appendingPathComponent("/" + "\(accountID)" + "/", isDirectory: true) else {
//                return dbPathForAccount
//        }
//        dbPathForAccount = pathComponent.path
//        return dbPathForAccount
//    }

    func moveDbToAccountFolder(for accountID: String) -> Bool {
        guard let dbPath = path else { return false }
        let url = NSURL(fileURLWithPath: dbPath)
        guard let oldPath = url.appendingPathComponent("/" + "\(accountID).db") else { return false}
        let newPath = accountDbPath(account: accountID)
        if newPath.isEmpty {
            return false
        }
        let fileManager = FileManager.default
        do {
            try fileManager.copyItem(atPath: oldPath.path, toPath: newPath)
            return fileManager.fileExists(atPath: newPath)
        }
        catch _ as NSError {
            return false
        }
    }

    func getPathForAccountContacts(accountID: String, createIfNotExists: Bool) -> String {
        let profilesFolder = profilesFolderPath(account: accountID)
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
