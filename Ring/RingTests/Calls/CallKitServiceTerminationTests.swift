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

import CallKit
import XCTest
@testable import Ring

private final class MockCXProvider: CXProvider {

    private(set) var invalidateCount = 0
    private(set) var outgoingCallUUIDs: [UUID] = []
    private(set) var endedCalls: [(uuid: UUID, reason: CXCallEndedReason)] = []
    var incomingCallError: Error?

    init() {
        super.init(configuration: CXProviderConfiguration())
    }

    override func invalidate() {
        invalidateCount += 1
    }

    override func reportNewIncomingCall(with uuid: UUID, update: CXCallUpdate,
                                        completion: @escaping (Error?) -> Void) {
        completion(incomingCallError)
    }

    override func reportCall(with uuid: UUID, endedAt dateEnded: Date?,
                             reason endedReason: CXCallEndedReason) {
        endedCalls.append((uuid, endedReason))
    }

    override func reportOutgoingCall(with uuid: UUID, startedConnectingAt dateStartedConnecting: Date?) {
        outgoingCallUUIDs.append(uuid)
    }
}

private final class MockCXCallController: CXCallController {

    private var completions: [(Error?) -> Void] = []

    override func request(_ transaction: CXTransaction,
                          completion: @escaping (Error?) -> Void) {
        completions.append(completion)
    }

    func completeRequest(at index: Int, error: Error? = nil) {
        completions[index](error)
    }
}

final class CallKitServiceTerminationTests: XCTestCase {

    private var provider = MockCXProvider()
    private var service: CallKitService!

    override func setUp() {
        super.setUp()
        provider = MockCXProvider()
        service = CallKitService(provider: provider)
    }

    func testEndAllCallsOnTerminationStopsPendingCallsAndInvalidatesProvider() {
        service.previewPendingCall(peerId: CallTestFixtures.peerUri, accountId: accountId1,
                                   displayName: profileName1, hasVideo: false, completion: nil)
        XCTAssertFalse(service.directory.allPlaceholderUUIDs().isEmpty)

        service.endAllCallsOnTermination()

        XCTAssertTrue(service.directory.allPlaceholderUUIDs().isEmpty,
                      "placeholders dropped before the process leaves")
        XCTAssertEqual(provider.invalidateCount, 1,
                       "provider invalidated so CallKit ends its calls synchronously")
    }

    func testFailedPendingCallReportRemovesPlaceholder() {
        provider.incomingCallError = NSError(domain: "CallKit", code: 1)

        service.previewPendingCall(peerId: CallTestFixtures.peerUri, accountId: accountId1,
                                   displayName: profileName1, hasVideo: false, completion: nil)

        XCTAssertTrue(service.directory.allPlaceholderUUIDs().isEmpty,
                      "a rejected report must not leave a phantom call to match later")
    }

    func testCompletedStartTransactionDoesNotReviveEndedOutgoingCall() {
        let callController = MockCXCallController()
        service = CallKitService(provider: provider, callController: callController)
        let call = CallTestFixtures.call(direction: .outgoing, status: .connecting)
        let handle = CallKitHandle(value: call.peerUri, displayName: profileName1,
                                   isPhoneNumber: false)

        service.reportOutgoingCallStarted(call, handle: handle)
        service.reportCallEnded(call.id, isRemoteEnd: false)
        callController.completeRequest(at: 0)

        XCTAssertTrue(provider.outgoingCallUUIDs.isEmpty,
                      "a completed start transaction must not revive an ended call")
        XCTAssertEqual(provider.endedCalls.map(\.reason), [.failed])
    }
}
