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

final class MessagesListHistoryTests: XCTestCase {
    private func message(_ id: String) -> MessageModel {
        MessageModel(withId: id, receivedDate: Date(), content: "hello", authorURI: "author1", incoming: true)
    }

    func testUniqueMessagesSkipsAlreadyLoaded() {
        let result = MessagesListVM.uniqueMessages([message("a"), message("b"), message("c")], excluding: ["b"])
        XCTAssertEqual(result.map { $0.id }, ["a", "c"])
    }

    func testUniqueMessagesDropsDuplicatesInsideBatch() {
        let result = MessagesListVM.uniqueMessages([message("a"), message("a"), message("b")], excluding: [])
        XCTAssertEqual(result.map { $0.id }, ["a", "b"])
    }

    func testUniqueMessagesKeepsOrder() {
        let result = MessagesListVM.uniqueMessages([message("c"), message("a"), message("b")], excluding: [])
        XCTAssertEqual(result.map { $0.id }, ["c", "a", "b"])
    }
}
