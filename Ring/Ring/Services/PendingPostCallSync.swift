/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

struct PendingPostCallSync {
    /*
     Commit timestamps come from the peer's clock, so a fresh commit can look
     slightly older than the call end. Tolerate a small skew: rejecting a
     genuine commit only costs the remainder of the wait, while accepting a
     stale one ends the wait for nothing.
     */
    private static let clockSkewTolerance: TimeInterval = 30

    let accountId: String
    let peerHash: String
    /// Empty when the ended call could not be tied to a conversation.
    let conversationId: String
    let callEndedAt: Date

    func isConfirmed(by message: MessageModel, from accountId: String,
                     in conversationId: String) -> Bool {
        guard case .call = message.type,
              accountId == self.accountId,
              message.authorId == peerHash else { return false }
        if !self.conversationId.isEmpty, conversationId != self.conversationId { return false }
        return message.receivedDate >= callEndedAt - PendingPostCallSync.clockSkewTolerance
    }
}
