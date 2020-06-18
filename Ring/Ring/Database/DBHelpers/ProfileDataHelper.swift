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

typealias Profile = (
    uri: String,
    alias: String?,
    photo: String?,
    type: String
)

final class ProfileDataHelper {
    let contactsProfileTable = Table("profiles")
    let accountProfileTable = Table("account_profile")
    let uri = Expression<String>("uri")
    let alias = Expression<String?>("alias")
    let photo = Expression<String?>("photo")
    let type = Expression<String>("type")
    private let log = SwiftyBeaver.self

    //migrate from legacy db
//    let id = Expression<Int64>("id")
//    func getLegacyProfileID(profileURI: String, dataBase: Connection) throws -> Int64? {
//        let query = contactsProfileTable.filter(uri == profileURI)
//        let items = try dataBase.prepare(query)
//        for item in  items {
//            return item[id]
//        }
//        return nil
//    }
//    func getLegacyProfiles(accountURI: String,
//                           accountId: String,
//                           database: Connection) throws -> [Int64: String] {
//        let query = contactsProfileTable.filter(accountId != uri && accountURI != uri)
//        let items = try database.prepare(query)
//        var profiles = [Int64: String]()
//        for item in  items {
//            profiles[item[id]] = item[uri]
//        }
//        return profiles
//    }
//    func migrateToDBForAccount (from oldDB: Connection,
//                                to newDB: Connection,
//                                jamiId: String,
//                                accountId: String) throws {
//        // migrate account profile
//        // get account profile, it should be only one
//        let accountQuery = contactsProfileTable.filter(uri == jamiId)
//        let items = try oldDB.prepare(accountQuery)
//        for item in  items {
//            let query = accountProfileTable.insert(alias <- item[alias],
//                                                   photo <- item[photo])
//            try newDB.run(query)
//        }
//
//        //migrate contacts rofiles
//        let contactQuery = contactsProfileTable.filter((uri != jamiId) && (uri != accountId))
//        let rows = try oldDB.prepare(contactQuery)
//        for row in  rows {
//            let query = contactsProfileTable.insert(uri <- "ring:" + row[uri],
//                                                    alias <- row[alias],
//                                                    photo <- row[photo],
//                                                    type <- row[type])
//            try newDB.run(query)
//        }
//    }

//    func createAccountTable(accountDb: Connection) {
//        do {
//            try accountDb.run(accountProfileTable.create(ifNotExists: true) { table in
//                table.column(alias)
//                table.column(photo)
//            })
//        } catch _ {
//            print("Table already exists")
//        }
//    }

    func dropAccountTable(accountDb: Connection) {
        do {
            try accountDb.run(accountProfileTable.drop(ifExists: true))
        } catch {
            debugPrint(error)
        }
    }

    func dropProfileTable(accountDb: Connection) {
        do {
            try accountDb.run(contactsProfileTable.drop(ifExists: true))
        } catch {
            debugPrint(error)
        }
    }

//    func updateAccountProfile(accountAlias: String?, accountPhoto: String?, dataBase: Connection) -> Bool {
//        do {
//            if try dataBase.pluck(accountProfileTable) != nil {
//                try dataBase.run(accountProfileTable.update(alias <- accountAlias,
//                                                            photo <- accountPhoto))
//            } else {
//                try dataBase.run(accountProfileTable.insert(alias <- accountAlias,
//                                                            photo <- accountPhoto))
//            }
//            return true
//        } catch {
//            return false
//        }
//    }

    func getAccountProfile(dataBase: Connection) -> Profile? {
        do {
            guard let row = try dataBase.pluck(accountProfileTable) else { return nil}
            return Profile("", row[alias], row[photo], ProfileType.ring.rawValue)
        } catch {
            return nil
        }
    }
//
//    func createContactsTable(accountDb: Connection) {
//        do {
//            try accountDb.run(contactsProfileTable.create(ifNotExists: true) { table in
//                table.column(uri, unique: true)
//                table.column(alias)
//                table.column(photo)
//                table.column(type)
//            })
//            try accountDb.run(contactsProfileTable.createIndex(uri))
//        } catch _ {
//            print("Table already exists")
//        }
//    }

//    func insert(item: Profile, dataBase: Connection) -> Bool {
//        let query = contactsProfileTable.insert(uri <- item.uri,
//                                  alias <- item.alias,
//                                  photo <- item.photo,
//                                  type <- item.type)
//        do {
//            let rowId = try dataBase.run(query)
//            guard rowId > 0 else {
//                return false
//            }
//            return true
//        } catch _ {
//            return false
//        }
//    }

//    func delete(item: Profile, dataBase: Connection) -> Bool {
//        let profileUri = item.uri
//        let query = contactsProfileTable.filter(uri == profileUri)
//        do {
//            let deletedRows = try dataBase.run(query.delete())
//            guard deletedRows == 1 else {
//                return false
//            }
//            return true
//        } catch _ {
//            return false
//        }
//    }

    func selectAll(dataBase: Connection) throws -> [Profile]? {
        var profiles = [Profile]()
        let items = try dataBase.prepare(contactsProfileTable)
        for item in items {
            profiles.append(Profile(uri: item[uri], alias: item[alias],
                                    photo: item[photo], type: item[type]))
        }
        return profiles
    }

//    func selectProfile(profileURI: String, dataBase: Connection) throws -> Profile? {
//        let query = contactsProfileTable.filter(uri == profileURI)
//        let items = try dataBase.prepare(query)
//        // for one URI we should have only one profile
//        for item in  items {
//            return Profile(uri: item[uri], alias: item[alias],
//                           photo: item[photo], type: item[type])
//        }
//        return nil
//    }

//    func insertOrUpdateProfile(item: Profile, dataBase: Connection) throws {
//        try dataBase.transaction {
//            let selectQuery = contactsProfileTable.filter(uri == item.uri)
//            let rows = try dataBase.run(selectQuery.update(alias <- item.alias,
//                                                           photo <- item.photo))
//            if rows > 0 {
//                return
//            }
//            let insertQuery = contactsProfileTable.insert(uri <- item.uri,
//                                           alias <- item.alias,
//                                           photo <- item.photo,
//                                           type <- item.type)
//            let rowId = try dataBase.run(insertQuery)
//            guard rowId > 0 else {
//                throw DataAccessError.databaseError
//            }
//        }
//    }
//
//    func deleteAll(dataBase: Connection) -> Bool {
//        do {
//            if try dataBase.run(contactsProfileTable.delete()) > 0 {
//                return true
//            } else {
//                return false
//            }
//        } catch {
//            return false
//        }
//    }
}
