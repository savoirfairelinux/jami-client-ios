//
//  ConversationDataHepler.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SQLite

class ConversationDataHelper: DataHelperProtocol {
     static let TABLENAME = "conversations"

     let table = Table(TABLENAME)
     let id = Expression<Int64>("id")
     let participantId = Expression<Int64>("participant_id")
    typealias TableType = Conversation

     func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
            try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(id)
                table.column(participantId)
            })

        } catch _ {
            print("Table already exists")
        }

    }

     func insert(item: TableType) throws -> Int64 {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        // TODO validate item {
        let insert = table.insert(id <- item.id, participantId <- item.participantID)
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
         let conversationId = item.id
            let query = table.filter(id == conversationId)
            do {
                let run = try dataBase.run(query.delete())
                guard run == 1 else {
                    throw DataAccessError.databaseError
                }
            } catch _ {
                throw DataAccessError.databaseError
            }

    }

     func find(conversationId: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == conversationId)
        var conversations = [TableType]()
        let items = try dataBase.prepare(query)
        for item in  items {
             conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }
        return conversations
    }

     func findAll() throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var conversations = [TableType]()
        let items = try dataBase.prepare(table)
        for item in items {
            conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }

        return conversations
    }

     func findConversationForAccount(profileId: Int64) throws -> [TableType]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var conversations = [TableType]()
        let query = table.filter(id == profileId)
        let items = try dataBase.prepare(query)
        for item in  items {
             conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }
         return conversations
    }
}
