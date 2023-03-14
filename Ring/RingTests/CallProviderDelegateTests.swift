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
    var delegate: MockCallsProviderDelegate!

    override func setUpWithError() throws {
        let systemCalls = MocSystemCalls()
        delegate = MockCallsProviderDelegate(systemCalls: systemCalls)
        let provider = MockCXProvider(systemCalls: systemCalls)
        callProviderService = CallsProviderService(provider: provider, delegate: delegate)
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        callProviderService = nil
        delegate = nil
    }

    func testStopCall_WhenPendingCallExists() {
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        let unhandeledCall = callProviderService.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNotNil(unhandeledCall)
        callProviderService.stopCall(callUUID: unhandeledCall!.uuid, participant: jamiId1)

        let result = callProviderService.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNil(result)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertEqual(systemCalls?.count, 0)
            XCTAssertEqual(unhandeledCalls?.count, 0)
        }
    }

    func testStopCall_WhenPendingCallDoesNotExists() {
        let account = AccountModel()
        let call = CallModel()
        call.participantUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)
        callProviderService.stopCall(callUUID: call.callUUID, participant: jamiId1)

        let result = callProviderService.getUnhandeledCall(peerId: jamiId1)
        XCTAssertNil(result)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertEqual(systemCalls?.count, 0)
            XCTAssertEqual(unhandeledCalls?.count, 0)
        }
    }

    func testHandleIncomingCall_PendingExists() {
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        let account = AccountModel()
        let call = CallModel()
        call.participantUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertNotNil(systemCalls)
            XCTAssertEqual(systemCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls?.count, 0)
        }
    }

    func testHandleIncomingCall_PendingDoesNotExists() {
        let account = AccountModel()
        let call = CallModel()
        call.participantUri = jamiId1
        callProviderService.handleIncomingCall(account: account, call: call)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertNotNil(systemCalls)
            XCTAssertEqual(systemCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls?.count, 0)
        }
    }

    func testPreviewPendingCall_WhenCalledTwice() {
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            XCTAssertNotNil(unhandeledCalls)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertNotNil(systemCalls)
            XCTAssertEqual(systemCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls!.first?.uuid, systemCalls!.first?.uuid)
        }
    }

    func testPreviewPendingCall_WhenCalledOnce() {
        callProviderService.previewPendingCall(peerId: jamiId1, withVideo: false, displayName: "", completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let unhandeledCalls = self.callProviderService.getUnhandeledCalls(peerId: jamiId1)
            XCTAssertNotNil(unhandeledCalls)
            let systemCalls = self.delegate.getCalls(jamiId: jamiId1)
            XCTAssertNotNil(systemCalls)
            XCTAssertEqual(systemCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls!.count, 1)
            XCTAssertEqual(unhandeledCalls!.first?.uuid, systemCalls!.first?.uuid)
        }
    }
}
