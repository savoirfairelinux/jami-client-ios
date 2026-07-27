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
    private let peerId = CallTestFixtures.peerUri
    private let otherPeerId = CallTestFixtures.secondaryPeerUri
    private let unknownPeerId = CallTestFixtures.tertiaryPeerUri
    private let callId = CallTestFixtures.callId
    private let otherCallId = CallTestFixtures.secondaryCallId

    private func addPlaceholder(uuid: UUID = UUID(), peerId: String? = nil,
                                accountId: String = accountId1) -> UUID {
        _ = directory.addPlaceholder(uuid: uuid, peerId: peerId ?? self.peerId, accountId: accountId,
                                     displayName: "Alice", hasVideo: false)
        return uuid
    }

    func testPlaceholderIsTracked() {
        let uuid = addPlaceholder()
        XCTAssertTrue(directory.isTracked(uuid))
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId1), uuid)
        XCTAssertNil(directory.callId(for: uuid))
    }

    func testSecondPlaceholderForSamePeerReplacesFirst() {
        let first = addPlaceholder()
        let second = UUID()

        let replaced = directory.addPlaceholder(uuid: second, peerId: peerId,
                                                accountId: accountId1, displayName: "Alice",
                                                hasVideo: false)

        XCTAssertEqual(replaced, first, "old placeholder returned for CallKit teardown")
        XCTAssertFalse(directory.isTracked(first))
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId1), second)
    }

    func testPlaceholdersForSamePeerOnDifferentAccountsCoexist() {
        let onAcc1 = addPlaceholder(peerId: peerId, accountId: accountId1)
        let onAcc2 = UUID()

        let replaced = directory.addPlaceholder(uuid: onAcc2, peerId: peerId,
                                                accountId: accountId2, displayName: "Alice",
                                                hasVideo: false)

        XCTAssertNil(replaced, "a different account is a different call")
        XCTAssertTrue(directory.isTracked(onAcc1))
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId1), onAcc1)
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId2), onAcc2)
    }

    func testPlaceholderLookupIsScopedToAccount() {
        let uuid = addPlaceholder(peerId: peerId, accountId: accountId1)
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId1), uuid)
        XCTAssertNil(directory.placeholderUUID(peerId: peerId, accountId: accountId2))
    }

    func testPlaceholdersForDifferentPeersCoexist() {
        let first = addPlaceholder(peerId: peerId)
        let replaced = directory.addPlaceholder(uuid: UUID(), peerId: otherPeerId,
                                                accountId: accountId1, displayName: "Bob",
                                                hasVideo: true)
        XCTAssertNil(replaced)
        XCTAssertTrue(directory.isTracked(first))
    }

    func testMatchReusesPlaceholderUUID() {
        let uuid = addPlaceholder()

        let result = directory.match(peerId: peerId, accountId: accountId1, callId: callId)

        XCTAssertEqual(result?.uuid, uuid)
        XCTAssertNil(result?.pendingDecision, "no user action yet")
        XCTAssertEqual(directory.callId(for: uuid), callId)
        XCTAssertEqual(directory.uuid(for: callId), uuid)
        XCTAssertNil(directory.placeholderUUID(peerId: peerId, accountId: accountId1), "no longer a placeholder")
    }

    func testMatchUsesTheCallingAccount() {
        let onAcc1 = addPlaceholder(peerId: peerId, accountId: accountId1)
        let onAcc2 = addPlaceholder(uuid: UUID(), peerId: peerId, accountId: accountId2)

        let result = directory.match(peerId: peerId, accountId: accountId2,
                                     callId: otherCallId)

        XCTAssertEqual(result?.uuid, onAcc2)
        XCTAssertEqual(directory.placeholderUUID(peerId: peerId, accountId: accountId1), onAcc1,
                       "the other account's placeholder is untouched")
        XCTAssertEqual(directory.uuid(for: otherCallId), onAcc2)
    }

    func testDecisionDoesNotReplayOntoAnotherAccountsCall() {
        let onAcc1 = addPlaceholder(peerId: peerId, accountId: accountId1)
        _ = addPlaceholder(uuid: UUID(), peerId: peerId, accountId: accountId2)
        _ = directory.recordCallAction(uuid: onAcc1, .declined)

        let result = directory.match(peerId: peerId, accountId: accountId2,
                                     callId: otherCallId)

        XCTAssertNil(result?.pendingDecision, "acc1's decline belongs to acc1's call")
    }

    func testMatchWithUnknownAccountReturnsNil() {
        _ = addPlaceholder(peerId: peerId, accountId: accountId1)
        XCTAssertNil(directory.match(peerId: peerId, accountId: accountId2,
                                     callId: callId))
    }

    func testMatchWithoutPlaceholderReturnsNil() {
        XCTAssertNil(directory.match(peerId: unknownPeerId, accountId: accountId1, callId: callId))
    }

    func testDecisionBeforeLibJamiCallIsReplayedOnMatch() {
        let uuid = addPlaceholder()

        let outcome = directory.recordCallAction(uuid: uuid, .accepted(withVideo: true))
        XCTAssertEqual(outcome, .storedOnPlaceholder)

        let result = directory.match(peerId: peerId, accountId: accountId1, callId: callId)
        XCTAssertEqual(result?.pendingDecision, .accepted(withVideo: true))
    }

    func testDeclineBeforeLibJamiCallIsReplayedOnMatch() {
        let uuid = addPlaceholder()
        _ = directory.recordCallAction(uuid: uuid, .declined)

        let result = directory.match(peerId: peerId, accountId: accountId1, callId: callId)
        XCTAssertEqual(result?.pendingDecision, .declined)
    }

    func testDecisionOnLiveCallIsForwarded() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: callId)

        let outcome = directory.recordCallAction(uuid: uuid, .accepted(withVideo: false))

        XCTAssertEqual(outcome, .applyToCall(callId))
    }

    func testDecisionOnUnknownUUID() {
        XCTAssertEqual(directory.recordCallAction(uuid: UUID(), .declined), .unknownCall)
    }

    func testAttachAndLookup() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: callId)
        XCTAssertTrue(directory.isTracked(uuid))
        XCTAssertEqual(directory.uuid(for: callId), uuid)
    }

    func testRemoveAssociation() {
        let uuid = UUID()
        directory.attach(uuid: uuid, to: callId)

        directory.remove(uuid: uuid)

        XCTAssertFalse(directory.isTracked(uuid))
        XCTAssertNil(directory.uuid(for: callId))
    }

    func testExpireRemovesOnlyPlaceholders() {
        let uuid = addPlaceholder()
        XCTAssertTrue(directory.expirePlaceholder(uuid: uuid))
        XCTAssertFalse(directory.isTracked(uuid))
    }

    func testExpireIsNoOpForLiveCalls() {
        let uuid = addPlaceholder()
        _ = directory.match(peerId: peerId, accountId: accountId1, callId: callId)

        XCTAssertFalse(directory.expirePlaceholder(uuid: uuid))
        XCTAssertTrue(directory.isTracked(uuid))
    }

    func testAllPlaceholderUUIDsForTeardown() {
        let first = addPlaceholder(peerId: peerId)
        let second = addPlaceholder(uuid: UUID(), peerId: otherPeerId)
        directory.attach(uuid: UUID(), to: callId)

        XCTAssertEqual(Set(directory.allPlaceholderUUIDs()), Set([first, second]))
    }
}
