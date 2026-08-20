/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

/**
 A way of letting go of a collaborative document, as the documents list offers
 them: from the row menu and from the swipe beside it.

 The two are asked as separate questions because they are not the same one. One
 reclaims what this device chose to store, and opening the document again
 fetches it back; the other retires it for every member, and nothing brings it
 back.
 */
enum CollabDocumentRemoval: CaseIterable, Identifiable {
    case fromThisDevice
    case forEveryone

    var id: Self { self }

    /**
     Which removals this document offers, in the order they are shown.

     Any member may stop holding a document, so `fromThisDevice` depends only on
     whether this device is holding one. `forEveryone` is the author's alone: the
     daemon refuses anyone else, and offering it to the others would promise what
     cannot happen.

     - parameter localJamiId: who this device is, empty when the account could
     not be read. An unknown identity matches nobody, least of all a document
     whose author is unknown too.
     */
    static func available(for document: CollaborativeDocument,
                          localJamiId: String) -> [CollabDocumentRemoval] {
        var removals: [CollabDocumentRemoval] = []
        if document.storedLocally {
            removals.append(.fromThisDevice)
        }
        if let author = document.author, !author.isEmpty,
           !localJamiId.isEmpty, author == localJamiId {
            removals.append(.forEveryone)
        }
        return removals
    }
}

// MARK: - Presentation

extension CollabDocumentRemoval {

    /// The row menu has the width to say which removal this is, and spends it.
    var menuTitle: String {
        switch self {
        case .fromThisDevice: return L10n.Collab.removeLocallyMenu
        case .forEveryone: return L10n.Collab.removeEverywhereMenu
        }
    }

    /// A swipe button fits about a dozen characters, so it says less. VoiceOver
    /// is given `menuTitle` there instead, the rotor having the room.
    var swipeTitle: String {
        switch self {
        case .fromThisDevice: return L10n.Collab.removeLocallyAction
        case .forEveryone: return L10n.Collab.removeEverywhereAction
        }
    }

    var symbol: String {
        switch self {
        case .fromThisDevice: return "minus.circle"
        case .forEveryone: return "trash"
        }
    }

    var alertTitle: String {
        switch self {
        case .fromThisDevice: return L10n.Collab.removeLocallyTitle
        case .forEveryone: return L10n.Collab.removeTitle
        }
    }

    func alertMessage(for name: String) -> String {
        switch self {
        case .fromThisDevice: return L10n.Collab.removeLocallyMessage(name)
        case .forEveryone: return L10n.Collab.removeMessage(name)
        }
    }
}
