/*
 *  Copyright (C) 2023 - 2026 Savoir-faire Linux Inc.
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

final class ConversationModelTests: XCTestCase {

    func createConversation(conversationId: String, jamiId: String, type: ConversationType?, accountId: String) -> ConversationModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId)
        conversation.type = type
        conversation.id = conversationId
        return conversation
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_DifferentAccounts() {
        // Arrange
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId2)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_EqualAccounts() {
        // Arrange
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationsEqual_SwarmTemporary_DifferentJamiId_EqualAccounts() {
        // Arrange
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId2, type: .oneToOne, accountId: accountId1)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_DifferentConversationType_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .invitesOnly, accountId: accountId1)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_DifferentConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .invitesOnly, accountId: accountId1)
        let conversation2 = createConversation(conversationId: conversationId2, jamiId: jamiId1, type: .invitesOnly, accountId: accountId1)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_EqualConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .invitesOnly, accountId: accountId1)
        let conversation2 = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .invitesOnly, accountId: accountId1)
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertTrue(result)
    }

    func testUpdateInfo_ValidMode_SetsType() {
        // Arrange
        let conversation = ConversationModel(withId: conversationId1, accountId: accountId1)
        let info = [ConversationAttributes.mode.rawValue: String(ConversationType.invitesOnly.rawValue)]
        // Act
        conversation.updateInfo(info: info)
        // Assert
        XCTAssertEqual(conversation.type, .invitesOnly)
    }

    func testUpdateInfo_MissingMode_DoesNotOverwriteKnownType() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .nonSwarm, accountId: accountId1)
        // Act
        conversation.updateInfo(info: ["syncing": "true"])
        // Assert
        XCTAssertEqual(conversation.type, .nonSwarm)
    }

    func testUpdateInfo_InvalidMode_DoesNotOverwriteKnownType() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .oneToOne, accountId: accountId1)
        // Act
        conversation.updateInfo(info: [ConversationAttributes.mode.rawValue: "notAnInt"])
        // Assert
        XCTAssertEqual(conversation.type, .oneToOne)
    }

    func testRoutesToSwarmInfo_UnclassifiedConversation_ReturnsTrue() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: nil, accountId: accountId1)
        // Act
        let result = conversation.routesToSwarmInfo()
        // Assert
        XCTAssertTrue(result)
    }

    func testRoutesToSwarmInfo_JamsConversation_ReturnsTrue() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .jams, accountId: accountId1)
        // Act
        let result = conversation.routesToSwarmInfo()
        // Assert
        XCTAssertTrue(result)
    }

    func testRoutesToSwarmInfo_NonSwarmConversation_ReturnsFalse() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .nonSwarm, accountId: accountId1)
        // Act
        let result = conversation.routesToSwarmInfo()
        // Assert
        XCTAssertFalse(result)
    }

    func testRoutesToSwarmInfo_SipConversation_ReturnsFalse() {
        // Arrange
        let conversation = createConversation(conversationId: conversationId1, jamiId: jamiId1, type: .sip, accountId: accountId1)
        // Act
        let result = conversation.routesToSwarmInfo()
        // Assert
        XCTAssertFalse(result)
    }
}
