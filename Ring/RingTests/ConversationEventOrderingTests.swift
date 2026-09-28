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

final class ConversationEventOrderingTests: XCTestCase {
    func testDaemonCallbackReturnsWhileEventHandlingIsBusy() {
        let service = makeService(adapter: ObjCMockConversationsAdapter())
        let release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var handledCount = 0
        let handled = expectation(description: "Event handled after release")
        service.onEvent = { event in
            guard case let .conversationReady(accountId, conversationId) = event else {
                return XCTFail("Unexpected event")
            }
            XCTAssertEqual(accountId, accountId1)
            XCTAssertEqual(conversationId, conversationId1)
            _ = release.wait(timeout: .now() + 2)
            lock.lock()
            handledCount += 1
            lock.unlock()
            handled.fulfill()
        }
        let source = service.eventSource

        source.conversationReady(conversationId: conversationId1, accountId: accountId1)
        lock.lock()
        XCTAssertEqual(handledCount, 0)
        lock.unlock()
        release.signal()
        wait(for: [handled], timeout: 2)
    }

    func testNewConversationIsReadyBeforeProfileAndPreferencesUpdates() {
        checkReadyBeforeUpdates(existingConversation: false)
    }

    func testExistingConversationKeepsProfileAndPreferencesUpdatesAfterReady() {
        checkReadyBeforeUpdates(existingConversation: true)
    }

    private func checkReadyBeforeUpdates(existingConversation: Bool) {
        let adapter = ObjCMockConversationsAdapter()
        let service = makeService(adapter: adapter)
        if existingConversation {
            service.addSwarmConversationId(conversationId: conversationId1, accountId: accountId1,
                                           jamiId: jamiId2)
        }
        let finished = expectation(description: "Updates applied in order")
        service.onEvent = { [unowned service] event in
            switch event {
            case let .conversationReady(accountId, conversationId):
                service.conversationReady(conversationId: conversationId, accountId: accountId,
                                          accountURI: jamiId1)
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.title, title1)
                XCTAssertEqual(conversation?.preferences.ignoreNotifications, false)
            case .incomingAccountMessage(_, _, "updated", _):
                let conversation = service.getConversationForId(conversationId: conversationId1,
                                                                accountId: accountId1)
                XCTAssertEqual(conversation?.title, profileName1)
                XCTAssertEqual(conversation?.preferences.ignoreNotifications, true)
                finished.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let source = service.eventSource

        source.conversationReady(conversationId: conversationId1, accountId: accountId1)
        source.conversationProfileUpdated(conversationId: conversationId1, accountId: accountId1,
                                          profile: ["title": profileName1])
        source.conversationPreferencesUpdated(conversationId: conversationId1, accountId: accountId1,
                                              preferences: ["ignoreNotifications": "true"])
        source.didReceiveMessage([:], from: jamiId2, messageId: "updated", to: accountId1)
        wait(for: [finished], timeout: 2)
    }

    func testMembersMessagesAndRemovalAreAppliedDuringEventDelivery() {
        let adapter = ObjCMockConversationsAdapter()
        let service = makeService(adapter: adapter)
        let finished = expectation(description: "Message inserted without redispatching to the same queue")
        service.onEvent = { [unowned service] event in
            switch event {
            case let .conversationReady(accountId, conversationId):
                service.conversationReady(conversationId: conversationId, accountId: accountId,
                                          accountURI: jamiId1)
            case let .conversationMemberEvent(accountId, conversationId, _, _):
                adapter.members = [["uri": jamiId2, "role": "member"]]
                service.conversationMemberEvent(conversationId: conversationId, accountId: accountId,
                                                accountURI: jamiId1)
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.getParticipants().map { $0.jamiId }, [jamiId2])
            case let .swarmMessageReceived(accountId, conversationId, payload):
                let message = MessageModel(with: payload, localJamiId: jamiId1)
                XCTAssertTrue(service.insertMessages(messages: [message], accountId: accountId,
                                                     localJamiId: jamiId1, conversationId: conversationId,
                                                     fromLoaded: false))
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.newMessages.value.messages.map { $0.id }, ["message"])
            case let .conversationRemoved(accountId, conversationId):
                service.conversationRemoved(conversationId: conversationId, accountId: accountId)
                XCTAssertNil(service.getConversationForId(conversationId: conversationId, accountId: accountId))
                finished.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let source = service.eventSource

        source.conversationReady(conversationId: conversationId1, accountId: accountId1)
        source.conversationMemberEvent(conversationId: conversationId1, accountId: accountId1,
                                       memberUri: jamiId2, event: 1)
        let message = SwarmMessageWrap()
        message.id = "message"
        message.type = "text/plain"
        message.linearizedParent = ""
        message.body = ["id": "message", "type": "text/plain", "body": "Hello", "author": jamiId2]
        message.reactions = []
        message.editions = []
        message.status = [:]
        source.newInteraction(conversationId: conversationId1, accountId: accountId1, message: message)
        source.conversationRemoved(conversationId: conversationId1, accountId: accountId1)
        wait(for: [finished], timeout: 2)
    }

    private func makeService(adapter: ObjCMockConversationsAdapter) -> ConversationsService {
        adapter.info = ["mode": "0", "title": title1]
        adapter.preferences = ["ignoreNotifications": "false"]
        adapter.members = []
        let dbManager = DBManager(conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(), dbConnections: DBContainer())
        return ConversationsService(withConversationsAdapter: adapter, dbManager: dbManager)
    }
}
