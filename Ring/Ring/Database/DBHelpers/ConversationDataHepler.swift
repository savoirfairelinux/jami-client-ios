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
    participantID: Int64
)

final class ConversationDataHelper {
    let table = RingDB.instance.tableConversations
    let id = Expression<Int64>("id")
    let participantId = Expression<Int64>("participant_id")

    func createTable() throws {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        do {
            try dataBase.run(table.create(ifNotExists: true) { table in
                table.column(id)
                table.column(participantId)
                table.foreignKey(participantId, references: RingDB.instance.tableProfiles, id, delete: .noAction)
            })

        } catch _ {
            print("Table already exists")
        }

    }

    func insert(item: Conversation) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let query = table.insert(id <- item.id,
                                  participantId <- item.participantID)
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

    func delete (item: Conversation) -> Bool {
        guard let dataBase = RingDB.instance.ringDB  else {
            return false
        }
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

    func selectConversations (conversationId: Int64) throws -> [Conversation]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == conversationId)
        var conversations = [Conversation]()
        let items = try dataBase.prepare(query)
        for item in  items {
            conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }
        return conversations
    }

    func selectAll() throws -> [Conversation]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var conversations = [Conversation]()
        let items = try dataBase.prepare(table)
        for item in items {
            conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }
        return conversations
    }

    func selectConversationsForProfile(profileId: Int64) throws -> [Conversation]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var conversations = [Conversation]()
        let query = table.filter(participantId == profileId)
        let items = try dataBase.prepare(query)
        for item in  items {
            conversations.append(Conversation(id: item[id], participantID: item[participantId]))
        }
        return conversations
    }

    func deleteConversations(conversationID: Int64) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
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
}
