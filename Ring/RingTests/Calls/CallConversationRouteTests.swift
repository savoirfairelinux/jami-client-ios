/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import XCTest
@testable import Ring

final class CallConversationRouteTests: XCTestCase {

    func testConferenceConversationTakesPrecedence() {
        let call = CallTestFixtures.call(conversationId: conversationId1)
        let conference = CallTestFixtures.conference(conversationId: conversationId2)

        XCTAssertEqual(CallConversationRoute(call: call, conference: conference),
                       CallConversationRoute(conversationId: conversationId2,
                                             peerUri: call.peerUri,
                                             accountId: accountId1))
    }

    func testEmptyConferenceConversationFallsBackToCallConversation() {
        let call = CallTestFixtures.call(conversationId: conversationId1)
        let conference = CallTestFixtures.conference(conversationId: String())

        XCTAssertEqual(CallConversationRoute(call: call, conference: conference),
                       CallConversationRoute(conversationId: conversationId1,
                                             peerUri: call.peerUri,
                                             accountId: accountId1))
    }
}
