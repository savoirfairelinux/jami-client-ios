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
    private let dbVersion = 1

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
        guard let dbPath = path else { return nil }
        do {
            self.connectionsSemaphore.wait()
            connections[account] = try Connection("\(dbPath)/" + "\(account).db")
            connections[account]??.userVersion = dbVersion
            self.connectionsSemaphore.signal()
            return connections[account] ?? nil
        } catch {
            self.connectionsSemaphore.signal()
            log.error("Unable to open database")
            return nil
        }
    }

    func isDBExistsFor(account: String) -> Bool {
        guard let dbPath = path else { return false }
        let url = NSURL(fileURLWithPath: dbPath)
        if let pathComponent = url.appendingPathComponent("/" + "\(account).db") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                return false
            } else {
                return true
            }
        } else {
            return true
        }
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
