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

class CallsServiceTests: XCTestCase {
    
    private var callsService: CallsService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var mockDBManager: DBManager!
    private var disposeBag: DisposeBag!
    
    override func setUp() {
        super.setUp()
        mockCallsAdapter = ObjCMockCallsAdapter()
        mockDBManager = DBManager(profileHepler: ProfileDataHelper(),
                                              conversationHelper: ConversationDataHelper(),
                                              interactionHepler: InteractionDataHelper(),
                                              dbConnections: DBContainer())
        disposeBag = DisposeBag()
        
        callsService = CallsService(withCallsAdapter: mockCallsAdapter, dbManager: mockDBManager)
    }
    
    override func tearDown() {
        disposeBag = nil
        callsService = nil
        mockCallsAdapter = nil
        mockDBManager = nil
        super.tearDown()
    }
    
    func testDidChangeCallState_WithNonFinishedState_AddsToCallsStore() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        let state = CallState.ringing.rawValue
        
        let callDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        mockCallsAdapter.callDetailsReturnValue = callDictionary
        
        var capturedCall: CallModel?
        callsService.callUpdates
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        callsService.didChangeCallState(withCallId: callId, state: state, accountId: accountId, stateCode: 0)
        
        XCTAssertNotNil(capturedCall, "Call should be captured")
        XCTAssertEqual(capturedCall?.callId, callId, "Call ID should match")
        XCTAssertEqual(capturedCall?.state, CallState.ringing, "Call state should match")
        XCTAssertEqual(capturedCall?.displayName, CallTestConstants.displayName, "Display name should match")
        XCTAssertEqual(callsService.calls.value.count, 1, "Calls store should contain one call")
    }
    
    func testDidChangeCallState_WithFinishedState_RemovesFromCallsStore() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        
        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary
        
        // Create an expectation for the initial call update
        let initialCallExpectation = XCTestExpectation(description: "Initial call added")
        
        // Subscribe to call updates to know when the initial call is added
        callsService.callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                initialCallExpectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        // Trigger the initial call state change
        callsService.didChangeCallState(withCallId: callId, state: CallState.ringing.rawValue, accountId: accountId, stateCode: 0)
        
        // Wait for the initial call to be added
        wait(for: [initialCallExpectation], timeout: 1.0)
        
        // Verify the call was added to the store
        XCTAssertEqual(callsService.calls.value.count, 1, "Calls store should contain one call initially")
        
        // Create an expectation for the call removal
        let callRemovalExpectation = XCTestExpectation(description: "Call removed")
        
        // Trigger the finished state and wait for the call to be removed
        DispatchQueue.main.async {
            self.callsService.didChangeCallState(withCallId: callId, state: CallState.over.rawValue, accountId: accountId, stateCode: 0)
            
            // Since removal happens asynchronously in a Task, we need to wait a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertEqual(self.callsService.calls.value.count, 0, "Call should be removed from store")
                callRemovalExpectation.fulfill()
            }
        }
        
        wait(for: [callRemovalExpectation], timeout: 2.0)
    }
    
    func testReceivingCall_AddsIncomingCallToStore() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        let uri = CallTestConstants.participantUri
        
        let callDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId,
            CallDetailKey.callTypeKey.rawValue: "0"]

        mockCallsAdapter.callDetailsReturnValue = callDictionary
        
        // Set up expectations
        let eventExpectation = XCTestExpectation(description: "Event emitted")
        eventExpectation.assertForOverFulfill = false
        
        let callsStoreExpectation = XCTestExpectation(description: "Calls store updated")
        
        // Keep track of captured event
        var capturedEvent: ServiceEvent?
        
        // Subscribe to the response stream
        callsService.sharedResponseStream
            .subscribe(onNext: { event in
                if event.eventType == .incomingCall {
                    capturedEvent = event
                    eventExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)
        
        // Monitor the calls store for changes
        callsService.calls
            .skip(1) // Skip the initial empty value
            .take(1)
            .subscribe(onNext: { calls in
                if calls.count == 1 && calls[callId] != nil {
                    callsStoreExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)
        
        // Perform the action that should trigger events
        callsService.receivingCall(withAccountId: accountId, callId: callId, fromURI: uri, withMedia: [TestMediaFactory.createAudioMedia()])
        
        // Wait for both expectations with a longer timeout
        wait(for: [eventExpectation, callsStoreExpectation], timeout: 3.0)
        
        // Now perform assertions after we know both events have occurred
        XCTAssertEqual(callsService.calls.value.count, 1, "Calls store should contain one call")
        XCTAssertNotNil(callsService.calls.value[callId], "Call should exist in store with correct ID")
        
        if let call = callsService.calls.value[callId] {
            XCTAssertEqual(call.callType, .incoming, "Call type should be incoming")
        }
        
        XCTAssertNotNil(capturedEvent, "Event should be captured")
        XCTAssertEqual(capturedEvent?.eventType, .incomingCall, "Event type should be incomingCall")
    }
    
    func testHandleMediaOperations_CallsMediaManagementService() async {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        
        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary
        
        // Set up expectation for initial call adding
        let initialCallExpectation = XCTestExpectation(description: "Initial call added")
        
        // Subscribe to callUpdates to know when initial call is added
        callsService.callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                initialCallExpectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        // Trigger call state change
        callsService.didChangeCallState(withCallId: callId, state: CallState.current.rawValue, accountId: accountId, stateCode: 0)
        
        // Wait for call to be added
        await fulfillment(of: [initialCallExpectation], timeout: 1.0)
        
        // Verify call was added
        XCTAssertEqual(callsService.calls.value.count, 1, "Calls store should contain one call")
        
        // Set up expectation for call update after muting
        let muteOperationExpectation = XCTestExpectation(description: "Audio mute operation completed")
        
        // Set up observer for call updates to detect when audio is muted
        callsService.callUpdates
            .skip(1) // Skip the first update which was the initial call
            .take(1)
            .subscribe(onNext: { call in
                if call.callId == callId && call.audioMuted {
                    muteOperationExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)
        
        // Perform the mute operation
        await callsService.audioMuted(call: callId, mute: true)
        
        // Wait for mute operation to be reflected in the call model
        await fulfillment(of: [muteOperationExpectation], timeout: 2.0)
        
        // Verify the call was muted
        let call = callsService.call(callID: callId)
        XCTAssertNotNil(call, "Call should exist")
        XCTAssertTrue(call?.audioMuted ?? false, "Audio should be muted")
    }
    
    func testAccept_CallsCallManagementService() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        
        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary
        mockCallsAdapter.acceptCallReturnValue = true
        
        callsService.didChangeCallState(withCallId: callId, state: CallState.incoming.rawValue, accountId: accountId, stateCode: 0)
        
        let expectation = XCTestExpectation(description: "Accept call completes")
        
        callsService.accept(callId: callId)
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
        XCTAssertEqual(mockCallsAdapter.acceptCallIdCallId, callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.acceptCallIdAccountId, accountId, "Account ID should match")
    }
    
    func testPlaceCall_ReturnsCallModel() {
        let account = AccountModel.createTestAccount()
        let participantId = CallTestConstants.participantUri
        let userName = CallTestConstants.displayName
        
        mockCallsAdapter.placeCallReturnValue = CallTestConstants.callId
        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.displayNameKey.rawValue: userName,
            CallDetailKey.accountIdKey.rawValue: account.id
        ]
        
        let expectation = XCTestExpectation(description: "Place call completes")
        
        var resultCall: CallModel?
        
        callsService.placeCall(
            withAccount: account,
            toParticipantId: participantId,
            userName: userName,
            videoSource: "camera",
            isAudioOnly: false
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
        XCTAssertEqual(resultCall?.callType, .outgoing, "Call type should be outgoing")
    }
    
    func testConferenceOperations_DelegateToConferenceService() {
        let conferenceId = "test-conference-id"
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        let conversationId = "conversationId"

        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]
        
        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary
        
        callsService.didChangeCallState(withCallId: callId, state: CallState.current.rawValue, accountId: accountId, stateCode: 0)
        
        let expectation = XCTestExpectation(description: "Conference operations complete")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.callsService.conferenceCreated(conferenceId: conferenceId, conversationId: conversationId, accountId: accountId)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
