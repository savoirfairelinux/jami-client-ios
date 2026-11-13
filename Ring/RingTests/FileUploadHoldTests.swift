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

final class FileUploadHoldTests: XCTestCase {

    private let now: TimeInterval = 100

    func testARequestHoldsUntilItsUploadEnds() {
        var hold = FileUploadHold()
        hold.requested(conversationId: "a", at: now)
        XCTAssertTrue(hold.isHolding(at: now))

        hold.started(conversationId: "a")
        XCTAssertTrue(hold.isHolding(at: now))

        hold.ended()
        XCTAssertFalse(hold.isHolding(at: now))
    }

    func testEveryRequestedUploadIsAwaited() {
        var hold = FileUploadHold()
        hold.requested(conversationId: "a", at: now)
        hold.requested(conversationId: "a", at: now)
        hold.started(conversationId: "a")
        hold.ended()
        XCTAssertTrue(hold.isHolding(at: now))

        hold.started(conversationId: "a")
        hold.ended()
        XCTAssertFalse(hold.isHolding(at: now))
    }

    func testAnUnrequestedUploadHoldsWhileRunning() {
        var hold = FileUploadHold()
        hold.started(conversationId: "a")
        XCTAssertTrue(hold.isHolding(at: now))

        hold.ended()
        XCTAssertFalse(hold.isHolding(at: now))
    }

    func testARequestThatNeverStartsExpires() {
        var hold = FileUploadHold()
        hold.requested(conversationId: "a", at: now)
        XCTAssertTrue(hold.isHolding(at: now + FileUploadHold.requestTimeout - 1))
        XCTAssertFalse(hold.isHolding(at: now + FileUploadHold.requestTimeout))
    }

    func testAnUploadInAnotherConversationKeepsTheRequestPending() {
        var hold = FileUploadHold()
        hold.requested(conversationId: "a", at: now)
        hold.started(conversationId: "b")
        hold.ended()
        XCTAssertTrue(hold.isHolding(at: now))
    }
}
