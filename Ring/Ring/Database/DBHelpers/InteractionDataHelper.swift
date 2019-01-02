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

typealias Interaction = (
    id: Int64,
    accountID: Int64,
    authorID: Int64,
    conversationID: Int64,
    timestamp: Int64,
    body: String,
    type: String,
    status: String,
    daemonID: String,
    incoming: Bool
)

final class InteractionDataHelper {

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
    let incoming = Expression<Bool>("incoming")

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
                table.column(incoming)
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

    func insert(item: Interaction) -> Int64? {
        guard let dataBase = RingDB.instance.ringDB else {
            return nil
        }

        let query = table.insert(accountId <- item.accountID,
                                  authorId <- item.authorID,
                                  conversationId <- item.conversationID,
                                  timestamp <- item.timestamp,
                                  body <- item.body,
                                  type <- item.type,
                                  status <- item.status,
                                  daemonId <- item.daemonID,
                                  incoming <- item.incoming)
        do {
            let rowId = try dataBase.run(query)
            guard rowId > 0 else {
                return nil
            }
            return rowId
        } catch _ {
            return nil
        }
    }

    func delete (item: Interaction) -> Bool {
        guard let dataBase = RingDB.instance.ringDB  else {
            return false
        }
        let profileId = item.id
        let query = table.filter(id == profileId)
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
                               daemonID: item[daemonId],
                               incoming: item[incoming])
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
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
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
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
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
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
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
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
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
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
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
        let query = table.filter(daemonId == interactionDaemonID)
        do {
            if try dataBase.run(query.update(status <- interactionStatus)) > 0 {
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
        let query = table.filter(id == interactionID)
        do {
            if try dataBase.run(query.update(status <- interactionStatus)) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func updateInteractionWithID(interactionID: Int64, content: String) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let query = table.filter(id == interactionID)
        do {
            if try dataBase.run(query.update(body <- content)) > 0 {
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    func deleteAllIntercations(convID: Int64) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let query = table.filter(conversationId == convID)
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

    func deleteMessageAndCallInteractions(convID: Int64) -> Bool {
        guard let dataBase = RingDB.instance.ringDB else {
            return false
        }
        let query = table.filter(conversationId == convID && (body != GeneratedMessageType.contactAdded.rawValue))
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

    func insertIfNotExist(item: Interaction) -> Int64? {
        guard let dataBase = RingDB.instance.ringDB else {
            return nil
        }

        let querySelect = table.filter(accountId == item.accountID &&
            conversationId == item.conversationID &&
            body == item.body &&
            type == item.type)
        let queryInsert = table.insert(accountId <- item.accountID,
                                       authorId <- item.authorID,
                                       conversationId <- item.conversationID,
                                       timestamp <- item.timestamp,
                                       body <- item.body,
                                       type <- item.type,
                                       status <- item.status,
                                       daemonId <- item.daemonID,
                                       incoming <- item.incoming)
        do {
            let rows = try dataBase.scalar(querySelect.count)
            if rows == 0 {
                let row = try dataBase.run(queryInsert)
                guard row > 0 else {
                    return nil
                }
                return row
            }
        } catch {
            return nil
        }
        return nil
    }
}
