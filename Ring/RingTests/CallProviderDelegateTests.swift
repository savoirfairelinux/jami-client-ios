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
import CallKit
@testable import Ring

final class CallProviderDelegateTests: XCTestCase {
    var callProviderService: CallsProviderService!
    var unhandeledCalls: [UnhandeledCall]?
    var systemCalls: [MockCall]?
    var systemCallsHolder: MocSystemCalls!
    var mockProvider: MockCXProvider!
    var mockController: MockCallController!

    override func setUpWithError() throws {
        systemCallsHolder = MocSystemCalls()
        mockProvider = MockCXProvider(systemCalls: systemCallsHolder)
        mockController = MockCallController(systemCalls: systemCallsHolder)
        callProviderService = CallsProviderService(provider: mockProvider, controller: mockController)
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        callProviderService = nil
        systemCallsHolder = nil
        unhandeledCalls = nil
        systemCalls = nil
        mockProvider = nil
        mockController = nil
    }

    func testStopCall_WhenPendingCallExists() {
        // Arrange
        let expectation = self.expectation(description: "Should have no pending call and no system call")
        // Act
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        let unhandeledCall = callProviderService.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNotNil(unhandeledCall)
        callProviderService.stopCall(callUUID: unhandeledCall!.uuid, participant: jamiId1)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls?.count, 0)
        XCTAssertEqual(unhandeledCalls?.count, 0)
    }

    func testStopCall_WhenPendingCallDoesNotExists() {
        // Arrange
        let expectation = self.expectation(description: "Should have no pending call and no system call")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        // Act
        callProviderService.handleIncomingCall(account: account, call: call)
        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls?.count, 0)
        XCTAssertEqual(unhandeledCalls?.count, 0)
    }

    func testHandleIncomingCall_PendingExists() {
        // Arrange
        let expectation = self.expectation(description: "Should have no pending call and one system call")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        // Act
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        callProviderService.handleIncomingCall(account: account, call: call)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.count, 0)
    }

    func testHandleIncomingCall_PendingDoesNotExists() {
        // Arrange
        let expectation = self.expectation(description: "Should have no pending call and one system call")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        // Act
        callProviderService.handleIncomingCall(account: account, call: call)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.count, 0)
    }

    func testPreviewPendingCall_WhenCalledTwice() {
        // Arrange
        let expectation = self.expectation(description: "Should have one pending call and one system call")
        // Act
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.first?.uuid, systemCalls!.first?.uuid)
    }

    func testPreviewPendingCall_WhenCalledOnce() {
        // Arrange
        let expectation = self.expectation(description: "Should have one pending call and one system call")
        // Act
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.first?.uuid, systemCalls!.first?.uuid)
    }

    // MARK: - Outgoing call declined tests

    func testStopCall_OutgoingCallDeclined_CallKitEndsCall() {
        let expectation = self.expectation(description: "CallKit should end the outgoing call")
        let account = AccountModel()
        account.id = "testAccountId"
        let call = CallModel()
        call.callUri = jamiId1
        call.displayName = "Test User"
        call.callType = .outgoing

        callProviderService.startCall(account: account, call: call)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1, isRemoteEnd: true)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)

        XCTAssertEqual(systemCalls?.count, 0, "CallKit should have no active calls after remote decline")
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 1, "Should report call ended for outgoing declined call")
        XCTAssertEqual(mockProvider.reportedEndedCalls.first?.reason, .remoteEnded)
    }

    func testStartCall_TransactionFails_CleansUpUUID() {
        let account = AccountModel()
        account.id = "testAccountId"
        let call = CallModel()
        call.callUri = jamiId1
        call.displayName = "Test User"
        call.callType = .outgoing

        mockController.shouldFailNextRequest = true
        callProviderService.startCall(account: account, call: call)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1, isRemoteEnd: true)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 0, "No reportCall should be made for a failed start")
    }

    // MARK: - Remote end call tests

    func testStopCall_RemoteEnd_UsesReportCallInsteadOfEndAction() {
        let expectation = self.expectation(description: "Should report call ended via provider")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1, isRemoteEnd: true)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)

        XCTAssertEqual(systemCalls?.count, 0)
        XCTAssertEqual(unhandeledCalls?.count, 0)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 1, "Should use reportCall for remote-ended calls")
        XCTAssertEqual(mockProvider.reportedEndedCalls.first?.reason, .remoteEnded, "Reason should be .remoteEnded")
    }

    func testStopCall_LocalEnd_UsesCXEndCallAction() {
        let expectation = self.expectation(description: "Should use CXEndCallAction")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)

        XCTAssertEqual(systemCalls?.count, 0)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 0, "Should NOT use reportCall for local-ended calls")
    }

    func testStopCall_RemoteEnd_PendingCallWithDifferentUUID() {
        let expectation = self.expectation(description: "Should report both calls ended")
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", accountId: "testAccountId", completion: nil)
        let unhandeledCall = callProviderService.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNotNil(unhandeledCall)

        let differentUUID = UUID()
        callProviderService.stopCall(callUUID: differentUUID, participant: jamiId1, isRemoteEnd: true)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)

        XCTAssertEqual(unhandeledCalls?.count, 0)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 1, "Should only report unhandled call; differentUUID was never registered with CallKit")
    }

    func testStopCall_AlreadyEndedCall_IsNoOp() {
        let expectation = self.expectation(description: "Should be no-op for already ended call")
        let account = AccountModel()
        let call = CallModel()
        call.callUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1, isRemoteEnd: true)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 1)

        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1, isRemoteEnd: true)

        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)

        XCTAssertEqual(systemCalls?.count, 0)
        XCTAssertEqual(mockProvider.reportedEndedCalls.count, 1, "Second stopCall should be a no-op")
    }

    // MARK: - Outgoing call lifecycle reporting tests

    func testReportOutgoingCallConnecting_ReportsToCallKit() {
        let account = AccountModel()
        account.id = "testAccountId"
        let call = CallModel()
        call.callUri = jamiId1
        call.displayName = "Test User"
        call.callType = .outgoing

        callProviderService.startCall(account: account, call: call)

        let initialConnectingReports = mockProvider.reportedOutgoingConnecting.count
        callProviderService.reportOutgoingCallConnecting(callUUID: call.callUUID)
        XCTAssertEqual(
            mockProvider.reportedOutgoingConnecting.count,
            initialConnectingReports + 1,
            "Should report outgoing call connecting exactly once for this call"
        )
        XCTAssertEqual(mockProvider.reportedOutgoingConnecting.last, call.callUUID)
    }

    func testReportOutgoingCallConnected_ReportsToCallKit() {
        let account = AccountModel()
        account.id = "testAccountId"
        let call = CallModel()
        call.callUri = jamiId1
        call.displayName = "Test User"
        call.callType = .outgoing

        callProviderService.startCall(account: account, call: call)
        let beforeCount = mockProvider.reportedOutgoingConnected.count

        callProviderService.reportOutgoingCallConnected(callUUID: call.callUUID)

        XCTAssertEqual(mockProvider.reportedOutgoingConnected.count, beforeCount + 1,
                       "reportOutgoingCallConnected should produce exactly one CallKit report")
        XCTAssertEqual(mockProvider.reportedOutgoingConnected.last, call.callUUID)
    }

    func testReportOutgoingCallConnecting_UnknownUUID_IsNoOp() {
        let unknownUUID = UUID()
        callProviderService.reportOutgoingCallConnecting(callUUID: unknownUUID)
        XCTAssertEqual(mockProvider.reportedOutgoingConnecting.count, 0, "Should not report for unknown UUID")
    }

    func testReportOutgoingCallConnected_UnknownUUID_IsNoOp() {
        let unknownUUID = UUID()
        callProviderService.reportOutgoingCallConnected(callUUID: unknownUUID)
        XCTAssertEqual(mockProvider.reportedOutgoingConnected.count, 0, "Should not report for unknown UUID")
    }

    func updateCalls(expectation: XCTestExpectation, jamiId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId)
            self.systemCalls = self.systemCallsHolder.getCalls(jamiId: jamiId)
            expectation.fulfill()
        }
    }
}
