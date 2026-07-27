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

final class CallKitDirectoryTests: XCTestCase {

    private var directory = CallKitDirectory()

    private func addPlaceholder(uuid: UUID = UUID(), peerId: String = "peer1",
                                accountId: String = accountId1) -> UUID {
        _ = directory.addPlaceholder(uuid: uuid, peerId: peerId, accountId: accountId,
                                     displayName: "Alice", hasVideo: false)
        return uuid
    }

    func testPlaceholderIsTracked() {
        let uuid = addPlaceholder()
        XCTAssertTrue(directory.isTracked(uuid))
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), uuid)
        XCTAssertNil(directory.callId(for: uuid))
    }

    func testSecondPlaceholderForSamePeerReplacesFirst() {
        let first = addPlaceholder()
        let second = UUID()

        let replaced = directory.addPlaceholder(uuid: second, peerId: "peer1",
                                                accountId: accountId1, displayName: "Alice",
                                                hasVideo: false)

        XCTAssertEqual(replaced, first, "old placeholder returned for CallKit teardown")
        XCTAssertFalse(directory.isTracked(first))
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), second)
    }

    func testPlaceholdersForSamePeerOnDifferentAccountsCoexist() {
        let onAcc1 = addPlaceholder(peerId: "peer1", accountId: accountId1)
        let onAcc2 = UUID()

        let replaced = directory.addPlaceholder(uuid: onAcc2, peerId: "peer1",
                                                accountId: accountId2, displayName: "Alice",
                                                hasVideo: false)

        XCTAssertNil(replaced, "a different account is a different call")
        XCTAssertTrue(directory.isTracked(onAcc1))
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), onAcc1)
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId2), onAcc2)
    }

    func testPlaceholderLookupIsScopedToAccount() {
        let uuid = addPlaceholder(peerId: "peer1", accountId: accountId1)
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), uuid)
        XCTAssertNil(directory.placeholderUUID(peerId: "peer1", accountId: accountId2))
    }

    func testPlaceholdersForDifferentPeersCoexist() {
        let first = addPlaceholder(peerId: "peer1")
        let replaced = directory.addPlaceholder(uuid: UUID(), peerId: "peer2",
                                                accountId: accountId1, displayName: "Bob",
                                                hasVideo: true)
        XCTAssertNil(replaced)
        XCTAssertTrue(directory.isTracked(first))
    }

    func testMatchReusesPlaceholderUUID() {
        let uuid = addPlaceholder()

        let result = directory.match(peerId: "peer1", accountId: accountId1, callId: CallId(raw: "call-1"))

        XCTAssertEqual(result?.uuid, uuid)
        XCTAssertNil(result?.pendingDecision, "no user action yet")
        XCTAssertEqual(directory.callId(for: uuid), CallId(raw: "call-1"))
        XCTAssertEqual(directory.uuid(for: CallId(raw: "call-1")), uuid)
        XCTAssertNil(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), "no longer a placeholder")
    }

    func testMatchUsesTheCallingAccount() {
        let onAcc1 = addPlaceholder(peerId: "peer1", accountId: accountId1)
        let onAcc2 = addPlaceholder(uuid: UUID(), peerId: "peer1", accountId: accountId2)

        let result = directory.match(peerId: "peer1", accountId: accountId2,
                                     callId: CallId(raw: "call-on-acc2"))

        XCTAssertEqual(result?.uuid, onAcc2)
        XCTAssertEqual(directory.placeholderUUID(peerId: "peer1", accountId: accountId1), onAcc1,
                       "the other account's placeholder is untouched")
        XCTAssertEqual(directory.uuid(for: CallId(raw: "call-on-acc2")), onAcc2)
    }

    func testDecisionDoesNotReplayOntoAnotherAccountsCall() {
        let onAcc1 = addPlaceholder(peerId: "peer1", accountId: accountId1)
        _ = addPlaceholder(uuid: UUID(), peerId: "peer1", accountId: accountId2)
        _ = directory.recordCallAction(uuid: onAcc1, .declined)

        let result = directory.match(peerId: "peer1", accountId: accountId2,
                                     callId: CallId(raw: "call-on-acc2"))

        XCTAssertNil(result?.pendingDecision, "acc1's decline belongs to acc1's call")
    }

    func testMatchWithUnknownAccountReturnsNil() {
        _ = addPlaceholder(peerId: "peer1", accountId: accountId1)
        XCTAssertNil(directory.match(peerId: "peer1", accountId: "acc9",
                                     callId: CallId(raw: "c")))
    }

    func testMatchWithoutPlaceholderReturnsNil() {
        XCTAssertNil(directory.match(peerId: "stranger", accountId: accountId1, callId: CallId(raw: "c")))
    }

    func testDecisionBeforeLibJamiCallIsReplayedOnMatch() {
        let uuid = addPlaceholder()

        let outcome = directory.recordCallAction(uuid: uuid, .accepted(withVideo: true))
        XCTAssertEqual(outcome, .storedOnPlaceholder)

        let result = directory.match(peerId: "peer1", accountId: accountId1, callId: CallId(raw: "call-1"))
        XCTAssertEqual(result?.pendingDecision, .accepted(withVideo: true))
    }

    func testDeclineBeforeLibJamiCallIsReplayedOnMatch() {
        let uuid = addPlaceholder()
        _ = directory.recordCallAction(uuid: uuid, .declined)

        let result = directory.match(peerId: "peer1", accountId: accountId1, callId: CallId(raw: "call-1"))
        XCTAssertEqual(result?.pendingDecision, .declined)
    }

    func testDecisionOnLiveCallIsForwarded() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: CallId(raw: "call-1"))

        let outcome = directory.recordCallAction(uuid: uuid, .accepted(withVideo: false))

        XCTAssertEqual(outcome, .applyToCall(CallId(raw: "call-1")))
    }

    func testDecisionOnUnknownUUID() {
        XCTAssertEqual(directory.recordCallAction(uuid: UUID(), .declined), .unknownCall)
    }

    func testAttachAndLookup() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: CallId(raw: "out-1"))
        XCTAssertTrue(directory.isTracked(uuid))
        XCTAssertEqual(directory.uuid(for: CallId(raw: "out-1")), uuid)
    }

    func testRemoveAssociation() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: CallId(raw: "out-1"))

        directory.remove(uuid: uuid)

        XCTAssertFalse(directory.isTracked(uuid))
        XCTAssertNil(directory.uuid(for: CallId(raw: "out-1")))
    }

    func testExpireRemovesOnlyPlaceholders() {
        let uuid = addPlaceholder()
        XCTAssertTrue(directory.expirePlaceholder(uuid: uuid))
        XCTAssertFalse(directory.isTracked(uuid))
    }

    func testExpireIsNoOpForLiveCalls() {
        let uuid = addPlaceholder()
        _ = directory.match(peerId: "peer1", accountId: accountId1, callId: CallId(raw: "call-1"))

        XCTAssertFalse(directory.expirePlaceholder(uuid: uuid))
        XCTAssertTrue(directory.isTracked(uuid))
    }

    func testAllPlaceholderUUIDsForTeardown() {
        let first = addPlaceholder(peerId: "peer1")
        let second = addPlaceholder(uuid: UUID(), peerId: "peer2")
        directory.attach(uuid: UUID(), to: CallId(raw: "live"))

        XCTAssertEqual(Set(directory.allPlaceholderUUIDs()), Set([first, second]))
    }
}
