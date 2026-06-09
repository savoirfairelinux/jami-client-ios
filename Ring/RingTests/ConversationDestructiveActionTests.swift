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

final class ConversationDestructiveActionTests: XCTestCase {

    func createConversation(conversationId: String, jamiId: String, type: ConversationType, accountId: String) -> ConversationModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId, type: type)
        conversation.id = conversationId
        return conversation
    }

    func testSmartListDestructiveActions_SwarmOneToOne() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .oneToOne, accountId: accountId1)

        // Act
        let actions = ConversationDestructiveAction.availableActions(for: conversation)

        // Assert
        XCTAssertEqual(actions, [.blockContact, .removeContact, .removeConversation])
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.title(for: conversation), L10n.Swarm.removeConversation)
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.confirmationMessage(for: conversation), L10n.Alerts.confirmRemoveOneToOneConversation)
    }

    func testSmartListDestructiveActions_SwarmGroup() {
        // Arrange
        let conversation = ConversationModel(withId: conversationId1, accountId: accountId1, type: .invitesOnly)
        conversation.addParticipant(jamiId: jamiId1)
        conversation.addParticipant(jamiId: jamiId2)
        conversation.addParticipant(jamiId: jamiId3)

        // Act
        let actions = ConversationDestructiveAction.availableActions(for: conversation)

        // Assert
        XCTAssertEqual(actions, [.removeConversation])
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.title(for: conversation), L10n.Swarm.leaveConversation)
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.confirmationMessage(for: conversation), L10n.Alerts.confirmLeaveConversation)
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.confirmationButtonTitle(for: conversation), L10n.Global.leave)
    }

    func testSmartListDestructiveActions_LegacyNonSwarm() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .nonSwarm, accountId: accountId1)

        // Act
        let actions = ConversationDestructiveAction.availableActions(for: conversation)

        // Assert
        XCTAssertEqual(actions, [.blockContact, .removeContact])
    }

    func testSmartListDestructiveActions_Sip() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHash: sipTestNumber1)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId1, hash: sipTestNumber1, type: .sip)
        conversation.id = conversationId1

        // Act
        let actions = ConversationDestructiveAction.availableActions(for: conversation)

        // Assert
        XCTAssertEqual(actions, [.removeConversation])
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.title(for: conversation), L10n.Swarm.removeConversation)
        XCTAssertEqual(ConversationDestructiveAction.removeConversation.confirmationMessage(for: conversation), L10n.Alerts.confirmDeleteConversation)
    }
}
