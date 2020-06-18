/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
    author: String?,
    conversation: Int64,
    timestamp: Int64,
    duration: Int64,
    body: String,
    type: String,
    status: String,
    daemonID: String,
    incoming: Bool
)

final class InteractionDataHelper {

    let table = Table("interactions")
    let id = Expression<Int64>("id")
    let author = Expression<String?>("author")
    let duration = Expression<Int64>("duration")
    let conversation = Expression<Int64>("conversation")
    let timestamp = Expression<Int64>("timestamp")
    let body = Expression<String>("body")
    let type = Expression<String>("type")
    let status = Expression<String>("status")
    let daemonId = Expression<String>("daemon_id")
    let incoming = Expression<Bool>("incoming")

    //foreign keys references
    let tableProfiles = Table("profiles")
    let tableConversations = Table("conversations")
    let uri = Expression<String>("uri")

    //migrations from legacy db
    let authorId = Expression<Int64>("author_id")
    let conversationId = Expression<Int64>("conversation_id")
    func migrateToDBForAccount (from oldDB: Connection,
                                to newDB: Connection,
                                accountProfileId: Int64,
                                contactsMap: [Int64: String]) throws {
        let items = try oldDB.prepare(table)
        for item in items {
            let uri: String? = (contactsMap[item[authorId]] != nil) ? "ring:" + contactsMap[item[authorId]]! : nil
            let migrationData = self.migrateMessageBody(body: item[body], type: item[type])
            let query = table.insert(id <- item[id],
                                     author <- uri,
                                     conversation <- item[conversationId],
                                     timestamp <- item[timestamp],
                                     duration <- migrationData.duration,
                                     body <- migrationData.body,
                                     type <- item[type],
                                     status <- item[status],
                                     daemonId <- item[daemonId],
                                     incoming <- item[incoming])
            try newDB.run(query)
        }
    }

    func migrateMessageBody(body: String, type: String) -> (body: String, duration: Int64) {
        switch type {
        case InteractionType.call.rawValue:
            //check if have call duration
            if let index = body.firstIndex(of: "-") {
                let timeIndex = body.index(index, offsetBy: 2)
                let durationString = body.suffix(from: timeIndex)
                let time = String(durationString).convertToSeconds()
                let messageBody = String(body.prefix(upTo: index))
                if messageBody.contains(GeneratedMessageType.incomingCall.rawValue) {
                    return(GeneratedMessage.incomingCall.toString(), time)
                } else {
                    return(GeneratedMessage.outgoingCall.toString(), time)
                }
            } else if body == GeneratedMessageType.missedIncomingCall.rawValue {
                return(GeneratedMessage.missedIncomingCall.toString(), 0)
            } else {
                return(GeneratedMessage.missedOutgoingCall.toString(), 0)
            }
        case InteractionType.contact.rawValue:
            if body == GeneratedMessageType.contactAdded.rawValue {
                return(GeneratedMessage.contactAdded.toString(), 0)
            } else {
                return(GeneratedMessage.invitationReceived.toString(), 0)
            }
        default:
            return (body, 0)
        }
    }

    func createTable(accountDb: Connection) {
        do {
            try accountDb.run(table.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(author)
                table.column(conversation)
                table.column(timestamp)
                table.column(duration)
                table.column(body)
                table.column(type)
                table.column(status)
                table.column(daemonId)
                table.column(incoming)
                table.foreignKey(author,
                                 references: tableProfiles, uri, delete: .noAction)
                table.foreignKey(conversation,
                                 references: tableConversations, id, delete: .noAction)
            })
        } catch _ {
            print("Table already exists")
        }
    }

    func insert(item: Interaction, dataBase: Connection) -> Int64? {
        let query = table.insert(duration <- item.duration,
                                  author <- item.author,
                                  conversation <- item.conversation,
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

    func delete (item: Interaction, dataBase: Connection) -> Bool {
        let interactionId = item.id
        let query = table.filter(id == interactionId)
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

    func delete (interactionId: Int64, dataBase: Connection) -> Bool {
        let query = table.filter(id == interactionId)
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

    func selectInteraction (interactionId: Int64, dataBase: Connection) throws -> Interaction? {
        let query = table.filter(id == interactionId)
        let items = try dataBase.prepare(query)
        for item in  items {
            return Interaction(id: item[id],
                               author: item[author],
                               conversation: item[conversation],
                               timestamp: item[timestamp],
                               duration: item[duration],
                               body: item[body],
                               type: item[type],
                               status: item[status],
                               daemonID: item[daemonId],
                               incoming: item[incoming])
        }
        return nil
    }

    func selectAll(dataBase: Connection) throws -> [Interaction]? {
        var interactions = [Interaction]()
        let items = try dataBase.prepare(table)
        for item in items {
            interactions.append(Interaction(id: item[id],
                                            author: item[author],
                                            conversation: item[conversation],
                                            timestamp: item[timestamp],
                                            duration: item[duration],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
        }
        return interactions
    }

    func selectInteractionsForConversation (conv: Int64, dataBase: Connection) throws -> [Interaction]? {
        let query = table.filter(conversation == conv)
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            author: item[author],
                                            conversation: item[conversation],
                                            timestamp: item[timestamp],
                                            duration: item[duration],
                                            body: item[body],
                                            type: item[type],
                                            status: item[status],
                                            daemonID: item[daemonId],
                                            incoming: item[incoming]))
        }
        return interactions
    }

    func selectInteractionWithDaemonId(interactionDaemonID: String, dataBase: Connection) throws -> Interaction? {
        let query = table.filter(daemonId == interactionDaemonID)
        var interactions = [Interaction]()
        let items = try dataBase.prepare(query)
        for item in  items {
            interactions.append(Interaction(id: item[id],
                                            author: item[author],
                                            conversation: item[conversation],
                                            timestamp: item[timestamp],
                                            duration: item[duration],
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

    func updateInteractionWithDaemonID(interactionDaemonID: String, interactionStatus: String, dataBase: Connection) -> Bool {
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

    func updateInteractionStatusWithID(interactionID: Int64, interactionStatus: String, dataBase: Connection) -> Bool {
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

    func updateInteractionContentWithID(interactionID: Int64, content: String, dataBase: Connection) -> Bool {
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

    func deleteAllIntercations(conv: Int64, dataBase: Connection) -> Bool {
        let query = table.filter(conversation == conv)
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

    func insertIfNotExist(item: Interaction, dataBase: Connection) -> Int64? {
        let querySelect = table.filter(conversation == item.conversation &&
            body == item.body &&
            type == item.type)
        let queryInsert = table.insert(author <- item.author,
                                       conversation <- item.conversation,
                                       timestamp <- item.timestamp,
                                       duration <- item.duration,
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
