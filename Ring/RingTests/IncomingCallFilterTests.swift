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

    func testContactAllowed_WhenAllowFromUnknownDisabled() {
        let filter = IncomingCallFilter(
            allowFromUnknown: false,
            contactDetails: [[FilterKeys.contactId: jamiId1]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testUnknownPeerRejected_WhenAllowFromUnknownDisabled() {
        let filter = IncomingCallFilter(
            allowFromUnknown: false,
            contactDetails: [[FilterKeys.contactId: jamiId2]]
        )
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testUnknownPeerAllowed_WhenAllowFromUnknownEnabled() {
        let filter = IncomingCallFilter(
            allowFromUnknown: true,
            contactDetails: []
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testBannedContactExcludedFromAllowSet() {
        let filter = IncomingCallFilter(
            allowFromUnknown: false,
            contactDetails: [[FilterKeys.contactId: jamiId1, FilterKeys.contactBanned: "true"]]
        )
        XCTAssertFalse(filter.shouldAccept(peerId: jamiId1))
    }

    func testPrefixedUppercaseContactMatchesRawHexPeer() {
        let filter = IncomingCallFilter(
            allowFromUnknown: false,
            contactDetails: [[FilterKeys.contactId: "ring:" + jamiId1.uppercased()]]
        )
        XCTAssertTrue(filter.shouldAccept(peerId: jamiId1))
    }

    func testParseAllowFromUnknown_AbsentKeyDefaultsToTrue() {
        XCTAssertTrue(IncomingCallFilter.parseAllowFromUnknown(accountDetails: [:]))
    }

    func testParseAllowFromUnknown_TrueStringAllows() {
        XCTAssertTrue(IncomingCallFilter.parseAllowFromUnknown(accountDetails: [FilterKeys.publicInCalls: "true"]))
    }

    func testParseAllowFromUnknown_FalseStringRejects() {
        XCTAssertFalse(IncomingCallFilter.parseAllowFromUnknown(accountDetails: [FilterKeys.publicInCalls: "false"]))
    }

    func testParseAllowFromUnknown_NonCanonicalCaseRejects() {
        XCTAssertFalse(IncomingCallFilter.parseAllowFromUnknown(accountDetails: [FilterKeys.publicInCalls: "TRUE"]))
    }
}
