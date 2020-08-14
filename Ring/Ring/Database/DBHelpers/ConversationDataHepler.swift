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

typealias Conversation = (
    id: Int64,
    participant: String
)

final class ConversationDataHelper {
    let table = Table("conversations")
    let id = Expression<Int64>("id")
    let participant = Expression<String>("participant")

    // reference foreign key
    let tableProfiles = Table("profiles")
    let uri = Expression<String>("uri")

    // to migrate from legacy db
    let participantId = Expression<Int64>("participant_id")

    func migrateToDBForAccount(from oldDB: Connection,
                               to newDB: Connection,
                               accountProfileId: Int64,
                               contactsMap: [Int64: String]) throws {
        let query = table.filter(accountProfileId != participantId)
        let items = try oldDB.prepare(query)
        for item in  items {
            if let uri = contactsMap[item[participantId]] {
                let query = table.insert(id <- item[id],
                                         participant <- "ring:" + uri)
                try newDB.run(query)
            }
        }
    }

    func createTable(accountDb: Connection) {
        do {
            try accountDb.run(table.create(ifNotExists: true) { table in
                table.column(id)
                table.column(participant)
                table.foreignKey(participant, references: tableProfiles, uri, delete: .noAction)
            })
        } catch _ {
            print("Table already exists")
        }
    }

    func insert(item: Conversation, dataBase: Connection) -> Bool {
        let query = table.insert(id <- item.id,
                                 participant <- item.participant)
        do {
            let rowId = try dataBase.run(query)
            guard rowId > 0 else {
                return false
            }
            return true
        } catch _ {
            return false
        }
    }

    func delete (item: Conversation, dataBase: Connection) -> Bool {
        let conversationId = item.id
        let query = table.filter(id == conversationId)
        do {
            let deletedRows = try dataBase.run(query.delete())
            guard deletedRows == 1 else {
                return false
            }
            return true
        } catch _ {
            return false
        }
    }

    func selectConversations (conversationId: Int64, dataBase: Connection) throws -> [Conversation]? {
        let query = table.filter(id == conversationId)
        var conversations = [Conversation]()
        let items = try dataBase.prepare(query)
        for item in  items {
            conversations.append(Conversation(id: item[id], participant: item[participant]))
        }
        return conversations
    }

    func selectAll(dataBase: Connection) throws -> [Conversation]? {
        var conversations = [Conversation]()
        let items = try dataBase.prepare(table)
        for item in items {
            conversations.append(Conversation(id: item[id], participant: item[participant]))
        }
        return conversations
    }

    func selectConversationsForProfile(profileUri: String, dataBase: Connection) throws -> [Conversation]? {
        var conversations = [Conversation]()
        let query = table.filter(participant == profileUri)
        let items = try dataBase.prepare(query)
        for item in  items {
            conversations.append(Conversation(id: item[id], participant: item[participant]))
        }
        return conversations
    }

    func deleteConversations(conversationID: Int64, dataBase: Connection) -> Bool {
        let query = table.filter(id == conversationID)
        do {
            if try dataBase.run(query.delete()) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func deleteAll(dataBase: Connection) -> Bool {
        do {
            if try dataBase.run(table.delete()) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
