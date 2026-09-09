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

    func testCallPayloadUsesCachedDisplayName() {
        let payload = IncomingCallPayloadBuilder.build(
            originalData: ["key": "value", "accountId": "stale"],
            peerId: jamiId1,
            hasVideo: true,
            accountId: "account-id",
            cachedDisplayName: "Alice"
        )

        XCTAssertEqual(payload["key"] as? String, "value")
        XCTAssertEqual(payload["peerId"] as? String, jamiId1)
        XCTAssertEqual(payload["hasVideo"] as? String, "true")
        XCTAssertEqual(payload["accountId"] as? String, "account-id")
        XCTAssertEqual(payload["displayName"] as? String, "Alice")
    }

    func testCallPayloadFallsBackToPeerIdWithoutCachedName() {
        let payload = IncomingCallPayloadBuilder.build(
            originalData: [:],
            peerId: jamiId1,
            hasVideo: false,
            accountId: "account-id",
            cachedDisplayName: ""
        )

        XCTAssertEqual(payload["peerId"] as? String, jamiId1)
        XCTAssertEqual(payload["hasVideo"] as? String, "false")
        XCTAssertEqual(payload["accountId"] as? String, "account-id")
        XCTAssertEqual(payload["displayName"] as? String, jamiId1)
    }

    func testAllowUnknownAcceptsStranger() {
        let filter = IncomingCallFilter(allowUnknown: true, contactDetails: [])
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testAllowUnknownAcceptsKnownContact() {
        let filter = IncomingCallFilter(
            allowUnknown: true,
            contactDetails: [[FilterKeys.contactId: jamiId1]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testKnownContactAcceptedWhenUnknownBlocked() {
        let filter = IncomingCallFilter(
            allowUnknown: false,
            contactDetails: [[FilterKeys.contactId: jamiId1]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testUnknownPeerRejectedWhenUnknownBlocked() {
        let filter = IncomingCallFilter(
            allowUnknown: false,
            contactDetails: [[FilterKeys.contactId: jamiId2]]
        )
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testEmptyContactListRejectsEverythingWhenUnknownBlocked() {
        let filter = IncomingCallFilter(allowUnknown: false, contactDetails: [])
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testPrefixedUppercaseContactMatchesRawHexPeer() {
        let filter = IncomingCallFilter(
            allowUnknown: false,
            contactDetails: [[FilterKeys.contactId: "ring:" + jamiId1.uppercased()]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }
}
