/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

typealias Profile = (
    id: Int64,
    uri: String,
    alias: String?,
    photo: String?,
    type: String,
    status: String
)

class ProfileDataHelper {
    static let TABLENAME = "profiles"

    let table = Table(TABLENAME)
    let id = Expression<Int64>("id")
    let uri = Expression<String>("uri")
    let alias = Expression<String?>("alias")
    let photo = Expression<String?>("photo")
    let type = Expression<String>("type")
    let status = Expression<String>("status")
    private let log = SwiftyBeaver.self

    func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
            try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(uri)
                table.column(alias)
                table.column(photo)
                table.column(type)
                table.column(status)
            })
        } catch _ {
            log.error("Table exists")
        }
    }

    func insert(item: Profile) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }

        let insert = table.insert(uri <- item.uri,
                                  alias <- item.alias,
                                  photo <- item.photo,
                                  type <- item.type,
                                  status <- item.status)
        do {
            let rowId = try dataBase.run(insert)
            guard rowId > 0 else {
                return false
            }
            return true
        } catch _ {
            return false
        }

    }

    func delete(item: Profile) -> Bool {
        guard let dataBase = RingDB.instance.ringDB  else {
            return false
        }
        let profileId = item.id
        let query = table.filter(id == profileId)
        do {
            let deletedRow = try dataBase.run(query.delete())
            guard deletedRow == 1 else {
                return false
            }
            return true
        } catch _ {
            return false
        }
    }

    func selectProfile(profileId: Int64) throws -> Profile? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == profileId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Profile(id: item[id], uri: item[uri], alias: item[alias],
                           photo: item[photo], type: item[type], status: item[status])
        }
        return nil
    }

    func selectAll() throws -> [Profile]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var profiles = [Profile]()
        let items = try dataBase.prepare(table)
        for item in items {
            profiles.append(Profile(id: item[id], uri: item[uri], alias: item[alias],
                                    photo: item[photo], type: item[type], status: item[status]))
        }
        return profiles
    }

    func selectProfile(accountURI: String) throws -> Profile? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(uri == accountURI)
        let items = try dataBase.prepare(query)
        // for one URI we should have only one profile
        for item in  items {
            return Profile(id: item[id], uri: item[uri], alias: item[alias],
                           photo: item[photo], type: item[type], status: item[status])
        }
        return nil
    }
}



