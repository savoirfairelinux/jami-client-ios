//
//  MessageDataHelper.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SQLite

class InteractionDataHelper: DataHelperProtocol {
     static let TABLENAME = "Interactions"

     let table = Table(TABLENAME)
     let id = Expression<Int64>("id")
     let accountid = Expression<Int64>("account_id")
     let authorid = Expression<Int64>("author_id")
     let conversationid = Expression<Int64>("conversation_id")
     let timestamp = Expression<Int64>("timestamp")
     let body = Expression<String>("body")
     let type = Expression<String>("type")
     let status = Expression<String>("status")
     let daemonid = Expression<String>("daemon_id")
     typealias TableType = Interaction

     func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
                try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(accountid)
                table.column(authorid)
                table.column(conversationid)
                table.column(timestamp)
                table.column(body)
                table.column(type)
                table.column(status)
                table.column(daemonid)
            })

        } catch _ {
            print("Table already exists")
        }

    }

     func insert(item: TableType) throws -> Int64 {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }

        let insert = table.insert(accountid <- item.accountID, accountid <- item.authorID, conversationid <- item.conversationID,
                                  timestamp <- item.timestamp, body <- item.body, type <- item.type,
                                  status <- item.status, daemonid <- item.daemonID)
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
        //throw DataAccessError.nilInData

    }

     func delete (item: TableType) throws {
        guard let dataBase = RingDB.instance.ringDB  else {
            throw DataAccessError.datastoreConnectionError
        }
        let profileId = item.id
        let query = table.filter(id == profileId!)
        do {
            let run = try dataBase.run(query.delete())
            guard run == 1 else {
                throw DataAccessError.databaseError
            }
        } catch _ {
            throw DataAccessError.databaseError
        }

    }

     func find(interactionId: Int64) throws -> TableType? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == interactionId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Interaction(id: item[id], accountID: item[accountid], authorID: item[authorid],
                               conversationID: item[conversationid], timestamp: item[timestamp],
                               body: item[body], type: item[type],
                               status: item[status], daemonID: item[daemonid])
        }
        return nil
    }

     func findAll() throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var interactions = [TableType]()
        let items = try dataBase.prepare(table)
        for item in items {
            interactions.append(Interaction(id: item[id], accountID: item[accountid],
                                        authorID: item[authorid],
                                        conversationID: item[conversationid],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonid]))
        }

        return interactions
    }

     func findFor(account searchId: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(accountid == searchId)
        var interactions = [TableType]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id], accountID: item[accountid],
                                        authorID: item[authorid], conversationID: item[conversationid],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonid]))
        }
        return interactions
    }

     func findForConversation(conversationID: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(conversationid == conversationID)
        var interactions = [TableType]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id], accountID: item[accountid],
                                        authorID: item[authorid], conversationID: item[conversationid],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonid]))
        }
        return interactions
    }
}
