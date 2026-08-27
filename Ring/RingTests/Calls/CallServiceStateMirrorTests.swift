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

@MainActor
final class CallServiceStateMirrorTests: XCTestCase {

    private func makeService() -> CallService {
        let events = AsyncStream<LibJamiCallEvent> { _ in }
        return CallService(callClient: TestLibJamiCallAPI(), callEvents: events)
    }

    private func makeCall(_ index: Int) -> CallState {
        let id = index == 1 ? CallTestFixtures.callId : CallTestFixtures.secondaryCallId
        let peerUri = index == 1 ? CallTestFixtures.peerUri : CallTestFixtures.secondaryPeerUri
        return CallTestFixtures.call(id: id,
                                     conversationId: nil,
                                     direction: .incoming,
                                     peerUri: peerUri)
    }

    func testMirrorTracksCallLifecycle() {
        let service = makeService()
        let first = makeCall(1)
        let second = makeCall(2)

        XCTAssertFalse(service.hasOngoingCalls)
        service.handle(.callAdded(first))
        service.handle(.callAdded(second))
        XCTAssertTrue(service.hasOngoingCalls)
        let addedSnapshot = service.stateMirror

        var held = first
        held.status = .held(side: .local)
        service.handle(.callUpdated(held))

        XCTAssertEqual(service.stateMirror.call(first.id)?.status, .held(side: .local))
        XCTAssertEqual(addedSnapshot.call(first.id)?.status, .current,
                       "a previously read snapshot must remain a value snapshot")

        service.handle(.callEnded(held, durationSeconds: 0))

        XCTAssertNil(service.stateMirror.call(first.id))
        XCTAssertEqual(service.stateMirror.call(second.id)?.status, .current)
        XCTAssertTrue(service.hasOngoingCalls)

        service.handle(.callEnded(second, durationSeconds: 0))
        XCTAssertFalse(service.hasOngoingCalls)
    }

    func testOutgoingCallURIForOneToOneConversationUsesParticipant() {
        let service = makeService()
        let conversation = ConversationModel(withId: "conversation-id",
                                             accountId: "account-id",
                                             type: .oneToOne)
        conversation.addParticipant(jamiId: "participant-id")

        XCTAssertEqual(service.outgoingCallURI(for: conversation), "participant-id")
    }

    func testOutgoingCallURIForSelfConversationUsesLocalParticipant() {
        let service = makeService()
        let conversation = ConversationModel(withParticipantUri: JamiURI(schema: .ring,
                                                                         infoHash: "local-id"),
                                             accountId: "account-id",
                                             type: .oneToOne,
                                             isLocal: true)

        XCTAssertEqual(service.outgoingCallURI(for: conversation), "local-id")
    }

    func testOutgoingCallURIForGroupConversationUsesSwarmURI() {
        let service = makeService()
        let conversation = makeGroupConversation()

        XCTAssertEqual(service.outgoingCallURI(for: conversation), "swarm:conversation-id")
    }

    func testOutgoingCallURIForGroupConversationUsesActiveCallURI() {
        let service = makeService()
        let conversation = makeGroupConversation()
        let activeCall = ActiveCall(id: "call-id",
                                    uri: "participant-id",
                                    device: "device-id",
                                    conversationId: conversation.id,
                                    accountId: conversation.accountId,
                                    isFromLocalDevice: false)
        var tracker = AccountCallTracker()
        tracker.setCalls(for: conversation.id, to: [activeCall])
        service.activeCalls.accept([conversation.accountId: tracker])

        XCTAssertEqual(service.outgoingCallURI(for: conversation), activeCall.constructURI())
    }

    func testOutgoingCallURIIsNilForGroupWithoutParticipants() {
        let service = makeService()
        let conversation = ConversationModel(withId: "conversation-id",
                                             accountId: "account-id",
                                             type: .invitesOnly)

        XCTAssertNil(service.outgoingCallURI(for: conversation))
    }

    private func makeGroupConversation() -> ConversationModel {
        let conversation = ConversationModel(withId: "conversation-id",
                                             accountId: "account-id",
                                             type: .invitesOnly)
        conversation.addParticipant(jamiId: "participant-id")
        return conversation
    }
}
