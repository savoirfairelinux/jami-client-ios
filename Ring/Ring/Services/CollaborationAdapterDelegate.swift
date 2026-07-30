/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation

/**
 Daemon events for a collaborative document.

 They fire while a document is open, at the rate the peers type, and they arrive
 on the daemon's own thread.

 A peer is identified by `clientId`, not by `peerId`: one account can have
 several devices in the same document, each with its own cursor. `peerId` says
 which person a client belongs to.
 */
@objc protocol CollaborationAdapterDelegate {
    func documentUpdate(withAccountId accountId: String,
                        conversationId: String,
                        documentId: String,
                        update: Data)

    func awarenessChanged(withAccountId accountId: String,
                          conversationId: String,
                          documentId: String,
                          peerId: String,
                          clientId: UInt64,
                          state: String)

    func participantLeft(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         peerId: String,
                         clientId: UInt64)

    func documentRenamed(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         name: String)

    func attachmentAdded(withAccountId accountId: String,
                         conversationId: String,
                         documentId: String,
                         attachmentId: String)
}
