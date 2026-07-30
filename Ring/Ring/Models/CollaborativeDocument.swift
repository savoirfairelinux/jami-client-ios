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
 A collaborative document announced in a conversation.

 The daemon only ever describes a document; its content lives in a Y-CRDT
 replica the client owns.
 */
struct CollaborativeDocument: Equatable {
    /// The media type every editor-backed document uses.
    static let mimeRichText = "text/html"
    /// The media type the daemon falls back to when none is given.
    static let mimePlainText = "text/plain"

    let id: String
    let name: String
    let mimeType: String
    let author: String?
    let timestamp: Int64

    var isRichText: Bool {
        return mimeType == CollaborativeDocument.mimeRichText
    }

    /**
     Build a document from a COLLAB_DOC commit map, as returned by
     `documentsForAccount`. The daemon spells the document id "uri", since the
     map is the announcing commit itself.
     */
    init?(fromNative map: [String: String]) {
        guard let id = map["uri"], !id.isEmpty else { return nil }
        self.id = id
        self.name = map["displayName"] ?? ""
        if let mime = map["mimeType"], !mime.isEmpty {
            self.mimeType = mime
        } else {
            self.mimeType = CollaborativeDocument.mimePlainText
        }
        if let author = map["author"], !author.isEmpty {
            self.author = author
        } else {
            self.author = nil
        }
        self.timestamp = Int64(map["timestamp"] ?? "") ?? 0
    }
}

/// One checkpoint in a document's history: a commit gathering a batch of updates.
struct CollaborativeVersion: Equatable {
    let commitId: String
    let author: String
    let device: String
    let timestamp: Int64
    let deltas: Int

    init?(fromNative map: [String: String]) {
        guard let commitId = map["id"], !commitId.isEmpty else { return nil }
        self.commitId = commitId
        self.author = map["author"] ?? ""
        self.device = map["device"] ?? ""
        self.timestamp = Int64(map["timestamp"] ?? "") ?? 0
        self.deltas = Int(map["deltas"] ?? "") ?? 0
    }
}
