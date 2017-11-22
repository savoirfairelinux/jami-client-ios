//
//  ProfileDataHelper.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SQLite
import SwiftyBeaver

class ProfileDataHelper: DataHelperProtocol {
     static let TABLENAME = "Profiles"

     let table = Table(TABLENAME)
     let id = Expression<Int64>("id")
     let uri = Expression<String?>("uri")
     let alias = Expression<String>("alias")
     let photo = Expression<String>("photo")
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
        // todo validate item {
        var insert = table.insert(uri <- item.uri,
                                  type <- item.type,
                                  status <- item.status)
        if let profileAlias = item.alias {
            insert = table.insert(uri <- item.uri,
                                  alias <- profileAlias,
                                  type <- item.type,
                                  status <- item.status)
            if let profilePhoto = item.photo {
                insert = table.insert(uri <- item.uri,
                                      alias <- profileAlias,
                                      photo <- profilePhoto,
                                      type <- item.type,
                                      status <- item.status)
            }
        }
        if let profilePhoto = item.photo {
            insert = table.insert(uri <- item.uri,
                                  photo <- profilePhoto,
                                  type <- item.type,
                                  status <- item.status)
            if let profileAlias = item.alias {
                insert = table.insert(uri <- item.uri,
                                      alias <- profileAlias,
                                      photo <- profilePhoto,
                                      type <- item.type,
                                      status <- item.status)
            }
        }

        do {
            let rowId = try dataBase.run(insert)
            guard rowId > 0 else {
                throw DataAccessError.databaseError
            }
            return rowId
        } catch _ {
            throw DataAccessError.databaseError
        }
        // }
        // throw DataAccessError.nilInData

    }

    func delete (item: TableType) throws {
        guard let dataBase = RingDB.instance.ringDB  else {
            throw DataAccessError.datastoreConnectionError
        }
        if let profileId = item.id {
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
    }

    func find (profileId: Int64) throws -> TableType? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == profileId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Profile(id: item[id], uri: item[uri]!, alias: item[alias],
                           photo: item[photo], type: item[type], status: item[status])
        }
        return nil
    }

     func findAll () throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var profiles = [TableType]()
        let items = try dataBase.prepare(table)
        for item in items {
            profiles.append(Profile(id: item[id], uri: item[uri]!, alias: item[alias],
                                    photo: item[photo], type: item[type], status: item[status]))
        }

        return profiles
    }

     func findProfileByRingUri (accountURI: String) throws -> TableType? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(uri == accountURI && (type == "Ring"))
        let items = try dataBase.prepare(query)
        for item in  items {
            return Profile(id: item[id], uri: item[uri]!, alias: item[alias],
                           photo: item[photo], type: item[type], status: item[status])
        }
        return nil
    }
}
