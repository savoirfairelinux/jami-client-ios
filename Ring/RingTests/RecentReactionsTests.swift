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

import XCTest
@testable import Ring

final class RecentReactionsTests: XCTestCase {
    private let suiteName = "RecentReactionsTests"
    private var store: UserDefaults!
    private var recents: RecentReactions!

    override func setUp() {
        super.setUp()
        store = UserDefaults(suiteName: suiteName)
        store.removePersistentDomain(forName: suiteName)
        recents = RecentReactions(store: store)
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshInstallShowsDefaults() {
        XCTAssertEqual(recents.reactions, RecentReactions.defaults)
    }

    func testRecordedEmojiLeadsWithoutDuplicates() {
        recents.record("🎉")
        recents.record("😆")

        XCTAssertEqual(recents.reactions, ["😆", "🎉", "👍", "👎", "🤣"])
    }

    func testOldestRecentDropsOutAtCapacity() {
        ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣"].forEach(recents.record)

        XCTAssertEqual(recents.reactions, ["6️⃣", "5️⃣", "4️⃣", "3️⃣", "2️⃣"])
    }

    func testRecentsPersistAcrossInstances() {
        recents.record("🎉")

        XCTAssertEqual(RecentReactions(store: store).reactions.first, "🎉")
    }
}
