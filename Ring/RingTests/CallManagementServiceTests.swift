/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import RxSwift
import RxRelay
@testable import Ring

class CallManagementServiceTests: XCTestCase {

    private var callManagementService: CallManagementService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var calls: SynchronizedRelay<CallsDictionary>!
    private var callUpdates: ReplaySubject<CallModel>!
    private var responseStream: PublishSubject<ServiceEvent>!
    private var queueHelper: ThreadSafeQueueHelper!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!

    override func setUp() {
        super.setUp()
        setupMocks()
        setupService()
    }

    override func tearDown() {
        disposeBag = nil
        callManagementService = nil
        mockCallsAdapter = nil
        calls = nil
        callUpdates = nil
        responseStream = nil
        queueHelper = nil
        testCall = nil
        super.tearDown()
    }

    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)
        responseStream = PublishSubject<ServiceEvent>()
        queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagementTest", qos: .userInitiated)
        calls = SynchronizedRelay<CallsDictionary>(initialValue: [:], queueHelper: queueHelper)
        disposeBag = DisposeBag()
    }

    private func setupService() {
        callManagementService = CallManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            callUpdates: callUpdates,
            responseStream: responseStream
        )
    }

    // MARK: - Tests

    func testAddCall() {
        let callId = CallTestConstants.callId
        let callState = CallState.ringing
        let callDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: CallTestConstants.accountId
        ]

        let mediaList = [TestMediaFactory.createAudioMedia()]

        let callUpdatesExpectation = XCTestExpectation(description: "Call updates emission")

        callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                callUpdatesExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        let result = callManagementService.addOrUpdateCall(
            callId: callId,
            callState: callState,
            callDictionary: callDictionary,
            mediaList: mediaList
        )

        wait(for: [callUpdatesExpectation], timeout: 1.0)

        XCTAssertNotNil(result, "Call should be returned")
        XCTAssertEqual(result?.callId, callId, "Call ID should match")
        XCTAssertEqual(result?.state, callState, "Call state should match")
        XCTAssertEqual(result?.displayName, CallTestConstants.displayName, "Display name should match")
        XCTAssertEqual(result?.mediaList.count, mediaList.count, "Media list should match")

        XCTAssertEqual(calls.get().count, 1, "Call should be added to store")
        XCTAssertNotNil(calls.get()[callId], "Call should be in store with correct ID")
    }

    func testUpdateCall() {
        let callId = CallTestConstants.callId
        let initialState = CallState.ringing
        let updatedState = CallState.current

        let initialCall = CallModel.createTestCall()
        initialCall.state = initialState

        calls.update { calls in
            calls[callId] = initialCall
        }

        let updatedCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: "Updated Name",
            CallDetailKey.accountIdKey.rawValue: CallTestConstants.accountId
        ]

        let callUpdatesExpectation = XCTestExpectation(description: "Call updates emission")

        callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                callUpdatesExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        let result = callManagementService.addOrUpdateCall(
            callId: callId,
            callState: updatedState,
            callDictionary: updatedCallDictionary
        )

        wait(for: [callUpdatesExpectation], timeout: 1.0)

        XCTAssertNotNil(result, "Updated call should be returned")
        XCTAssertEqual(result?.state, updatedState, "Call state should be updated")
        XCTAssertEqual(result?.displayName, "Updated Name", "Call details should be updated")
    }

    func testRemoveCall() async {
        let call = CallModel.createTestCall()
        call.state = .current
        call.dateReceived = Date(timeIntervalSinceNow: -60) // Call started 1 minute ago

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }

        var capturedEvent: ServiceEvent?
        responseStream
            .take(1)
            .subscribe(onNext: { event in
                capturedEvent = event
            })
            .disposed(by: disposeBag)

        await callManagementService.removeCall(callId: CallTestConstants.callId, callState: .over)

        XCTAssertEqual(calls.get().count, 0, "Call should be removed from store")
        XCTAssertNotNil(capturedEvent, "Event should be emitted")
        XCTAssertEqual(capturedEvent!.eventType, .callEnded, "Event type should be callEnded")
    }

    func testRemoveCall_WithInvalidCallId() async {
        let call = CallModel.createTestCall()
        call.state = .current
        call.dateReceived = Date(timeIntervalSinceNow: -60) // Call started 1 minute ago

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }
        await callManagementService.removeCall(callId: "invalid-id", callState: .over)
        XCTAssertEqual(calls.get().count, 1, "Call store should remain 1")
    }

    func testUpdateCallUUID_WithValidData() async {
        let call = CallModel.createTestCall()
        let originalUUID = call.callUUID

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }

        let newUUIDString = UUID().uuidString

        await callManagementService.updateCallUUID(callId: CallTestConstants.callId, callUUID: newUUIDString)

        let updatedCall = calls.get()[CallTestConstants.callId]
        XCTAssertNotNil(updatedCall, "Call should still exist in store")
        XCTAssertNotEqual(updatedCall?.callUUID, originalUUID, "UUID should have changed")
        XCTAssertEqual(updatedCall?.callUUID.uuidString, newUUIDString, "UUID should match new value")
    }

    func testAccept() {
        let call = CallModel.createTestCall()
        call.mediaList = [TestMediaFactory.createAudioMedia()]

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }

        mockCallsAdapter.acceptCallReturnValue = true

        let expectation = XCTestExpectation(description: "Accept call completes")

        callManagementService.accept(callId: CallTestConstants.callId)
            .subscribe(
                onCompleted: {
                    expectation.fulfill()
                },
                onError: { error in
                    XCTFail("Accept call should not fail: \(error)")
                }
            )
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mockCallsAdapter.acceptCallIdCount, 1, "Accept call should be called once")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdCallId, CallTestConstants.callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdAccountId, CallTestConstants.accountId, "Account ID should match")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdMediaList?.count, 1, "Media list should match")
    }

    func testRefuse() {
        let call = CallModel.createTestCall()

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }

        mockCallsAdapter.refuseCallReturnValue = true

        let expectation = XCTestExpectation(description: "Refuse call completes")

        callManagementService.refuse(callId: CallTestConstants.callId)
            .subscribe(
                onCompleted: {
                    expectation.fulfill()
                },
                onError: { error in
                    XCTFail("Refuse call should not fail: \(error)")
                }
            )
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mockCallsAdapter.refuseCallIdCount, 1, "Refuse call should be called once")
        XCTAssertEqual(mockCallsAdapter.refuseCallIdCallId, CallTestConstants.callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.refuseCallIdAccountId, CallTestConstants.accountId, "Account ID should match")
    }

    func testHangUp() {
        let call = CallModel.createTestCall()

        calls.update { calls in
            calls[CallTestConstants.callId] = call
        }

        mockCallsAdapter.hangUpCallReturnValue = true

        let expectation = XCTestExpectation(description: "Hang up call completes")

        callManagementService.hangUp(callId: CallTestConstants.callId)
            .subscribe(
                onCompleted: {
                    expectation.fulfill()
                },
                onError: { error in
                    XCTFail("Hang up call should not fail: \(error)")
                }
            )
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(mockCallsAdapter.hangUpCallCallCount, 1, "Hang up call should be called once")
        XCTAssertEqual(mockCallsAdapter.hangUpCallCallId, CallTestConstants.callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.hangUpCallAccountId, CallTestConstants.accountId, "Account ID should match")
    }

    func testPlaceCall_Success() {
        let account = AccountModel.createTestAccount()
        let participantId = CallTestConstants.participantUri
        let userName = CallTestConstants.displayName
        let videoSource = "camera"

        mockCallsAdapter.placeCallReturnValue = CallTestConstants.callId
        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.displayNameKey.rawValue: userName,
            CallDetailKey.accountIdKey.rawValue: account.id
        ]

        let expectation = XCTestExpectation(description: "Place call completes")

        var resultCall: CallModel?

        callManagementService.placeCall(
            withAccount: account,
            toParticipantId: participantId,
            userName: userName,
            videoSource: videoSource,
            isAudioOnly: false,
            withMedia: []
        )
        .subscribe(
            onSuccess: { call in
                resultCall = call
                expectation.fulfill()
            },
            onFailure: { error in
                XCTFail("Place call should not fail: \(error)")
            }
        )
        .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertNotNil(resultCall, "Call model should be returned")
        XCTAssertEqual(resultCall?.callId, CallTestConstants.callId, "Call ID should match")
        XCTAssertEqual(resultCall?.displayName, userName, "Display name should match")
        XCTAssertEqual(resultCall?.accountId, account.id, "Account ID should match")
        XCTAssertEqual(resultCall?.callType, .outgoing, "Call type should be outgoing")

        XCTAssertEqual(mockCallsAdapter.placeCallAccountIdCount, 1, "Place call should be called once")
        XCTAssertEqual(mockCallsAdapter.placeCallAccountId, account.id, "Account ID should match")
        XCTAssertEqual(mockCallsAdapter.placeCallParticipantId, participantId, "Participant ID should match")
    }
}

extension ObjCMockCallsAdapter {
    var acceptCallIdCount: Int {
        return Int(self.acceptCallWithIdCount)
    }

    var acceptCallIdCallId: String? {
        return self.acceptCallWithIdCallId
    }

    var acceptCallIdAccountId: String? {
        return self.acceptCallWithIdAccountId
    }

    var acceptCallIdMediaList: [[String: String]]? {
        return self.acceptCallWithIdMediaList as? [[String: String]]
    }

    var refuseCallIdCount: Int {
        return Int(self.refuseCallWithIdCount)
    }

    var refuseCallIdCallId: String? {
        return self.refuseCallWithIdCallId
    }

    var refuseCallIdAccountId: String? {
        return self.refuseCallWithIdAccountId
    }

    var placeCallAccountIdCount: Int {
        return Int(self.placeCallWithAccountIdCount)
    }

    var placeCallAccountId: String? {
        return self.placeCallWithAccountIdAccountId
    }

    var placeCallParticipantId: String? {
        return self.placeCallWithAccountIdToParticipantId
    }
}
