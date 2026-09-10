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

    private var pendingReports: [(Error?) -> Void] = []

    override func reportNewIncomingCall(with uuid: UUID, update: CXCallUpdate,
                                        completion: @escaping (Error?) -> Void) {
        pendingReports.append(completion)
    }

    /// CallKit answers a report on its delegate queue, after the submit returned.
    func completeReport(at index: Int) {
        pendingReports[index](incomingCallError)
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

    /// The placeholder is recorded on the main queue, after the report is submitted.
    private func drainMainQueue() {
        let drained = expectation(description: "pending main-queue work ran")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    func testEndAllCallsOnTerminationStopsPendingCallsAndInvalidatesProvider() {
        service.previewPendingCall(peerId: CallTestFixtures.peerUri, accountId: accountId1,
                                   displayName: profileName1, hasVideo: false, completion: nil)
        drainMainQueue()
        XCTAssertFalse(service.directory.allPlaceholderUUIDs().isEmpty)

        service.endAllCallsOnTermination()

        XCTAssertTrue(service.directory.allPlaceholderUUIDs().isEmpty,
                      "placeholders dropped before the process leaves")
        XCTAssertEqual(provider.invalidateCount, 1,
                       "provider invalidated so CallKit ends its calls synchronously")
    }

    func testFailedPendingCallReportDeclinesMatchingIncomingCall() throws {
        provider.incomingCallError = NSError(domain: "CallKit", code: 1)
        let call = CallTestFixtures.call(direction: .incoming, status: .ringing)
        var endedCallIds: [CallId] = []
        service.onAction = { action in
            guard case .end(let callId) = action else {
                XCTFail("a rejected report must only end the matching call")
                return
            }
            endedCallIds.append(callId)
        }

        service.previewPendingCall(peerId: call.peerHash, accountId: call.accountId,
                                   displayName: profileName1, hasVideo: false, completion: nil)
        drainMainQueue()
        provider.completeReport(at: 0)

        let uuid = try XCTUnwrap(service.directory.placeholderUUID(peerId: call.peerHash,
                                                                   accountId: call.accountId))
        XCTAssertEqual(service.directory.placeholder(uuid: uuid)?.decision, .declined)
        XCTAssertTrue(endedCallIds.isEmpty,
                      "the decline waits until libjami reports the call")

        let handle = CallKitHandle(value: call.peerUri, displayName: profileName1,
                                   isPhoneNumber: false)
        service.reportIncomingCall(call, handle: handle)

        XCTAssertEqual(endedCallIds, [call.id])
        XCTAssertEqual(service.directory.uuid(for: call.id), uuid,
                       "the matching call reuses the rejected placeholder")
        XCTAssertTrue(service.directory.allPlaceholderUUIDs().isEmpty,
                      "the placeholder is consumed when the call arrives")
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
