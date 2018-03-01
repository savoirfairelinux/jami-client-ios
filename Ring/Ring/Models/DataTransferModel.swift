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

// swiftlint:disable cyclomatic_complexity
func stringFromEventCode(with code: NSDataTransferEventCode) -> String {
    switch code {
    case .invalid: return L10n.Datatransfer.transferStatusInvalid
    case .created: return L10n.Datatransfer.transferStatusCreated
    case .unsupported: return L10n.Datatransfer.transferStatusUnsupported
    case .wait_host_acceptance: return L10n.Datatransfer.transferStatusWaitHostAcceptance
    case .wait_peer_acceptance: return L10n.Datatransfer.transferStatusWaitPeerAcceptance
    case .ongoing: return L10n.Datatransfer.transferStatusOngoing
    case .finished: return L10n.Datatransfer.transferStatusFinished
    case .closed_by_host: return L10n.Datatransfer.transferStatusClosedByHost
    case .closed_by_peer: return L10n.Datatransfer.transferStatusClosedByPeer
    case .invalid_pathname: return L10n.Datatransfer.transferStatusInvalidPathname
    case .unjoinable_peer: return L10n.Datatransfer.transferStatusUnjoinablePeer
    }
}
// swiftlint:enable cyclomatic_complexity

class DataTransferModel: NSObject {
    var id: UInt64 = 0
    var uid: Int64 = 0
    var accountId: String = ""
    var status: NSDataTransferEventCode = .invalid
    var isIncoming: Bool = false
    var totalSize: Int64 = 0
    var progress: Int64 = 0 // if status >= on_progress, gives number of bytes tx/rx until now
    var path: String = ""
    var displayName: String = ""
    var peerInfoHash: String = ""

    init(withTransferId transferId: UInt64, withInfo info: NSDataTransferInfo) {
        super.init()
        self.id = transferId
        update(withInfo: info)
    }

    func update(withInfo info: NSDataTransferInfo) {
        self.accountId = info.accountId
        self.displayName = info.displayName
        self.path = info.path
        self.totalSize = info.totalSize
        self.peerInfoHash = info.peer
        self.isIncoming = info.flags == 1
        self.progress = info.bytesProgress
        self.totalSize = info.totalSize
        self.status = info.lastEvent
    }
}
