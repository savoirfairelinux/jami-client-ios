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
     static let TABLENAME = "interactions"

     let table = Table(TABLENAME)
     let id = Expression<Int64>("id")
     let accountId = Expression<Int64>("account_id")
     let authorId = Expression<Int64>("author_id")
     let conversationId = Expression<Int64>("conversation_id")
     let timestamp = Expression<Int64>("timestamp")
     let body = Expression<String>("body")
     let type = Expression<String>("type")
     let status = Expression<String>("status")
     let daemonId = Expression<String>("daemon_id")
     typealias TableType = Interaction

     func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
                try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(accountId)
                table.column(authorId)
                table.column(conversationId)
                table.column(timestamp)
                table.column(body)
                table.column(type)
                table.column(status)
                table.column(daemonId)
            })

        } catch _ {
            print("Table already exists")
        }

    }

     func insert(item: TableType) throws -> Int64 {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }

        let insert = table.insert(accountId <- item.accountID, accountId <- item.authorID, conversationId <- item.conversationID,
                                  timestamp <- item.timestamp, body <- item.body, type <- item.type,
                                  status <- item.status, daemonId <- item.daemonID)
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

     func selectInteraction (where interactionId: Int64) throws -> TableType? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == interactionId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Interaction(id: item[id], accountID: item[accountId], authorID: item[authorId],
                               conversationID: item[conversationId], timestamp: item[timestamp],
                               body: item[body], type: item[type],
                               status: item[status], daemonID: item[daemonId])
        }
        return nil
    }

     func selectAll() throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var interactions = [TableType]()
        let items = try dataBase.prepare(table)
        for item in items {
            interactions.append(Interaction(id: item[id], accountID: item[accountId],
                                        authorID: item[authorId],
                                        conversationID: item[conversationId],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonId]))
        }

        return interactions
    }

     func selectInteractionsForAccount (where accountID: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(accountId == accountID)
        var interactions = [TableType]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id], accountID: item[accountId],
                                        authorID: item[authorId], conversationID: item[conversationId],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonId]))
        }
        return interactions
    }

     func selectInteractionsForConversation (where conversationID: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(conversationId == conversationID)
        var interactions = [TableType]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id], accountID: item[accountId],
                                        authorID: item[authorId], conversationID: item[conversationId],
                                        timestamp: item[timestamp], body: item[body],
                                        type: item[type], status: item[status],
                                        daemonID: item[daemonId]))
        }
        return interactions
    }
}
