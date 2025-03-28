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

    override func setUpWithError() throws {
        systemCallsHolder = MocSystemCalls()
        let provider = MockCXProvider(systemCalls: systemCallsHolder)
        let controller = MockCallController(systemCalls: systemCallsHolder)
        callProviderService = CallsProviderService(provider: provider, controller: controller)
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        callProviderService = nil
        systemCallsHolder = nil
        unhandeledCalls = nil
        systemCalls = nil
    }

    func testStopCall_WhenPendingCallExists() {
        // Arrange
        let expectation = self.expectation(description: "Should have no pending call and no system call")
        // Act
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
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
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
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
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
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
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        updateCalls(expectation: expectation, jamiId: jamiId1)
        waitForExpectations(timeout: 2, handler: nil)
        // Assert
        XCTAssertEqual(systemCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.count, 1)
        XCTAssertEqual(unhandeledCalls!.first?.uuid, systemCalls!.first?.uuid)
    }

    func updateCalls(expectation: XCTestExpectation, jamiId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId)
            self.systemCalls = self.systemCallsHolder.getCalls(jamiId: jamiId)
            expectation.fulfill()
        }
    }
}
