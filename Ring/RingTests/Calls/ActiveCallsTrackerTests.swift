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

final class ActiveCallsTrackerTests: XCTestCase {

    private let account1 = ActiveCallsTracker.AccountRef(id: accountId1, jamiId: jamiId1,
                                                         currentDeviceId: deviceId1)
    private let account2 = ActiveCallsTracker.AccountRef(id: accountId2, jamiId: jamiId2,
                                                         currentDeviceId: deviceId2)

    private func wireCall(id: String = CallTestFixtures.callId.raw,
                          uri: String = CallTestFixtures.peerUri,
                          device: String = CallTestFixtures.remoteDeviceId) -> [String: String] {
        return ["id": id, "uri": uri, "device": device]
    }

    private func rendezvousURI(conversationId: String = conversationId1,
                               uri: String = CallTestFixtures.peerUri,
                               device: String = CallTestFixtures.remoteDeviceId,
                               callId: String = CallTestFixtures.callId.raw) -> String {
        return "rdv:\(conversationId)/\(uri)/\(device)/\(callId)"
    }

    func testUpdateParsesValidCalls() {
        var tracker = ActiveCallsTracker()

        tracker.updateActiveCalls(conversationId: conversationId1,
                                  calls: [wireCall()], account: account1)

        let calls = tracker.trackers[accountId1]?.calls(for: conversationId1)
        XCTAssertEqual(calls?.count, 1)
        XCTAssertEqual(calls?.first?.id, CallTestFixtures.callId.raw)
        XCTAssertEqual(calls?.first?.accountId, accountId1)
        XCTAssertFalse(calls!.first!.isFromLocalDevice)
    }

    func testLocalDeviceDetection() {
        var tracker = ActiveCallsTracker()

        tracker.updateActiveCalls(conversationId: conversationId1,
                                  calls: [wireCall(uri: jamiId1, device: deviceId1)],
                                  account: account1)

        XCTAssertTrue(tracker.trackers[accountId1]!.calls(for: conversationId1)[0].isFromLocalDevice)
        XCTAssertFalse(tracker.hasRemoteActiveCalls())
    }

    func testInvalidEntriesAreSkipped() {
        var tracker = ActiveCallsTracker()

        tracker.updateActiveCalls(conversationId: conversationId1,
                                  calls: [["id": CallTestFixtures.secondaryCallId.raw], wireCall()], account: account1)

        XCTAssertEqual(tracker.trackers[accountId1]?.calls(for: conversationId1).count, 1)
    }

    func testEmptyUpdateClearsIgnoredAndAccepted() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1,
                                  calls: [wireCall()], account: account1)
        let call = tracker.trackers[accountId1]!.calls(for: conversationId1)[0]
        tracker.ignoreCall(call)

        tracker.updateActiveCalls(conversationId: conversationId1, calls: [], account: account1)

        XCTAssertTrue(tracker.trackers[accountId1]!.ignoredCalls(for: conversationId1).isEmpty)
    }

    func testIgnorePropagatesAcrossAccountsSharingTheSwarm() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account1)
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account2)

        let call = tracker.trackers[accountId1]!.calls(for: conversationId1)[0]
        tracker.ignoreCall(call)

        XCTAssertFalse(tracker.trackers[accountId1]!.notIgnoredCalls(for: conversationId1).contains(call))
        XCTAssertTrue(tracker.trackers[accountId2]!.notIgnoredCalls(for: conversationId1).isEmpty,
                      "same remote call ignored on the sibling account")
    }

    func testAcceptByUriPropagatesAcrossAccounts() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account1)
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account2)

        let rdvUri = rendezvousURI()
        tracker.acceptCall(uri: rdvUri)

        XCTAssertTrue(tracker.trackers[accountId1]!.notAcceptedCalls(for: conversationId1).isEmpty)
        XCTAssertTrue(tracker.trackers[accountId2]!.notAcceptedCalls(for: conversationId1).isEmpty)
        XCTAssertFalse(tracker.hasUnansweredRemoteCalls())
    }

    func testHangUpReopensAcceptedSlot() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account1)
        let rdvUri = rendezvousURI()
        tracker.acceptCall(uri: rdvUri)
        XCTAssertTrue(tracker.trackers[accountId1]!.notAcceptedCalls(for: conversationId1).isEmpty)

        tracker.activeCallHungUp(uri: rdvUri)

        XCTAssertEqual(tracker.trackers[accountId1]!.notAcceptedCalls(for: conversationId1).count, 1)
    }

    func testIgnoreDoesNotPropagateToDifferentRemoteCall() {
        var tracker = ActiveCallsTracker()
        let calls = [wireCall(), wireCall(id: CallTestFixtures.secondaryCallId.raw, device: CallTestFixtures.secondaryRemoteDeviceId)]
        tracker.updateActiveCalls(conversationId: conversationId1, calls: calls, account: account1)
        tracker.updateActiveCalls(conversationId: conversationId1, calls: calls, account: account2)

        let call = tracker.trackers[accountId1]!.calls(for: conversationId1)[0]
        tracker.ignoreCall(call)

        let remaining = tracker.trackers[accountId2]!.notIgnoredCalls(for: conversationId1)
        XCTAssertEqual(remaining.map(\.id), [CallTestFixtures.secondaryCallId.raw])
    }

    func testMultipleAccountsTrackedIndependently() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account1)
        tracker.updateActiveCalls(conversationId: conversationId2, calls: [wireCall(id: CallTestFixtures.secondaryCallId.raw)],
                                  account: account2)

        XCTAssertEqual(tracker.trackers[accountId1]?.calls(for: conversationId1).count, 1)
        XCTAssertEqual(tracker.trackers[accountId2]?.calls(for: conversationId2).count, 1)
        XCTAssertNil(tracker.trackers[accountId1]?.calls(for: conversationId2).first)
    }

    func testGetActiveCall() {
        var tracker = ActiveCallsTracker()
        tracker.updateActiveCalls(conversationId: conversationId1, calls: [wireCall()],
                                  account: account1)
        XCTAssertNotNil(tracker.activeCall(conversationId: conversationId1, accountId: accountId1))
        XCTAssertNil(tracker.activeCall(conversationId: conversationId2, accountId: accountId1))
    }
}
