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

final class RequestModelTests: XCTestCase {

    func testConversationRequestWithoutMode_StaysConversationRequest() {
        let request = RequestModel(withDictionary: [
            RequestModel.RequestKey.conversationId.rawValue: conversationId1,
            RequestModel.RequestKey.from.rawValue: jamiId1
        ], accountId: accountId1, type: .conversation)

        XCTAssertTrue(request.isConversationRequest())
        XCTAssertTrue(request.isUnclassifiedConversationRequest())
        XCTAssertNil(request.conversationType)
    }

    func testConversationRequestWithValidMode_SetsConversationType() {
        let request = RequestModel(withDictionary: [
            RequestModel.RequestKey.conversationId.rawValue: conversationId1,
            RequestModel.RequestKey.from.rawValue: jamiId1,
            RequestModel.RequestKey.mode.rawValue: String(ConversationType.oneToOne.rawValue)
        ], accountId: accountId1, type: .conversation)

        XCTAssertTrue(request.isConversationRequest())
        XCTAssertEqual(request.conversationType, .oneToOne)
        XCTAssertFalse(request.isUnclassifiedConversationRequest())
    }

    func testConversationRequestWithNonSwarmMode_DoesNotBecomeContactRequest() {
        let request = RequestModel(withDictionary: [
            RequestModel.RequestKey.conversationId.rawValue: conversationId1,
            RequestModel.RequestKey.from.rawValue: jamiId1,
            RequestModel.RequestKey.mode.rawValue: String(ConversationType.nonSwarm.rawValue)
        ], accountId: accountId1, type: .conversation)

        XCTAssertTrue(request.isConversationRequest())
        XCTAssertEqual(request.conversationType, .nonSwarm)
    }

    func testUpdateFromMissingMode_DoesNotOverwriteKnownConversationType() {
        let request = RequestModel(withDictionary: [
            RequestModel.RequestKey.conversationId.rawValue: conversationId1,
            RequestModel.RequestKey.from.rawValue: jamiId1,
            RequestModel.RequestKey.mode.rawValue: String(ConversationType.oneToOne.rawValue)
        ], accountId: accountId1, type: .conversation)

        request.updatefrom(dictionary: [
            RequestModel.RequestKey.conversationId.rawValue: conversationId1,
            RequestModel.RequestKey.from.rawValue: jamiId1
        ])

        XCTAssertTrue(request.isConversationRequest())
        XCTAssertEqual(request.conversationType, .oneToOne)
    }

    func testInitFromConversation_PreservesNilConversationType() {
        let conversation = ConversationModel(withId: conversationId1, accountId: accountId1)
        let request = RequestModel(conversation: conversation)

        XCTAssertTrue(request.isConversationRequest())
        XCTAssertNil(request.conversationType)
    }
}
