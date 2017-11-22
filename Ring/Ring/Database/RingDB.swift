//
//  RingDB.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SQLite
import SwiftyBeaver

enum DataAccessError: Error {
    case datastoreConnectionError
    case databaseError
    case nilInData
}

class RingDB {
    static let instance = RingDB()
    let ringDB: Connection?
    private let log = SwiftyBeaver.self

    private init() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!

        do {
            ringDB = try Connection("\(path)/Ring.sqlite3")
        } catch {
            ringDB = nil
            log.error("Unable to open database")
        }

//        do { try createTables()
//        } catch {
//            log.error("Unable to create tables")
//        }
    }

//    func createTables() throws {
//        do {
//            try ProfileDataHelper.createTable()
//            try ConversationDataHelper.createTable()
//            try InteractionDataHelper.createTable()
//        } catch {
//            throw DataAccessError.datastoreConnectionError
//        }
//    }
}
