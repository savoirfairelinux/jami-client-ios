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
import RxSwift
@testable import Ring

final class ConversationModelTests: XCTestCase {
    func testDraftAndReplyRemainUntilLocalAcceptance() {
        let states = PublishSubject<State>()
        let panel = MessagePanelVM(messagePanelState: states)
        let message = MessageModel(withId: "post", receivedDate: Date(), content: "Post", authorURI: jamiId2, incoming: true)
        panel.messageToReply = MessageContentVM(message: message, contextMenuState: states,
                                               transferState: states, isHistory: false, preferencesColor: .black)
        var complete: ((Int, MessageSendError?) -> Void)?
        let subscription = states.subscribe(onNext: { state in
            if case let .send(messages, completion) = state as? MessagePanelState {
                XCTAssertEqual(messages.first?.parentId, "post")
                complete = completion
            }
        })
        defer { subscription.dispose() }
        panel.sendDraft(text: "Reply")
        XCTAssertEqual(panel.draftText, "Reply")
        XCTAssertEqual(panel.messageToReply?.message.id, "post")
        XCTAssertTrue(panel.isSending)
        complete?(0, .permissionDenied)
        XCTAssertEqual(panel.draftText, "Reply")
        XCTAssertEqual(panel.messageToReply?.message.id, "post")
        XCTAssertFalse(panel.isSending)
        panel.sendDraft(text: panel.draftText)
        complete?(1, nil)
        XCTAssertEqual(panel.draftText, "")
        XCTAssertNil(panel.messageToReply)
    }

    func testFailedAttachmentIsRetainedAndPartialRetryDoesNotDuplicateIt() {
        let states = PublishSubject<State>()
        let panel = MessagePanelVM(messagePanelState: states)
        var complete: ((Int, MessageSendError?) -> Void)?
        var sent: [OutgoingMessage] = []
        let subscription = states.subscribe(onNext: { state in
            if case let .send(messages, completion) = state as? MessagePanelState {
                sent = messages
                complete = completion
            }
        })
        defer { subscription.dispose() }
        panel.send(.data(displayName: "photo.jpg", data: Data([1, 2])))
        complete?(0, .failed)
        XCTAssertEqual(panel.attachments.count, 1)
        panel.sendDraft(text: "Caption")
        XCTAssertEqual(sent.count, 2)
        complete?(1, .failed)
        XCTAssertTrue(panel.attachments.isEmpty)
        XCTAssertEqual(panel.draftText, "Caption")
        panel.sendDraft(text: panel.draftText)
        XCTAssertEqual(sent.count, 1)
        complete?(0, .unconfirmed)
        XCTAssertEqual(panel.draftText, "Caption")
    }

    func testFeedMemberCanReplyButCannotPublishOrForward() {
        let grants = ["textReply", "fileReply", "reaction"]
        XCTAssertFalse(SwarmSendPolicy.allows(grants, file: false, parentId: ""))
        XCTAssertFalse(SwarmSendPolicy.allows(grants, file: true, parentId: ""))
        XCTAssertTrue(SwarmSendPolicy.allows(grants, file: false, parentId: "post"))
        XCTAssertTrue(SwarmSendPolicy.allows(grants, file: true, parentId: "post"))
    }

    func testMissingOrUnknownGrantsDoNotAllowSharing() {
        XCTAssertFalse(SwarmSendPolicy.allows(nil, file: false, parentId: ""))
        XCTAssertFalse(SwarmSendPolicy.allows(["futurePermission"], file: true, parentId: "post"))
        XCTAssertFalse(SwarmSendPolicy.canPublish(["textReply", "fileReply"]))
        XCTAssertTrue(SwarmSendPolicy.canPublish(["text"]))
        XCTAssertTrue(SwarmSendPolicy.canPublish(["file"]))
    }

    func testBridgeRechecksGrantsWhenForwardingAfterSelection() {
        let adapter = ObjCMockConversationsAdapter()
        adapter.permissions = ["text", "file"]
        XCTAssertTrue(SwarmSendPolicy.canPublish(adapter.getConversationPermissions(accountId1, conversationId: conversationId1)))
        // The destination was selectable, but the local role changed before dispatch.
        adapter.permissions = ["textReply", "fileReply"]
        XCTAssertFalse(adapter.sendSwarmMessage(accountId1, conversationId: conversationId1,
                                               message: "Forwarded", parentId: "", flag: 0))
    }

    func testFileBridgeRejectsPublishingWithOnlyReplyPermission() {
        let adapter = ObjCMockSendFileAdapter()
        adapter.permissions = ["fileReply"]
        XCTAssertFalse(adapter.sendSwarmFile(withName: "photo.jpg", accountId: accountId1,
                                            conversationId: conversationId1, withFilePath: "/unused", parent: ""))
        adapter.permissions = []
        XCTAssertFalse(adapter.sendSwarmFile(withName: "photo.jpg", accountId: accountId1,
                                            conversationId: conversationId1, withFilePath: "/unused", parent: "post"))
    }

    func createConversation(conversationId: String, jamiId: String, type: ConversationType, accountId: String) -> ConversationModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: jamiId)
        var info = ConversationInfo(type: type)
        info.participants = [ConversationParticipant(jamiId: uri.hash ?? "")]
        info.hash = uri.hash ?? ""
        return ConversationModel(id: conversationId, accountId: accountId, info: info)
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
}
