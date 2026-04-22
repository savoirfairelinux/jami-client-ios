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

    func testDidChangeCallState_WithNonFinishedState() {
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
        XCTAssertEqual(callsService.calls.get().count, 1, "Calls store should contain one call")
    }

    func testDidChangeCallState_WithFinishedState() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId

        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]

        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary

        let initialCallExpectation = XCTestExpectation(description: "Initial call added")

        callsService.callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                initialCallExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        callsService.didChangeCallState(withCallId: callId, state: CallState.ringing.rawValue, accountId: accountId, stateCode: 0)

        wait(for: [initialCallExpectation], timeout: 1.0)

        XCTAssertEqual(callsService.calls.get().count, 1, "Calls store should contain one call initially")

        let callRemovalExpectation = XCTestExpectation(description: "Call removed")

        DispatchQueue.main.async {
            self.callsService.didChangeCallState(withCallId: callId, state: CallState.over.rawValue, accountId: accountId, stateCode: 0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertEqual(self.callsService.calls.get().count, 0, "Call should be removed from store")
                callRemovalExpectation.fulfill()
            }
        }

        wait(for: [callRemovalExpectation], timeout: 2.0)
    }

    func testReceivingCall() {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId
        let uri = CallTestConstants.participantUri

        let callDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId,
            CallDetailKey.callTypeKey.rawValue: "0"]

        mockCallsAdapter.callDetailsReturnValue = callDictionary

        let eventExpectation = XCTestExpectation(description: "Event emitted")
        eventExpectation.assertForOverFulfill = false

        let callsStoreExpectation = XCTestExpectation(description: "Calls store updated")

        var capturedEvent: ServiceEvent?

        callsService.sharedResponseStream
            .subscribe(onNext: { event in
                if event.eventType == .incomingCall {
                    capturedEvent = event
                    eventExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        callsService.calls.observable
            .skip(1) // Skip the initial empty value
            .take(1)
            .subscribe(onNext: { calls in
                if calls.count == 1 && calls[callId] != nil {
                    callsStoreExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        callsService.receivingCall(withAccountId: accountId, callId: callId, fromURI: uri, withMedia: [TestMediaFactory.createAudioMedia()])

        wait(for: [eventExpectation, callsStoreExpectation], timeout: 3.0)

        XCTAssertEqual(callsService.calls.get().count, 1, "Calls store should contain one call")
        XCTAssertNotNil(callsService.calls.get()[callId], "Call should exist in store with correct ID")

        if let call = callsService.calls.get()[callId] {
            XCTAssertEqual(call.callType, .incoming, "Call type should be incoming")
        }

        XCTAssertNotNil(capturedEvent, "Event should be captured")
        XCTAssertEqual(capturedEvent?.eventType, .incomingCall, "Event type should be incomingCall")
    }

    func testMediaOperations() async {
        let callId = CallTestConstants.callId
        let accountId = CallTestConstants.accountId

        let initialCallDictionary = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: accountId
        ]

        mockCallsAdapter.callDetailsReturnValue = initialCallDictionary

        let initialCallExpectation = XCTestExpectation(description: "Initial call added")

        callsService.callUpdates
            .take(1)
            .subscribe(onNext: { _ in
                initialCallExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        callsService.didChangeCallState(withCallId: callId, state: CallState.current.rawValue, accountId: accountId, stateCode: 0)

        await fulfillment(of: [initialCallExpectation], timeout: 1.0)

        XCTAssertEqual(callsService.calls.get().count, 1, "Calls store should contain one call")

        let muteOperationExpectation = XCTestExpectation(description: "Audio mute operation completed")

        callsService.callUpdates
            .skip(1) // Skip the first update which was the initial call
            .take(1)
            .subscribe(onNext: { call in
                if call.callId == callId && call.audioMuted {
                    muteOperationExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        callsService.audioMuted(call: callId, mute: true)

        await fulfillment(of: [muteOperationExpectation], timeout: 2.0)

        let call = callsService.call(callID: callId)
        XCTAssertNotNil(call, "Call should exist")
        XCTAssertTrue(call?.audioMuted ?? false, "Audio should be muted")
    }

    func testAcceptCall() {
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

    func testPlaceCall() {
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

    // MARK: - placeSwarmCall

    // Participant path: when the iPhone joins an existing hosted swarm conference,
    // the daemon creates a regular outgoing SIPCall and never emits ConferenceCreated.
    // placeSwarmCall must still resolve, using the inner placeCall's model with the
    // conversationId attached. This is the bug case from the "[Conference] Joining
    // call causes black screen" issue.
    func testPlaceSwarmCall_ParticipantPath_ResolvesWithConversationId() {
        let account = AccountModel.createTestAccount()
        let conversationId = "conv-xyz"
        let uri = "swarm:" + conversationId
        let daemonCallId = "daemon-call-1"

        mockCallsAdapter.placeCallReturnValue = daemonCallId
        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.displayNameKey.rawValue: CallTestConstants.displayName,
            CallDetailKey.accountIdKey.rawValue: account.id
        ]

        let expectation = XCTestExpectation(description: "placeSwarmCall resolves via participant path")
        var resultCall: CallModel?

        callsService.placeSwarmCall(
            withAccount: account,
            uri: uri,
            userName: CallTestConstants.displayName,
            videoSource: "camera",
            isAudioOnly: false,
            timeout: .milliseconds(500)
        )
        .subscribe(
            onSuccess: { call in
                resultCall = call
                expectation.fulfill()
            },
            onFailure: { error in
                XCTFail("placeSwarmCall should not fail: \(error)")
            }
        )
        .disposed(by: disposeBag)

        // Intentionally do NOT call callsService.conferenceCreated(...) — this simulates
        // the daemon routing the call to an existing host as a plain SIPCall.
        wait(for: [expectation], timeout: 2.0)

        XCTAssertNotNil(resultCall)
        XCTAssertEqual(resultCall?.callId, daemonCallId, "Call id should be the daemon's SIPCall id")
        XCTAssertEqual(resultCall?.conversationId, conversationId, "conversationId should be attached")
        XCTAssertEqual(callsService.calls.get()[daemonCallId]?.conversationId, conversationId,
                       "Stored CallModel should also carry the conversationId")
    }

    // Host path: when the daemon becomes the swarm host, it emits ConferenceCreated
    // synchronously and placeCall returns an empty callId (→ .placeCallFailed).
    // placeSwarmCall must resolve via the ConferenceCreated signal.
    func testPlaceSwarmCall_HostPath_ResolvesWithConferenceId() {
        let account = AccountModel.createTestAccount()
        let conversationId = "conv-host"
        let uri = "swarm:" + conversationId
        let confId = "conf-1"

        // Simulate "daemon became host" by having placeCall return empty (so the
        // inner Single fails with .placeCallFailed), then synchronously driving
        // the ConferenceCreated delegate callback.
        mockCallsAdapter.placeCallReturnValue = ""
        mockCallsAdapter.callDetailsReturnValue = [:]

        let expectation = XCTestExpectation(description: "placeSwarmCall resolves via host path")
        var resultCall: CallModel?

        // Drive ConferenceCreated as soon as waitingSwarmCalls contains our conversationId.
        // Observing callUpdates isn't sufficient for timing here — we just fire it
        // asynchronously on main, which matches the daemon's behaviour closely enough.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.callsService.conferenceCreated(conferenceId: confId, conversationId: conversationId, accountId: account.id)
        }

        callsService.placeSwarmCall(
            withAccount: account,
            uri: uri,
            userName: CallTestConstants.displayName,
            videoSource: "camera",
            isAudioOnly: false,
            timeout: .seconds(2)
        )
        .subscribe(
            onSuccess: { call in
                resultCall = call
                expectation.fulfill()
            },
            onFailure: { error in
                XCTFail("placeSwarmCall should not fail: \(error)")
            }
        )
        .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 3.0)

        XCTAssertNotNil(resultCall)
        XCTAssertEqual(resultCall?.callId, confId, "Call id should be the conferenceId from the host path")
        XCTAssertEqual(resultCall?.conversationId, conversationId)
    }

    // Neither signal fires → the Rx timeout path must emit placeCallFailed.
    func testPlaceSwarmCall_NeitherPath_TimesOut() {
        let account = AccountModel.createTestAccount()
        let uri = "swarm:conv-nothing"

        // Empty placeCall return → inner Single fails with .placeCallFailed (swallowed).
        // No conferenceCreated callback → hostDisposable never fires.
        mockCallsAdapter.placeCallReturnValue = ""
        mockCallsAdapter.callDetailsReturnValue = [:]

        let expectation = XCTestExpectation(description: "placeSwarmCall times out")
        var resultError: Error?

        callsService.placeSwarmCall(
            withAccount: account,
            uri: uri,
            userName: CallTestConstants.displayName,
            videoSource: "camera",
            isAudioOnly: false,
            timeout: .milliseconds(300)
        )
        .subscribe(
            onSuccess: { _ in
                XCTFail("placeSwarmCall should not succeed")
            },
            onFailure: { error in
                resultError = error
                expectation.fulfill()
            }
        )
        .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 2.0)

        XCTAssertNotNil(resultError)
        XCTAssertEqual(resultError as? CallServiceError, CallServiceError.placeCallFailed)
    }
}
