//
//  DataHelperProtocol.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2017-11-20.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation

protocol DataHelperProtocol {
    associatedtype TableType
     func createTable() throws
     func insert(item: TableType) throws -> Int64
     func delete(item: TableType) throws
     func selectAll() throws -> [TableType]?
}
