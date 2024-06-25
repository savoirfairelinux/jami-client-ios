/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

@testable import Ring
import XCTest

final class ConversationModelTests: XCTestCase {
    func createConversation(
        conversationId: String,
        jamiId: String,
        type: ConversationType,
        accountId: String
    ) -> ConversationModel {
        let uri = JamiURI(schema: URIType.ring, infoHash: jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId)
        conversation.type = type
        conversation.id = conversationId
        return conversation
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_DifferentAccounts() {
        // Arrange
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId2
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_EqualAccounts() {
        // Arrange
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId1
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationsEqual_SwarmTemporary_DifferentJamiId_EqualAccounts() {
        // Arrange
        let conversation1 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: "",
            jamiId: jamiId2,
            type: .oneToOne,
            accountId: accountId1
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_DifferentConversationType_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(
            conversationId: conversationId1,
            jamiId: jamiId1,
            type: .invitesOnly,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: "",
            jamiId: jamiId1,
            type: .oneToOne,
            accountId: accountId1
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_DifferentConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(
            conversationId: conversationId1,
            jamiId: jamiId1,
            type: .invitesOnly,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: conversationId2,
            jamiId: jamiId1,
            type: .invitesOnly,
            accountId: accountId1
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_EqualConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let conversation1 = createConversation(
            conversationId: conversationId1,
            jamiId: jamiId1,
            type: .invitesOnly,
            accountId: accountId1
        )
        let conversation2 = createConversation(
            conversationId: conversationId1,
            jamiId: jamiId1,
            type: .invitesOnly,
            accountId: accountId1
        )
        // Act
        let result = conversation1 == conversation2
        // Assert
        XCTAssertTrue(result)
    }
}
