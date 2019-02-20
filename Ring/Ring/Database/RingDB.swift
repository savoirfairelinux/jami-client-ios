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
    case databaseError
}

final class RingDB {
    static let instance = RingDB()
    let ringDB: Connection?
    private let log = SwiftyBeaver.self
    private let dbName = "ring.db"
    let dbVersion = 1

    //tables
    var tableProfiles = Table("profiles")
    var tableConversations = Table("conversations")
    var tableInteractionss = Table("interactions")
    var tableAccountProfiles = Table("profiles_accounts")

    private init() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!

        do {
            ringDB = try Connection("\(path)/" + dbName)
        } catch {
            ringDB = nil
            log.error("Unable to open database")
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
