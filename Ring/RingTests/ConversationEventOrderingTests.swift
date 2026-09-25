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
    private let accountId = "event-account"
    private let conversationId = "event-conversation"

    func testDaemonCallbackReturnsWhileEventHandlingIsBusy() {
        let service = makeService(adapter: ObjCMockConversationsAdapter())
        let release = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var handledCount = 0
        let handled = expectation(description: "Event handled after release")
        service.onEvent = { event, _ in
            guard case let .conversationReady(accountId, conversationId) = event else {
                return XCTFail("Unexpected event")
            }
            XCTAssertEqual(accountId, "account")
            XCTAssertEqual(conversationId, "conversation")
            _ = release.wait(timeout: .now() + 2)
            lock.lock()
            handledCount += 1
            lock.unlock()
            handled.fulfill()
        }
        let source = service.eventSource

        source.conversationReady(conversationId: "conversation", accountId: "account")
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
        let accountId = self.accountId
        let conversationId = self.conversationId
        let adapter = ObjCMockConversationsAdapter()
        let service = makeService(adapter: adapter)
        if existingConversation {
            service.addSwarmConversationId(conversationId: conversationId, accountId: accountId,
                                           jamiId: "peer")
        }
        let finished = expectation(description: "Updates applied in order")
        service.onEvent = { [unowned service] event, state in
            switch event {
            case let .conversationReady(accountId, conversationId):
                state.conversationReady(conversationId: conversationId, accountId: accountId,
                                        accountURI: "local")
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.title, "Original")
                XCTAssertEqual(conversation?.preferences.ignoreNotifications, false)
            case let .conversationProfileUpdated(accountId, conversationId, profile):
                state.conversationProfileUpdated(conversationId: conversationId, accountId: accountId,
                                                 profile: profile)
            case let .conversationPreferencesUpdated(accountId, conversationId, preferences):
                state.conversationPreferencesUpdated(conversationId: conversationId, accountId: accountId,
                                                     preferences: preferences)
            case .composingStatusChanged:
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.title, "Updated")
                XCTAssertEqual(conversation?.preferences.ignoreNotifications, true)
                finished.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let source = service.eventSource

        source.conversationReady(conversationId: conversationId, accountId: accountId)
        source.conversationProfileUpdated(conversationId: conversationId, accountId: accountId,
                                          profile: ["title": "Updated"])
        source.conversationPreferencesUpdated(conversationId: conversationId, accountId: accountId,
                                              preferences: ["ignoreNotifications": "true"])
        source.composingStatusChanged(accountId: accountId, conversationId: conversationId,
                                      from: "peer", status: 0)
        wait(for: [finished], timeout: 2)
    }

    func testMembersMessagesAndRemovalAreAppliedDuringEventDelivery() {
        let accountId = self.accountId
        let conversationId = self.conversationId
        let adapter = ObjCMockConversationsAdapter()
        let service = makeService(adapter: adapter)
        let finished = expectation(description: "Message inserted without redispatching to the same queue")
        service.onEvent = { [unowned service] event, state in
            switch event {
            case let .conversationReady(accountId, conversationId):
                state.conversationReady(conversationId: conversationId, accountId: accountId,
                                        accountURI: "local")
            case let .conversationMemberEvent(accountId, conversationId, _, _):
                adapter.members = [["uri": "peer", "role": "member"]]
                state.conversationMemberEvent(conversationId: conversationId, accountId: accountId,
                                              accountURI: "local")
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.getParticipants().map { $0.jamiId }, ["peer"])
            case let .swarmMessageReceived(accountId, conversationId, payload):
                let message = MessageModel(with: payload, localJamiId: "local")
                XCTAssertTrue(state.insertMessages(messages: [message], accountId: accountId,
                                                   localJamiId: "local", conversationId: conversationId,
                                                   fromLoaded: false))
                let conversation = service.getConversationForId(conversationId: conversationId,
                                                                accountId: accountId)
                XCTAssertEqual(conversation?.messages.map { $0.id }, ["message"])
            case let .conversationRemoved(accountId, conversationId):
                state.conversationRemoved(conversationId: conversationId, accountId: accountId)
                XCTAssertNil(service.getConversationForId(conversationId: conversationId, accountId: accountId))
                finished.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        let source = service.eventSource

        source.conversationReady(conversationId: conversationId, accountId: accountId)
        source.conversationMemberEvent(conversationId: conversationId, accountId: accountId,
                                       memberUri: "peer", event: 1)
        let message = SwarmMessageWrap()
        message.id = "message"
        message.type = "text/plain"
        message.linearizedParent = ""
        message.body = ["id": "message", "type": "text/plain", "body": "Hello", "author": "peer"]
        message.reactions = []
        message.editions = []
        message.status = [:]
        source.newInteraction(conversationId: conversationId, accountId: accountId, message: message)
        source.conversationRemoved(conversationId: conversationId, accountId: accountId)
        wait(for: [finished], timeout: 2)
    }

    private func makeService(adapter: ObjCMockConversationsAdapter) -> ConversationsService {
        adapter.info = ["mode": "0", "title": "Original"]
        adapter.preferences = ["ignoreNotifications": "false"]
        adapter.members = []
        let dbManager = DBManager(conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(), dbConnections: DBContainer())
        return ConversationsService(withConversationsAdapter: adapter, dbManager: dbManager)
    }
}
