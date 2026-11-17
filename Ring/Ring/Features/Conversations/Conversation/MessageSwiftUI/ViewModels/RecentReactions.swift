/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

final class RecentReactions {
    static let defaults: [String] = [
        0x1F44D, 0x1F44E, 0x1F606, 0x1F923, 0x1F615
    ].map { String(UnicodeScalar($0)!) }

    private static let key = "RECENT_REACTIONS_KEY"
    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    var reactions: [String] {
        var result = [String]()
        for emoji in saved + Self.defaults where !result.contains(emoji) {
            result.append(emoji)
            if result.count == Self.defaults.count { break }
        }
        return result
    }

    func record(_ emoji: String) {
        guard !emoji.isEmpty else { return }
        let updated = [emoji] + saved.filter { $0 != emoji }
        store.set(Array(updated.prefix(Self.defaults.count)), forKey: Self.key)
    }

    private var saved: [String] {
        store.stringArray(forKey: Self.key) ?? []
    }
}
