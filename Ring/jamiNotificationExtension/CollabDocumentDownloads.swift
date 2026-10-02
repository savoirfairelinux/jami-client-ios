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

/// The documents the notification extension waits for. The daemon downloads
/// an announced document on its own and reports it replicated once no download
/// of it is in progress, possibly before the extension sees the announcement.
/// Like the daemon, it tells a document apart by the conversation that
/// announced it.
struct CollabDocumentDownloads {
    private struct DocumentKey: Hashable {
        let conversationId: String
        let documentId: String
    }

    private var awaited: Set<DocumentKey> = []
    private var replicated: Set<DocumentKey> = []

    /// Whether an announced document is still being downloaded.
    var isAwaiting: Bool {
        return !awaited.isEmpty
    }

    mutating func documentAnnounced(conversationId: String, documentId: String) {
        let document = DocumentKey(conversationId: conversationId, documentId: documentId)
        if !replicated.contains(document) {
            awaited.insert(document)
        }
    }

    mutating func documentReplicated(conversationId: String, documentId: String) {
        let document = DocumentKey(conversationId: conversationId, documentId: documentId)
        replicated.insert(document)
        awaited.remove(document)
    }
}
