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
    let dbName = "ring.db"

    private init() {
        let path = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
            ).first!

        do {
            ringDB = try Connection("\(path)/" + dbName)
        } catch {
            ringDB = nil
            log.error("Unable to open database")
        }
    }
}
