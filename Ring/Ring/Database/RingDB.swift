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

final class RingDB {
    var jamiDB: Connection?
    private var connections = [String: Connection?]()
    private let log = SwiftyBeaver.self
    private let jamiDBName = "ring.db"
    private let path: String

    init() {
        path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!
    }

    func getJamiDB() -> Connection? {
        if jamiDB != nil {
            return jamiDB
        }
        do {
            jamiDB = try Connection("\(path)/" + jamiDBName)
        } catch {
            jamiDB = nil
            log.error("Unable to open database")
        }
        return jamiDB
    }

    func forAccount(account: String) -> Connection? {
        if connections[account] != nil {
            return connections[account] ?? nil
        }
        do {
            let accountDb = try Connection("\(path)/\(account)/" + "\(account).db")
            connections[account] = accountDb
            return accountDb
        } catch {
            log.error("Unable to open database")
            return nil
        }
    }

    func isDBExistsFor(account: String) -> Bool {
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("\(account)/" + "\(account).db") {
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
}
