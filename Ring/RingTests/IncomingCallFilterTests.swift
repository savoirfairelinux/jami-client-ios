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

import XCTest

final class IncomingCallFilterTests: XCTestCase {

    func testKnownContactAccepted() {
        let filter = IncomingCallFilter(
            contactDetails: [[FilterKeys.contactId: jamiId1]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testUnknownPeerRejected() {
        let filter = IncomingCallFilter(
            contactDetails: [[FilterKeys.contactId: jamiId2]]
        )
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testEmptyContactListRejectsEverything() {
        let filter = IncomingCallFilter(contactDetails: [])
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testPrefixedUppercaseContactMatchesRawHexPeer() {
        let filter = IncomingCallFilter(
            contactDetails: [[FilterKeys.contactId: "ring:" + jamiId1.uppercased()]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }
}
