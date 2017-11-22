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

typealias Interaction = (
    id: Int64,
    accountID: Int64,
    authorID: Int64,
    conversationID: Int64,
    timestamp: Int64,
    body: String,
    type: String,
    status: String,
    daemonID: String
)

class InteractionDataHelper {

    let table = RingDB.instance.tableInteractionss
    let id = Expression<Int64>("id")
    let accountId = Expression<Int64>("account_id")
    let authorId = Expression<Int64>("author_id")
    let conversationId = Expression<Int64>("conversation_id")
    let timestamp = Expression<Int64>("timestamp")
    let body = Expression<String>("body")
    let type = Expression<String>("type")
    let status = Expression<String>("status")
    let daemonId = Expression<String>("daemon_id")

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
                table.foreignKey(accountId,
                                 references: RingDB.instance.tableProfiles, id, delete: .noAction)
                table.foreignKey(authorId,
                                 references: RingDB.instance.tableProfiles, id, delete: .noAction)
                table.foreignKey(conversationId,
                                 references: RingDB.instance.tableConversations, id, delete: .noAction)
            })

        } catch _ {
            print("Table already exists")
        }
    }

    func insert(item: Interaction) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }

        let insert = table.insert(accountId <- item.accountID,
                                  authorId <- item.authorID,
                                  conversationId <- item.conversationID,
                                  timestamp <- item.timestamp,
                                  body <- item.body,
                                  type <- item.type,
                                  status <- item.status,
                                  daemonId <- item.daemonID)
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

    func delete (item: Interaction) -> Bool {
        guard let dataBase = RingDB.instance.ringDB  else {
            return false
        }
        let profileId = item.id
        let query = table.filter(id == profileId)
        do {
            let run = try dataBase.run(query.delete())
            guard run == 1 else {
                return false
            }
            return true
        } catch _ {
            return false
        }
    }

    func selectInteraction (interactionId: Int64) throws -> Interaction? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(id == interactionId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Interaction(id: item[id],
                               accountID: item[accountId],
                               authorID: item[authorId],
                               conversationID: item[conversationId],
                               timestamp: item[timestamp],
                               body: item[body],
                               type: item[type],
                               status: item[status],
                               daemonID: item[daemonId])
        }
        return nil
    }

    func selectAll() throws -> [Interaction]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        var interactions = [Interaction]()
        let items = try dataBase.prepare(table)
        for item in items {
            interactions.append(Interaction(id: item[id],
                                            accountID: item[accountId],
                                            authorID: item[authorId],
                                            conversationID: item[conversationId],
                                            timestamp: item[timestamp],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId]))
        }
        return interactions
    }

    func selectInteractionsForAccount (accountID: Int64) throws -> [Interaction]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(accountId == accountID)
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            accountID: item[accountId],
                                            authorID: item[authorId],
                                            conversationID: item[conversationId],
                                            timestamp: item[timestamp],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId]))
        }
        return interactions
    }

    func selectInteractionsForConversation (conversationID: Int64) throws -> [Interaction]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(conversationId == conversationID)
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            accountID: item[accountId],
                                            authorID: item[authorId],
                                            conversationID: item[conversationId],
                                            timestamp: item[timestamp],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId]))
        }
        return interactions
    }

    func selectInteractionsForConversationWithAccount (conversationID: Int64,
                                                       accountProfileID: Int64) throws -> [Interaction]? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(conversationId == conversationID && (accountId == accountProfileID))
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            accountID: item[accountId],
                                            authorID: item[authorId],
                                            conversationID: item[conversationId],
                                            timestamp: item[timestamp],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId]))
        }
        return interactions
    }

    func selectInteractionWithDaemonId(interactionDaemonID: String) throws -> Interaction? {
        guard let dataBase = RingDB.instance.ringDB else {
            throw DataAccessError.datastoreConnectionError
        }
        let query = table.filter(daemonId == interactionDaemonID)
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            accountID: item[accountId],
                                            authorID: item[authorId],
                                            conversationID: item[conversationId],
                                            timestamp: item[timestamp],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId]))
        }
        if interactions.isEmpty {
            return nil
        }

        if interactions.count > 1 {
            return nil
        }

        return interactions.first
    }

    func updateInteractionWithDaemonID(interactionDaemonID: String, interactionStatus: String) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let interaction = table.filter(daemonId == interactionDaemonID)
        do {
            if try dataBase.run(interaction.update(status <- interactionStatus)) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func updateInteractionWithID(interactionID: Int64, interactionStatus: String) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let interaction = table.filter(id == interactionID)
        do {
            if try dataBase.run(interaction.update(status <- interactionStatus)) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func deleteInteractionsForConversation(convID: Int64) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let interaction = table.filter(conversationId == convID)
        do {
            if try dataBase.run(interaction.delete()) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }
}
