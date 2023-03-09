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

import XCTest
@testable import Ring

final class ConversationModelTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }

    func createConversation(conversationId: String, jamiId: String, type: ConversationType, accountId: String) -> ConversationModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHach: jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId)
        conversation.type = type
        conversation.id = conversationId
        return conversation
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_DifferentAccounts() {
        // Arrange
        let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let accountId1 = "3e2343efr543"
        let accountId2 = "e4545gbvf5r5"
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId, type: .oneToOne, accountId: accountId1)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId, type: .oneToOne, accountId: accountId2)
        // Act
        let result = conversation1 == conversation2
        XCTAssertFalse(result, "Conversations with different account ids are not equal")
    }

    func testConversationsEqual_SwarmTemporary_EqualJamiId_EqualAccounts() {
        // Arrange
        let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let accountId = "3e2343efr543"
        // For temporary conversation conversationId is empty.
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId, type: .oneToOne, accountId: accountId)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId, type: .oneToOne, accountId: accountId)
        // Act
        let result = conversation1 == conversation2
        XCTAssertTrue(result)
    }

    func testConversationsEqual_SwarmTemporary_DifferentJamiId_EqualAccounts() {
        // Arrange
        let jamiId1 = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let jamiId2 = "e5ghj8140bea12734db05ebcdb012f1d2634dv56"
        let accountId = "3e2343efr543"
        let conversation1 = createConversation(conversationId: "", jamiId: jamiId1, type: .oneToOne, accountId: accountId)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId2, type: .oneToOne, accountId: accountId)
        // Act
        let result = conversation1 == conversation2
        XCTAssertFalse(result)
    }

    func testConversationsEqual_DifferentConversationType_EqualJamiId_EqualAccount() {
        // Arrange
        let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let accountId = "3e2343efr543"
        let conversationId = "e5ghj8140bea12734db05ebcdb012f1d2634dv56"
        let conversation1 = createConversation(conversationId: conversationId, jamiId: jamiId, type: .invitesOnly, accountId: accountId)
        let conversation2 = createConversation(conversationId: "", jamiId: jamiId, type: .oneToOne, accountId: accountId)
        // Act
        let result = conversation1 == conversation2
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_DifferentConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let accountId = "3e2343efr543"
        let conversationId1 = "e5ghj8140bea12734db05ebcdb012f1d2634dv56"
        let conversationId2 = "dr4at8140bea12734db05ebcdb012f1d2634dv23"
        let conversation1 = createConversation(conversationId: conversationId1, jamiId: jamiId, type: .invitesOnly, accountId: accountId)
        let conversation2 = createConversation(conversationId: conversationId2, jamiId: jamiId, type: .invitesOnly, accountId: accountId)
        // Act
        let result = conversation1 == conversation2
        XCTAssertFalse(result)
    }

    func testConversationsEqual_EqualType_EqualConversationId_EqualJamiId_EqualAccount() {
        // Arrange
        let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let accountId = "3e2343efr543"
        let conversationId = "e5ghj8140bea12734db05ebcdb012f1d2634dv56"
        let conversation1 = createConversation(conversationId: conversationId, jamiId: jamiId, type: .invitesOnly, accountId: accountId)
        let conversation2 = createConversation(conversationId: conversationId, jamiId: jamiId, type: .invitesOnly, accountId: accountId)
        // Act
        let result = conversation1 == conversation2
        XCTAssertTrue(result)
    }
}
