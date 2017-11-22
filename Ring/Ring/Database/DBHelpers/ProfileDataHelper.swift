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

class ProfileDataHelper: DataHelperProtocol {
     static let TABLENAME = "profiles"

     let table = Table(TABLENAME)
     let id = Expression<Int64>("id")
     let uri = Expression<String>("uri")
     let alias = Expression<String?>("alias")
     let photo = Expression<String?>("photo")
     let type = Expression<String>("type")
     let status = Expression<String>("status")
     typealias TableType = Profile
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

    func insert(item: TableType) throws -> Int64 {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }

        let insert = table.insert(uri <- item.uri,
                                  alias <- item.alias,
                                  photo <- item.photo,
                                  type <- item.type,
                                  status <- item.status)
        do {
            let rowId = try dataBase.run(insert)
            guard rowId > 0 else {
                throw DataAccessError.databaseError
            }
            return rowId
        } catch _ {
            throw DataAccessError.databaseError
        }

    }

    func delete (item: TableType) throws {
        guard let dataBase = RingDB.instance.ringDB  else {
            throw DataAccessError.datastoreConnectionError
        }
         let profileId = item.id
            let query = table.filter(id == profileId)
            do {
                let run = try dataBase.run(query.delete())
                guard run == 1 else {
                    throw DataAccessError.databaseError
                }
            } catch _ {
                throw DataAccessError.databaseError
            }
    }

    func selectProfile (profileId: Int64) throws -> TableType? {
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

     func selectAll () throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var profiles = [TableType]()
        let items = try dataBase.prepare(table)
        for item in items {
            profiles.append(Profile(id: item[id], uri: item[uri], alias: item[alias],
                                    photo: item[photo], type: item[type], status: item[status]))
        }

        return profiles
    }

     func selectRingProfile (accountURI: String) throws -> TableType? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(uri == accountURI && (type == ProfileType.ring.rawValue))
        let items = try dataBase.prepare(query)
        for item in  items {
            return Profile(id: item[id], uri: item[uri], alias: item[alias],
                           photo: item[photo], type: item[type], status: item[status])
        }
        return nil
    }
}
