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

import XCTest
@testable import Ring

final class ConversationRemovalTests: XCTestCase {
    private let conversation = ConversationModel(id: "conversation", accountId: "account",
                                                 info: ConversationInfo(type: .oneToOne))

    private func removal(conversationId: String, accountId: String) -> ServiceEvent {
        var event = ServiceEvent(withEventType: .conversationRemoved)
        event.addEventInput(.conversationId, value: conversationId)
        event.addEventInput(.accountId, value: accountId)
        return event
    }

    func testRemovingShownConversationClosesIt() {
        let event = removal(conversationId: "conversation", accountId: "account")

        XCTAssertTrue(ConversationsCoordinator.isRemoval(event, of: conversation))
    }

    func testRemovingAnotherConversationKeepsIt() {
        let event = removal(conversationId: "other", accountId: "account")

        XCTAssertFalse(ConversationsCoordinator.isRemoval(event, of: conversation))
    }

    func testSameIdInAnotherAccountKeepsIt() {
        let event = removal(conversationId: "conversation", accountId: "other")

        XCTAssertFalse(ConversationsCoordinator.isRemoval(event, of: conversation))
    }

    func testOtherEventsKeepIt() {
        var event = ServiceEvent(withEventType: .conversationMemberEvent)
        event.addEventInput(.conversationId, value: "conversation")
        event.addEventInput(.accountId, value: "account")

        XCTAssertFalse(ConversationsCoordinator.isRemoval(event, of: conversation))
    }

    func testNothingShownKeepsNothing() {
        let event = removal(conversationId: "conversation", accountId: "account")

        XCTAssertFalse(ConversationsCoordinator.isRemoval(event, of: nil))
    }
}
