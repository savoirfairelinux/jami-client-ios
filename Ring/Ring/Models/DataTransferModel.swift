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
    case onConnection
    case onProgress
    case success
    case stopByPeer
    case stopByHost
    case unjoinablePeer
    case invalidPathname
    case unsupported

    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .onConnection: return "onConnection"
        case .onProgress: return "onProgress"
        case .success: return "success"
        case .stopByPeer: return "stopByPeer"
        case .stopByHost: return "stopByHost"
        case .unjoinablePeer: return "unjoinablePeer"
        case .invalidPathname: return "invalidPathname"
        case .unsupported: return "unsupported"
        }
    }
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
