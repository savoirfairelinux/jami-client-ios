//
//  DataTransferModel.swift
//  Ring
//
//  Created by Andreas Traczyk on 2018-03-01.
//  Copyright © 2018 Savoir-faire Linux. All rights reserved.
//

import Foundation

enum DataTransferStatus {
    case unknown
    case on_connection
    case on_progress
    case success
    case stop_by_peer
    case stop_by_host
    case unjoinable_peer
    case invalid_pathname
    case unsupported
}

class DataTransferModel {
    var uid: String = ""
    var status: DataTransferStatus = .unknown
    var isOutgoing: Bool = false
    var totalSize: size_t = 0
    var progress: size_t = 0 // if status >= on_progress, gives number of bytes tx/rx until now
    var path: String = ""
    var displayName: String = ""
}
