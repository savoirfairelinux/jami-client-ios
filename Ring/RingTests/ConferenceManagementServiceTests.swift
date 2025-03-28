//
//  ConferenceManagementServiceTests.swift
//  Ring
//
//  Created by kateryna on 2025-03-30.
//  Copyright © 2025 Savoir-faire Linux. All rights reserved.
//

import XCTest
import RxSwift
import RxRelay
@testable import Ring

class ConferenceManagementServiceTests: XCTestCase {

    // MARK: - Test Constants
    private enum TestConstants {
        static let conferenceId = "test-conference-id"
        static let secondCallId = "test-call-id-2"
        static let thirdCallId = "test-call-id-3"
        static let participantURI = "test-participant-uri"
        static let deviceId = "test-device-id"
        static let streamId = "test-stream-id"
    }

    // MARK: - Properties
    private var conferenceManagementService: ConferenceManagementService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!
    private var testConference: CallModel!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        setupMocks()
        setupTestCalls()
        setupService()
    }

    override func tearDown() {
        mockCallsAdapter = nil
        calls = nil
        disposeBag = nil
        testCall = nil
        testConference = nil
        conferenceManagementService = nil
        super.tearDown()
    }

    // MARK: - Test Setup Helpers
    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        disposeBag = DisposeBag()
    }

    private func setupTestCalls() {
        // Create a regular call
        testCall = CallModel.createTestCall()

        // Create a conference call with multiple participants
        testConference = CallModel.createTestCall(withCallId: TestConstants.conferenceId)
        testConference.participantsCallId = Set([CallTestConstants.callId, TestConstants.secondCallId])

        // Add both to the calls array
        var callsDict = [String: CallModel]()
        callsDict[CallTestConstants.callId] = testCall
        callsDict[TestConstants.conferenceId] = testConference
        callsDict[TestConstants.secondCallId] = CallModel.createTestCall(withCallId: TestConstants.secondCallId)

        calls.accept(callsDict)
    }

    private func setupService() {
        conferenceManagementService = ConferenceManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls
        )
    }

    // MARK: - Mock Configuration Helpers
    private func setupMockConferenceCalls(_ callIds: [String]) {
        mockCallsAdapter.getConferenceCallsReturnValue = callIds
    }

    private func setupMockGetConferenceInfo(participants: [[String: String]]) {
        mockCallsAdapter.getConferenceInfoReturnValue = participants
    }

    private func setupMockGetConferenceDetails(details: [String: String]) {
        mockCallsAdapter.getConferenceDetailsReturnValue = details
    }
    
    private func setupCallWithSingleParticipant(_ callId: String) -> CallModel {
        var callsDict = calls.value
        let singleCall = CallModel.createTestCall(withCallId: callId)
        singleCall.participantsCallId = Set([callId]) // One participant (itself)
        callsDict[callId] = singleCall
        calls.accept(callsDict)
        return singleCall
    }
    
    private func setupCallWithMultipleParticipants(_ callId: String, participants: [String]) -> CallModel {
        var callsDict = calls.value
        let conferenceCall = CallModel.createTestCall(withCallId: callId)
        conferenceCall.participantsCallId = Set(participants)
        callsDict[callId] = conferenceCall
        calls.accept(callsDict)
        return conferenceCall
    }
    
    private func setupCallWithLayout(_ callId: String, layout: CallLayout) -> CallModel {
        var callsDict = calls.value
        let call = callsDict[callId] ?? CallModel.createTestCall(withCallId: callId)
        call.layout = layout
        callsDict[callId] = call
        calls.accept(callsDict)
        return call
    }
    
    private func verifyPendingConference(forCall callId: String, expectedConference: String) {
        if let pendingConf = conferenceManagementService.shouldCallBeAddedToConference(callId: callId) {
            XCTAssertEqual(pendingConf, expectedConference, "Call should be added to the correct pending conference")
        } else {
            XCTFail("Call should have been added to a pending conference")
        }
    }

    // MARK: - Event Assertion Helpers
    private func expectConferenceEvent(conferenceId: String, state: ConferenceState) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "Conference \(state.rawValue) event published")
        
        conferenceManagementService.currentConferenceEvent
            .skip(1) // Skip the initial empty value
            .take(1)
            .subscribe(onNext: { event in
                XCTAssertEqual(event.conferenceID, conferenceId, "Conference ID should match")
                XCTAssertEqual(event.state, state.rawValue, "State should be \(state.rawValue)")
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        return expectation
    }
    
    private func verifyAdapter<T: Equatable>(
        property: T?,
        expectedValue: T,
        message: String
    ) {
        XCTAssertEqual(property, expectedValue, message)
    }

    // MARK: - Join Conference Tests
    func testJoinConference_WithSingleCall() {
        setupCallWithSingleParticipant(CallTestConstants.callId)

        conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: CallTestConstants.callId)

        verifyAdapter(
            property: mockCallsAdapter.joinConferenceCallCount,
            expectedValue: 1,
            message: "joinConference should be called for a single call"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferencesCallCount,
            expectedValue: 0,
            message: "joinConferences should not be called for a single call"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferenceConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferenceCallId,
            expectedValue: CallTestConstants.callId,
            message: "Call ID should match"
        )

        verifyPendingConference(forCall: CallTestConstants.callId, expectedConference: TestConstants.conferenceId)
    }
    
    func testJoinConference_WithConferenceCall() {
        setupCallWithMultipleParticipants(
            TestConstants.secondCallId,
            participants: [TestConstants.secondCallId, TestConstants.thirdCallId]
        )
        
        conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: TestConstants.secondCallId)
        
        verifyAdapter(
            property: mockCallsAdapter.joinConferenceCallCount,
            expectedValue: 0,
            message: "joinConference should not be called for a conference call"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferencesCallCount,
            expectedValue: 1,
            message: "joinConferences should be called for a conference call"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferencesConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "First conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinConferencesSecondConferenceId,
            expectedValue: TestConstants.secondCallId,
            message: "Second conference ID should match"
        )
        
        verifyPendingConference(forCall: TestConstants.secondCallId, expectedConference: TestConstants.conferenceId)
    }

    func testJoinCall() {
        conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)

        verifyAdapter(
            property: mockCallsAdapter.joinCallCallCount,
            expectedValue: 1,
            message: "Join call should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinCallFirstCallId,
            expectedValue: CallTestConstants.callId,
            message: "First call ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.joinCallSecondCallId,
            expectedValue: TestConstants.secondCallId,
            message: "Second call ID should match"
        )

        verifyPendingConference(forCall: TestConstants.secondCallId, expectedConference: CallTestConstants.callId)
    }

    func testAddCall() {
        let newCall = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)

        let inConferenceExpectation = XCTestExpectation(description: "Call added to conference")

        conferenceManagementService.inConferenceCalls
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, TestConstants.thirdCallId, "Added call should match the expected call")
                inConferenceExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        conferenceManagementService.addCall(call: newCall, to: TestConstants.conferenceId)

        wait(for: [inConferenceExpectation], timeout: 1.0)

        verifyPendingConference(forCall: TestConstants.thirdCallId, expectedConference: TestConstants.conferenceId)
    }

    // MARK: - Hang Up Tests
    func testHangUpCall() {
        let expectation = XCTestExpectation(description: "Hang up call completed")
        mockCallsAdapter.hangUpCallReturnValue = true
        setupCallWithSingleParticipant(CallTestConstants.callId)

        let hangupCompletable = conferenceManagementService.hangUpCallOrConference(callId: CallTestConstants.callId)

        hangupCompletable
            .subscribe(onCompleted: {
                expectation.fulfill()
            }, onError: { error in
                XCTFail("Hang up call should complete without error: \(error)")
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)
        verifyAdapter(
            property: mockCallsAdapter.hangUpCallCallCount,
            expectedValue: 1,
            message: "Hang up call should be called once"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangUpConferenceCallCount,
            expectedValue: 0,
            message: "Hang up conference should not be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangUpCallCallId,
            expectedValue: CallTestConstants.callId,
            message: "Call ID should match"
        )
    }

    func testHangUpConference() {
        let expectation = XCTestExpectation(description: "Hang up conference completed")
        mockCallsAdapter.hangUpConferenceReturnValue = true
        setupCallWithMultipleParticipants(
            TestConstants.conferenceId,
            participants: [CallTestConstants.callId, TestConstants.secondCallId]
        )

        let hangupCompletable = conferenceManagementService.hangUpCallOrConference(callId: TestConstants.conferenceId)

        hangupCompletable
            .subscribe(onCompleted: {
                expectation.fulfill()
            }, onError: { error in
                XCTFail("Hang up conference should complete without error: \(error)")
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)
        verifyAdapter(
            property: mockCallsAdapter.hangUpCallCallCount,
            expectedValue: 0,
            message: "Hang up call should not be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangUpConferenceCallCount,
            expectedValue: 1,
            message: "Hang up conference should be called once"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangUpConferenceCallId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
    }

    func testHangUpCallFailure() {
        let expectation = XCTestExpectation(description: "Hang up call failed")
        mockCallsAdapter.hangUpCallReturnValue = false

        let hangupCompletable = conferenceManagementService.hangUpCallOrConference(callId: CallTestConstants.callId)

        hangupCompletable
            .subscribe(onCompleted: {
                XCTFail("Hang up call should not complete")
            }, onError: { error in
                if let callError = error as? CallServiceError, callError == CallServiceError.hangUpCallFailed {
                    expectation.fulfill()
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 1.0)
        verifyAdapter(
            property: mockCallsAdapter.hangUpCallCallCount,
            expectedValue: 1,
            message: "Hang up call should be called once"
        )
    }

    // MARK: - Participant Tests
    func testIsParticipant() {
        let participantInfo = [
            ["uri": "test-participant-uri", "active": "true"],
            ["uri": "other-participant", "active": "false"]
        ]

        setupMockGetConferenceInfo(participants: participantInfo)

        let result = conferenceManagementService.isParticipant(
            participantURI: TestConstants.participantURI,
            activeIn: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId
        )

        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertEqual(result, true, "Participant should be active")
        verifyAdapter(
            property: mockCallsAdapter.getConferenceInfoCallCount,
            expectedValue: 1,
            message: "Get conference info should be called once"
        )
        verifyAdapter(
            property: mockCallsAdapter.getConferenceInfoConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
    }

    func testIsModerator() {
        // Setup - create moderator and non-moderator participants
        let moderatorId = "moderator-id"
        let participantId = "participant-id"

        let conferenceInfo = [
            ["uri": moderatorId, "isModerator": "true", "active": "true"],
            ["uri": participantId, "isModerator": "false", "active": "true"]
        ]
        
        conferenceManagementService.handleConferenceInfoUpdated(conference: TestConstants.conferenceId, info: conferenceInfo)

        XCTAssertTrue(
            conferenceManagementService.isModerator(participantId: moderatorId, inConference: TestConstants.conferenceId),
            "User with isModerator=true should be identified as a moderator"
        )
        
        XCTAssertFalse(
            conferenceManagementService.isModerator(participantId: participantId, inConference: TestConstants.conferenceId),
            "User with isModerator=false should not be identified as a moderator"
        )
        
        XCTAssertFalse(
            conferenceManagementService.isModerator(participantId: "non-existent-id", inConference: TestConstants.conferenceId),
            "Non-existent user should not be identified as a moderator"
        )
    }

    // MARK: - Layout Tests
    func testSetActiveParticipant_Maximize() {
        setupMockGetConferenceInfo(participants: [
            ["uri": TestConstants.participantURI, "active": "true"]
        ])
        setupCallWithLayout(TestConstants.conferenceId, layout: .grid)

        conferenceManagementService.setActiveParticipant(
            conferenceId: TestConstants.conferenceId,
            maximixe: true,
            jamiId: TestConstants.participantURI
        )

        verifyAdapter(
            property: mockCallsAdapter.setActiveParticipantCallCount,
            expectedValue: 1,
            message: "Set active participant should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.setActiveParticipantJamiId,
            expectedValue: TestConstants.participantURI,
            message: "Jami ID should match"
        )
        
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutCallCount,
            expectedValue: 1,
            message: "Set conference layout should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutLayout,
            expectedValue: CallLayout.oneWithSmal.rawValue,
            message: "Layout should be 'oneWithSmall' when maximizing from grid"
        )
    }
    
    func testSetActiveParticipant_OneWithSmall_ToGrid() {
        setupMockGetConferenceInfo(participants: [
            ["uri": TestConstants.participantURI, "active": "true"]
        ])
        setupCallWithLayout(TestConstants.conferenceId, layout: .oneWithSmal)

        conferenceManagementService.setActiveParticipant(
            conferenceId: TestConstants.conferenceId,
            maximixe: false,
            jamiId: TestConstants.participantURI
        )

        verifyAdapter(
            property: mockCallsAdapter.setActiveParticipantCallCount,
            expectedValue: 1,
            message: "Set active participant should be called"
        )
        
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutCallCount,
            expectedValue: 1,
            message: "Set conference layout should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutLayout,
            expectedValue: CallLayout.grid.rawValue,
            message: "Layout should be 'grid' when not maximizing from oneWithSmal"
        )
    }
    
    func testSetActiveParticipant_OneWithSmall_ToOne() {
        setupMockGetConferenceInfo(participants: [
            ["uri": TestConstants.participantURI, "active": "true"]
        ])
        setupCallWithLayout(TestConstants.conferenceId, layout: .oneWithSmal)

        conferenceManagementService.setActiveParticipant(
            conferenceId: TestConstants.conferenceId,
            maximixe: true,
            jamiId: TestConstants.participantURI
        )

        verifyAdapter(
            property: mockCallsAdapter.setActiveParticipantCallCount,
            expectedValue: 1,
            message: "Set active participant should be called"
        )
        
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutCallCount,
            expectedValue: 1,
            message: "Set conference layout should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceLayoutLayout,
            expectedValue: CallLayout.one.rawValue,
            message: "Layout should be 'one' when maximizing from oneWithSmal"
        )
    }

    // MARK: - Conference Event Tests
    func testHandleConferenceCreated() {
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId])
        conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)
        setupMockGetConferenceDetails(details: ["accountId": CallTestConstants.accountId, "audioOnly": "false"])

        let eventExpectation = expectConferenceEvent(
            conferenceId: TestConstants.conferenceId,
            state: .conferenceCreated
        )

        conferenceManagementService.handleConferenceCreated(conference: TestConstants.conferenceId, accountId: CallTestConstants.accountId)

        wait(for: [eventExpectation], timeout: 1.0)
        XCTAssertNotNil(calls.value[TestConstants.conferenceId], "Conference should be added to calls")
        verifyAdapter(
            property: mockCallsAdapter.getConferenceCallsCallCount,
            expectedValue: 1,
            message: "Get conference calls should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.getConferenceDetailsCallCount,
            expectedValue: 1,
            message: "Get conference details should be called"
        )
    }

    func testHandleConferenceChanged() {
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId])

        let callsUpdatedExpectation = XCTestExpectation(description: "Calls updated")

        var callsObserved = false
        calls
            .skip(1) // Skip initial value
            .take(1)
            .subscribe(onNext: { callsDict in
                callsObserved = true
                XCTAssertEqual(
                    callsDict[TestConstants.conferenceId]?.participantsCallId.count,
                    3,
                    "Conference should have 3 participants"
                )
                callsUpdatedExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        conferenceManagementService.handleConferenceChanged(
            conference: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId,
            state: "changed"
        )

        wait(for: [callsUpdatedExpectation], timeout: 1.0)
        XCTAssertTrue(callsObserved, "Calls should have been updated")
        verifyAdapter(
            property: mockCallsAdapter.getConferenceCallsCallCount,
            expectedValue: 1,
            message: "Get conference calls should be called"
        )
    }

    func testHandleConferenceRemoved() {
        let eventExpectation = XCTestExpectation(description: "Conference removed event published")
        let thirdCall = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)
        conferenceManagementService.addCall(call: thirdCall, to: TestConstants.conferenceId)

        var eventCount = 0
        conferenceManagementService.currentConferenceEvent
            .skip(1) // Skip the initial empty value
            .take(2) // We expect two events (infoUpdated and conferenceDestroyed)
            .subscribe(onNext: { event in
                eventCount += 1
                if eventCount == 2 {
                    XCTAssertEqual(event.state, ConferenceState.conferenceDestroyed.rawValue, "Second event should be conferenceDestroyed")
                    eventExpectation.fulfill()
                }
            })
            .disposed(by: disposeBag)

        conferenceManagementService.handleConferenceRemoved(conference: TestConstants.conferenceId)

        wait(for: [eventExpectation], timeout: 1.0)
        XCTAssertNil(calls.value[TestConstants.conferenceId], "Conference should be removed from calls")
        XCTAssertNil(
            conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.thirdCallId),
            "Conference should be removed from pending conferences"
        )
    }

    func testHandleConferenceInfoUpdated() {
        let participants = [
            ["uri": "participant1", "isModerator": "true", "active": "true"],
            ["uri": "participant2", "isModerator": "false", "active": "true"]
        ]

        let eventExpectation = expectConferenceEvent(
            conferenceId: TestConstants.conferenceId,
            state: .infoUpdated
        )

        conferenceManagementService.handleConferenceInfoUpdated(
            conference: TestConstants.conferenceId,
            info: participants
        )

        wait(for: [eventExpectation], timeout: 1.0)

        let storedParticipants = conferenceManagementService.getConferenceParticipants(for: TestConstants.conferenceId)
        XCTAssertNotNil(storedParticipants, "Participants should be stored")
        XCTAssertEqual(storedParticipants?.count, 2, "Should have 2 participants")
        
        if let participants = storedParticipants {
            let moderators = participants.filter { $0.isModerator }
            XCTAssertEqual(moderators.count, 1, "One participant should be a moderator")
            XCTAssertEqual(moderators.first?.uri, "participant1", "participant1 should be the moderator")
        }
    }

    // MARK: - Pending Conferences Tests
    func testClearPendingConferences() {
        let call1 = CallModel.createTestCall(withCallId: CallTestConstants.callId)
        conferenceManagementService.addCall(call: call1, to: TestConstants.conferenceId)
        conferenceManagementService.addCall(call: call1, to: TestConstants.secondCallId)

        conferenceManagementService.clearPendingConferences(callId: CallTestConstants.callId)

        XCTAssertNil(
            conferenceManagementService.shouldCallBeAddedToConference(callId: CallTestConstants.callId),
            "Call should be removed from pending conferences"
        )
    }

    func testUpdateConferences() {
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId])
        
        var updatedCalls = calls.value
        updatedCalls[TestConstants.thirdCallId] = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)
        calls.accept(updatedCalls)

        let callsUpdatedExpectation = XCTestExpectation(description: "Calls updated")

        calls
            .skip(1) // Skip initial value
            .take(1)
            .subscribe(onNext: { _ in
                callsUpdatedExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        conferenceManagementService.updateConferences(callId: CallTestConstants.callId)

        wait(for: [callsUpdatedExpectation], timeout: 1.0)
        verifyAdapter(
            property: mockCallsAdapter.getConferenceCallsCallCount,
            expectedValue: 1,
            message: "Get conference calls should be called"
        )

        for callId in [CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId] {
            XCTAssertEqual(
                calls.value[callId]?.participantsCallId.count,
                3,
                "Call \(callId) should have 3 participants"
            )
        }
    }
}

