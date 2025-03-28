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
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var callUpdates: ReplaySubject<CallModel>!
    private var responseStream: PublishSubject<ServiceEvent>!
    private var queueHelper: ThreadSafeQueueHelper!
    private var disposeBag: DisposeBag!
    
    override func setUp() {
        super.setUp()
        mockCallsAdapter = ObjCMockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)
        responseStream = PublishSubject<ServiceEvent>()
        queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagementTest", qos: .userInitiated)
        disposeBag = DisposeBag()
        
        callManagementService = CallManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            callUpdates: callUpdates,
            responseStream: responseStream,
            queueHelper: queueHelper
        )
    }
    
    override func tearDown() {
        disposeBag = nil
        callManagementService = nil
        mockCallsAdapter = nil
        calls = nil
        callUpdates = nil
        responseStream = nil
        queueHelper = nil
        super.tearDown()
    }
    
    func testAddOrUpdateCall_WithNewCall_AddsToCallsStore() {
        let callId = CallTestConstants.callId
        let callState = CallState.ringing
        let callDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: CallTestConstants.accountId
        ]
        
        let mediaList = [TestMediaFactory.createAudioMedia()]
        
        let callUpdatesExpectation = XCTestExpectation(description: "Call updates emission")
        
        // Listen for call updates from the service
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
        
        // Wait for call updates
        wait(for: [callUpdatesExpectation], timeout: 1.0)
        
        XCTAssertNotNil(result, "Call should be returned")
        XCTAssertEqual(result?.callId, callId, "Call ID should match")
        XCTAssertEqual(result?.state, callState, "Call state should match")
        XCTAssertEqual(result?.displayName, CallTestConstants.displayName, "Display name should match")
        XCTAssertEqual(result?.mediaList.count, mediaList.count, "Media list should match")
        
        XCTAssertEqual(calls.value.count, 1, "Call should be added to store")
        XCTAssertNotNil(calls.value[callId], "Call should be in store with correct ID")
    }
    
    func testAddOrUpdateCall_WithExistingCall_UpdatesCall() {
        let callId = CallTestConstants.callId
        let initialState = CallState.ringing
        let updatedState = CallState.current
        
        let initialCall = CallModel.createTestCall()
        initialCall.state = initialState
        
        var callsDict = [String: CallModel]()
        callsDict[callId] = initialCall
        calls.accept(callsDict)
        
        let updatedCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: "Updated Name",
            CallDetailKey.accountIdKey.rawValue: CallTestConstants.accountId
        ]
        
        let callUpdatesExpectation = XCTestExpectation(description: "Call updates emission")
        
        // Listen for call updates from the service
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
        
        // Wait for call updates
        wait(for: [callUpdatesExpectation], timeout: 1.0)
        
        XCTAssertNotNil(result, "Updated call should be returned")
        XCTAssertEqual(result?.state, updatedState, "Call state should be updated")
        XCTAssertEqual(result?.displayName, "Updated Name", "Call details should be updated")
    }
    
    func testAddOrUpdateCall_WithInactiveNewCallState_ReturnsNil() {
        let result = callManagementService.addOrUpdateCall(
            callId: CallTestConstants.callId,
            callState: .over,
            callDictionary: [:]
        )
        
        XCTAssertNil(result, "Inactive new call should not be added")
        XCTAssertEqual(calls.value.count, 0, "Call store should remain empty")
    }
    
    func testRemoveCall_WithValidCallId_RemovesFromStore() async {
        let call = CallModel.createTestCall()
        call.state = .current
        call.dateReceived = Date(timeIntervalSinceNow: -60) // Call started 1 minute ago
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        var capturedEvent: ServiceEvent?
        responseStream
            .take(1)
            .subscribe(onNext: { event in
                capturedEvent = event
            })
            .disposed(by: disposeBag)
        
        await callManagementService.removeCall(callId: CallTestConstants.callId, callState: .over)
        
        XCTAssertEqual(calls.value.count, 0, "Call should be removed from store")
        XCTAssertNotNil(capturedEvent, "Event should be emitted")
        XCTAssertEqual(capturedEvent!.eventType, .callEnded, "Event type should be callEnded")
    }
    
    func testRemoveCall_WithInvalidState_DoesNotRemoveCall() async {
        let call = CallModel.createTestCall()
        call.state = .current
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        let capturedEventsCount = PublishSubject<Int>()
        var eventsCount = 0
        
        responseStream
            .subscribe(onNext: { _ in
                eventsCount += 1
                capturedEventsCount.onNext(eventsCount)
            })
            .disposed(by: disposeBag)
        
        await callManagementService.removeCall(callId: CallTestConstants.callId, callState: .ringing)
        
        XCTAssertEqual(calls.value.count, 1, "Call should not be removed with invalid state")
        
        let expectation = XCTestExpectation(description: "Wait for potential events")
        capturedEventsCount
            .take(1)
            .timeout(.milliseconds(500), scheduler: MainScheduler.instance)
            .catch { _ in return Observable.just(0) }
            .subscribe(onNext: { count in
                XCTAssertEqual(count, 0, "No events should be emitted")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testRemoveCall_WithInvalidCallId_DoesNothing() async {
        await callManagementService.removeCall(callId: "invalid-id", callState: .over)
        XCTAssertEqual(calls.value.count, 0, "Call store should remain empty")
    }
    
    func testUpdateCallUUID_WithValidData_UpdatesUUID() async {
        let call = CallModel.createTestCall()
        let originalUUID = call.callUUID
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        let newUUIDString = UUID().uuidString
        
        await callManagementService.updateCallUUID(callId: CallTestConstants.callId, callUUID: newUUIDString)
        
        let updatedCall = calls.value[CallTestConstants.callId]
        XCTAssertNotNil(updatedCall, "Call should still exist in store")
        XCTAssertNotEqual(updatedCall?.callUUID, originalUUID, "UUID should have changed")
        XCTAssertEqual(updatedCall?.callUUID.uuidString, newUUIDString, "UUID should match new value")
    }
    
    func testUpdateCallUUID_WithInvalidCallId_DoesNothing() async {
        await callManagementService.updateCallUUID(callId: "invalid-id", callUUID: UUID().uuidString)
        XCTAssertEqual(calls.value.count, 0, "Call store should remain empty")
    }
    
    func testUpdateCallUUID_WithInvalidUUID_DoesNotUpdateUUID() async {
        let call = CallModel.createTestCall()
        let originalUUID = call.callUUID
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        await callManagementService.updateCallUUID(callId: CallTestConstants.callId, callUUID: "invalid-uuid")
        
        let updatedCall = calls.value[CallTestConstants.callId]
        XCTAssertNotNil(updatedCall, "Call should still exist in store")
        XCTAssertEqual(updatedCall?.callUUID, originalUUID, "UUID should not have changed")
    }
    
    func testAccept_WithValidCall_CallsAdapter() {
        let call = CallModel.createTestCall()
        call.mediaList = [TestMediaFactory.createAudioMedia()]
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
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
    
    func testAccept_WithAdapterFailure_ReturnsError() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        
        // Setup initial call
        let initialCall = CallModel.createTestCall()
        initialCall.callId = callId
        initialCall.accountId = accountId
        
        var callsDict = [String: CallModel]()
        callsDict[callId] = initialCall
        calls.accept(callsDict)
        
        // Configure the mock to return failure
        mockCallsAdapter.acceptCallReturnValue = false
        
        // Expectation for testing
        let expectation = XCTestExpectation(description: "Accept call fails")
        
        // Call the accept method and check result
        callManagementService.accept(callId: callId)
            .subscribe(
                onCompleted: {
                    XCTFail("Accept call should fail when adapter returns false")
                    expectation.fulfill()
                },
                onError: { error in
                    guard let callError = error as? CallServiceError else {
                        XCTFail("Error should be CallServiceError")
                        expectation.fulfill()
                        return
                    }
                    XCTAssertEqual(callError, .acceptCallFailed, "Error should be acceptCallFailed")
                    expectation.fulfill()
                }
            )
            .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify the adapter was called with correct parameters
        XCTAssertEqual(mockCallsAdapter.acceptCallIdCount, 1, "Accept should be called once")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdCallId, callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdAccountId, accountId, "Account ID should match")
    }
    
    func testAccept_WithInvalidCallId_ReturnsError() {
        let expectation = XCTestExpectation(description: "Accept call fails")
        
        callManagementService.accept(callId: "invalid-id")
            .subscribe(
                onCompleted: {
                    XCTFail("Accept call should fail")
                },
                onError: { error in
                    XCTAssertEqual(error as? CallServiceError, .callNotFound, "Error should be callNotFound")
                    expectation.fulfill()
                }
            )
            .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRefuse_WithValidCall_CallsAdapter() {
        let call = CallModel.createTestCall()
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
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
    
    func testRefuse_WithAdapterFailure_ReturnsError() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        
        // Setup initial call
        let initialCall = CallModel.createTestCall()
        initialCall.callId = callId
        initialCall.accountId = accountId
        
        var callsDict = [String: CallModel]()
        callsDict[callId] = initialCall
        calls.accept(callsDict)
        
        // Configure the mock to return failure
        mockCallsAdapter.refuseCallReturnValue = false
        
        // Expectation for testing
        let expectation = XCTestExpectation(description: "Refuse call fails")
        
        // Call the refuse method and check result
        callManagementService.refuse(callId: callId)
            .subscribe(
                onCompleted: {
                    XCTFail("Refuse call should fail when adapter returns false")
                    expectation.fulfill()
                },
                onError: { error in
                    guard let callError = error as? CallServiceError else {
                        XCTFail("Error should be CallServiceError")
                        expectation.fulfill()
                        return
                    }
                    XCTAssertEqual(callError, .refuseCallFailed, "Error should be refuseCallFailed")
                    expectation.fulfill()
                }
            )
            .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify the adapter was called with correct parameters
        XCTAssertEqual(mockCallsAdapter.refuseCallIdCount, 1, "Refuse should be called once")
        XCTAssertEqual(mockCallsAdapter.refuseCallIdCallId, callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.refuseCallIdAccountId, accountId, "Account ID should match")
    }
    
    func testHangUp_WithValidCall_CallsAdapter() {
        let call = CallModel.createTestCall()
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
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
    
    func testPlaceCall_Success_ReturnsCallModel() {
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
    
    func testPlaceCall_WithAdapterFailure_ReturnsError() {
        let account = AccountModel.createTestAccount()
        let participantId = CallTestConstants.participantUri
        
        mockCallsAdapter.placeCallReturnValue = "" // Empty call ID indicates failure
        
        let expectation = XCTestExpectation(description: "Place call fails")
        
        callManagementService.placeCall(
            withAccount: account,
            toParticipantId: participantId,
            userName: "Test User",
            videoSource: "camera",
            isAudioOnly: false,
            withMedia: []
        )
        .subscribe(
            onSuccess: { _ in
                XCTFail("Place call should fail")
            },
            onFailure: { error in
                XCTAssertEqual(error as? CallServiceError, .placeCallFailed, "Error should be placeCallFailed")
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIsCurrentCall_WithCurrentCall_ReturnsTrue() {
        let call = CallModel.createTestCall()
        call.state = .current
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        XCTAssertTrue(callManagementService.isCurrentCall(), "Should return true with current call")
    }
    
    func testIsCurrentCall_WithoutCurrentCall_ReturnsFalse() {
        let call = CallModel.createTestCall()
        call.state = .connecting
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        XCTAssertFalse(callManagementService.isCurrentCall(), "Should return false without current call")
    }
    
    func testCall_WithValidCallId_ReturnsCall() {
        let call = CallModel.createTestCall()
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        let result = callManagementService.call(callId: CallTestConstants.callId)
        
        XCTAssertNotNil(result, "Call should be returned")
        XCTAssertEqual(result?.callId, CallTestConstants.callId, "Call ID should match")
    }
    
    func testCall_WithInvalidCallId_ReturnsNil() {
        let result = callManagementService.call(callId: "invalid-id")
        
        XCTAssertNil(result, "Call should not be found")
    }
    
    func testCallByUUID_WithValidUUID_ReturnsCall() {
        let call = CallModel.createTestCall()
        let uuidString = call.callUUID.uuidString
        
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = call
        calls.accept(callsDict)
        
        let result = callManagementService.callByUUID(UUID: uuidString)
        
        XCTAssertNotNil(result, "Call should be returned")
        XCTAssertEqual(result?.callUUID.uuidString, uuidString, "UUID should match")
    }
    
    func testCallByUUID_WithInvalidUUID_ReturnsNil() {
        let result = callManagementService.callByUUID(UUID: UUID().uuidString)
        
        XCTAssertNil(result, "Call should not be found")
    }
    
    func testPlaceCall_WithAdapterSuccess_ReturnsCallId() {
        let accountId = CallTestConstants.accountId
        let participantId = "test-participant-id"
        let expectedCallId = "new-call-id"
        let accountName = "Test Account"
        
        // Create test account
        let account = AccountModel.createTestAccount(withId: accountId)
        
        // Configure the mock to return success
        mockCallsAdapter.placeCallReturnValue = expectedCallId
        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.displayNameKey.rawValue: "Test User",
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        // Expectation for testing
        let expectation = XCTestExpectation(description: "Place call succeeds")
        
        // Call the placeCall method and check result
        callManagementService.placeCall(
            withAccount: account,
            toParticipantId: participantId,
            userName: "Test User",
            videoSource: "camera",
            isAudioOnly: false,
            withMedia: []
        )
        .subscribe(
            onSuccess: { callModel in
                XCTAssertEqual(callModel.callId, expectedCallId, "Call ID should match adapter's return value")
                XCTAssertEqual(callModel.accountId, accountId, "Account ID should match")
                XCTAssertEqual(callModel.participantUri, participantId, "Participant ID should match")
                expectation.fulfill()
            },
            onFailure: { error in
                XCTFail("Place call should succeed when adapter returns a call ID: \(error)")
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify the adapter was called with correct parameters
        XCTAssertEqual(mockCallsAdapter.placeCallAccountIdCount, 1, "PlaceCall should be called once")
        XCTAssertEqual(mockCallsAdapter.placeCallAccountId, accountId, "Account ID should match")
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
