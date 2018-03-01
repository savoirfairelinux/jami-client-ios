/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

import Foundation

enum DataTransferStatus: CustomStringConvertible {
    case unknown
    case onConnection       // outgoing/incoming tx: wait for connection/acceptance or local acceptance
    case onProgress         // connected, data transfer progress reporting
    case success            // transfer finished with success, all data sent
    case closedByPeer       // error: transfer terminated by peer
    case closedByHost       // error: transfer terminated by local host
    case unjoinablePeer     // error: (outgoing only) peer connection failed
    case invalidPathname    // error: (file transfer only) given file path is not valid
    case unsupported        // error: unable to do the transfer (generic error)

    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .onConnection: return "onConnection"
        case .onProgress: return "onProgress"
        case .success: return "success"
        case .closedByPeer: return "closedByPeer"
        case .closedByHost: return "closedByHost"
        case .unjoinablePeer: return "unjoinablePeer"
        case .invalidPathname: return "invalidPathname"
        case .unsupported: return "unsupported"
        }
    }
}

@objc class DataTransferModel: NSObject {
    var uid: UInt64 = 0
    var accountId: String = ""
    var status: DataTransferStatus = .unknown
    var isOutgoing: Bool = false
    var totalSize: Int64 = 0
    var progress: Int64 = 0 // if status >= on_progress, gives number of bytes tx/rx until now
    var path: String = ""
    var displayName: String = ""
    var peerInfoHash: String = ""

    init(withTransferId transferId: UInt64, withInfo info: NSDataTransferInfo) {
        self.uid = transferId
        self.accountId = info.accountId
        self.displayName = info.displayName
        self.path = info.path
        self.totalSize = info.totalSize
        self.peerInfoHash = info.peer
    }
}
