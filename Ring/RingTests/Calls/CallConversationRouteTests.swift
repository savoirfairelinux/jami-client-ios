/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 */

import XCTest
@testable import Ring

final class CallConversationRouteTests: XCTestCase {

    func testConferenceConversationTakesPrecedence() {
        let call = makeCall(conversationId: "direct")
        var conference = ConferenceState(id: ConfId(raw: "conference"),
                                         accountId: accountId1)
        conference.conversationId = "swarm"

        XCTAssertEqual(CallConversationRoute(call: call, conference: conference),
                       CallConversationRoute(conversationId: "swarm",
                                             peerUri: call.peerUri,
                                             accountId: accountId1))
    }

    func testEmptyConferenceConversationFallsBackToCallConversation() {
        let call = makeCall(conversationId: "direct")
        var conference = ConferenceState(id: ConfId(raw: "conference"),
                                         accountId: accountId1)
        conference.conversationId = ""

        XCTAssertEqual(CallConversationRoute(call: call, conference: conference),
                       CallConversationRoute(conversationId: "direct",
                                             peerUri: call.peerUri,
                                             accountId: accountId1))
    }

    func testMissingCallCannotProduceConversationRoute() {
        XCTAssertNil(CallConversationRoute(call: nil, conference: nil))
    }

    private func makeCall(conversationId: String?) -> CallState {
        CallState(id: CallId(raw: "call"), accountId: accountId1,
                  direction: .outgoing, peerUri: "bob", status: .current,
                  conversationId: conversationId)
    }
}
