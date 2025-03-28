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

        // Add both to the calls BehaviorRelay
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

    // MARK: - Helper Methods
    private func setupMockConferenceCalls(_ callIds: [String]) {
        mockCallsAdapter.getConferenceCallsReturnValue = callIds
    }

    private func setupMockGetConferenceInfo(participants: [[String: String]]) {
        mockCallsAdapter.getConferenceInfoReturnValue = participants
    }

    private func setupMockGetConferenceDetails(details: [String: String]) {
        mockCallsAdapter.getConferenceDetailsReturnValue = details
    }

    // MARK: - Join Conference Tests
    func testJoinConference() {
        // Execute
        conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: CallTestConstants.callId)

        // Verify
        XCTAssertEqual(mockCallsAdapter.joinConferenceCallCount, 1, "Join conference should be called")
        XCTAssertEqual(mockCallsAdapter.joinConferenceConferenceId, TestConstants.conferenceId, "Conference ID should match")
        XCTAssertEqual(mockCallsAdapter.joinConferenceCallId, CallTestConstants.callId, "Call ID should match")

        // Verify that the call was added to pending conferences
        if let pendingConf = conferenceManagementService.shouldCallBeAddedToConference(callId: CallTestConstants.callId) {
            XCTAssertEqual(pendingConf, TestConstants.conferenceId, "Call should be added to the correct pending conference")
        } else {
            XCTFail("Call should have been added to a pending conference")
        }
    }

    func testJoinConferences() {
        // Setup
        let expectation = XCTestExpectation(description: "Join conferences called")

        // Create a second "conference" call to join
        let secondConference = CallModel.createTestCall(withCallId: TestConstants.secondCallId)
        secondConference.participantsCallId = Set([TestConstants.thirdCallId])

        var callsDict = calls.value
        callsDict[TestConstants.secondCallId] = secondConference
        calls.accept(callsDict)

        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.joinConferences(_:secondConference:accountId:account2Id:)) {
                expectation.fulfill()
            }
            return nil
        }

        // Execute
        conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: TestConstants.secondCallId)

        // Verify
        wait(for: [expectation], timeout: 1.0)

        // Verify that the call was added to pending conferences
        if let pendingConf = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.secondCallId) {
            XCTAssertEqual(pendingConf, TestConstants.conferenceId, "Call should be added to the correct pending conference")
        } else {
            XCTFail("Call should have been added to a pending conference")
        }
    }

    func testJoinCall() {
        // Setup
        let expectation = XCTestExpectation(description: "Join call called")
        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.joinCall(_:second:accountId:account2Id:)) {
                expectation.fulfill()
            }
            return nil
        }

        // Execute
        conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)

        // Verify
        wait(for: [expectation], timeout: 1.0)

        // Verify that the call was added to pending conferences
        if let pendingConf = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.secondCallId) {
            XCTAssertEqual(pendingConf, CallTestConstants.callId, "Call should be added to the correct pending conference")
        } else {
            XCTFail("Call should have been added to a pending conference")
        }
    }

    func testAddCall() {
        // Setup
        let newCall = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)

        // Setup expectation for inConferenceCalls
        let inConferenceExpectation = XCTestExpectation(description: "Call added to conference")

        conferenceManagementService.inConferenceCalls
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, TestConstants.thirdCallId, "Added call should match the expected call")
                inConferenceExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        // Execute
        conferenceManagementService.addCall(call: newCall, to: TestConstants.conferenceId)

        // Verify
        wait(for: [inConferenceExpectation], timeout: 1.0)

        // Verify that the call was added to pending conferences
        if let pendingConf = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.thirdCallId) {
            XCTAssertEqual(pendingConf, TestConstants.conferenceId, "Call should be added to the correct pending conference")
        } else {
            XCTFail("Call should have been added to a pending conference")
        }
    }

    // MARK: - Hang Up Tests
    func testHangUpCall() {
        // Setup
        let expectation = XCTestExpectation(description: "Hang up call completed")

        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.hangUpCall(_:accountId:)) {
                return true
            }
            return nil
        }

        // Execute
        let hangupCompletable = conferenceManagementService.hangUpCallOrConference(callId: CallTestConstants.callId)

        hangupCompletable
            .subscribe(onCompleted: {
                expectation.fulfill()
            }, onError: { error in
                XCTFail("Hang up call should complete without error: \(error)")
            })
            .disposed(by: disposeBag)

        // Verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testHangUpConference() {
        // Setup
        let expectation = XCTestExpectation(description: "Hang up conference completed")

        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.hangUpConference(_:accountId:)) {
                return true
            }
            return nil
        }

        // Execute
        let hangupCompletable = conferenceManagementService.hangUpCallOrConference(callId: TestConstants.conferenceId)

        hangupCompletable
            .subscribe(onCompleted: {
                expectation.fulfill()
            }, onError: { error in
                XCTFail("Hang up conference should complete without error: \(error)")
            })
            .disposed(by: disposeBag)

        // Verify
        wait(for: [expectation], timeout: 1.0)
    }

    func testHangUpCallFailure() {
        // Setup
        let expectation = XCTestExpectation(description: "Hang up call failed")

        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.hangUpCall(_:accountId:)) {
                return false
            }
            return nil
        }

        // Execute
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

        // Verify
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Participant Tests
    func testIsParticipant() {
        // Setup
        let participantInfo = [
            ["uri": "test-participant-uri", "active": "true"],
            ["uri": "other-participant", "active": "false"]
        ]

        setupMockGetConferenceInfo(participants: participantInfo)

        // Execute
        let result = conferenceManagementService.isParticipant(
            participantURI: TestConstants.participantURI,
            activeIn: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId
        )

        // Verify
        XCTAssertNotNil(result, "Result should not be nil")
        XCTAssertEqual(result, true, "Participant should be active")
    }

    func testIsModerator() {
        // Setup for adding conference info
        let moderatorId = "moderator-id"
        let participantId = "participant-id"

        let conferenceInfo = [
            ["uri": moderatorId, "moderator": "true"],
            ["uri": participantId, "moderator": "false"]
        ]

        // Add the conference info to the service
        let participants = conferenceInfo.map { ConferenceParticipant(info: $0, onlyURIAndActive: false) }
        conferenceManagementService.handleConferenceInfoUpdated(conference: TestConstants.conferenceId, info: conferenceInfo)

        // Execute and verify moderator
        let isModerator = conferenceManagementService.isModerator(participantId: moderatorId, inConference: TestConstants.conferenceId)
        XCTAssertTrue(isModerator, "User should be identified as a moderator")

        // Execute and verify non-moderator
        let isNotModerator = conferenceManagementService.isModerator(participantId: participantId, inConference: TestConstants.conferenceId)
        XCTAssertFalse(isNotModerator, "User should not be identified as a moderator")
    }

    func testSetActiveParticipant() {
        // Setup
        let expectation1 = XCTestExpectation(description: "Set active participant called")
        let expectation2 = XCTestExpectation(description: "Set conference layout called")

        setupMockGetConferenceInfo(participants: [["uri": TestConstants.participantURI, "active": "true"]])

        mockCallsAdapter.implementation = ObjCMockImplementation { invocation in
            let selector = invocation.selector
            if selector == #selector(CallsAdapter.setActiveParticipant(_:forConference:accountId:)) {
                expectation1.fulfill()
            } else if selector == #selector(CallsAdapter.setConferenceLayout(_:forConference:accountId:)) {
                expectation2.fulfill()
            }
            return nil
        }

        // Execute
        conferenceManagementService.setActiveParticipant(
            conferenceId: TestConstants.conferenceId,
            maximixe: true,
            jamiId: TestConstants.participantURI
        )

        // Verify
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    // MARK: - Conference Event Tests
    func testHandleConferenceCreated() {
        // Setup
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId])

        // Add a pending conference
        conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)

        setupMockGetConferenceDetails(details: ["accountId": CallTestConstants.accountId, "audioOnly": "false"])

        // Setup expectation for conference event
        let eventExpectation = XCTestExpectation(description: "Conference event published")

        conferenceManagementService.currentConferenceEvent
            .skip(1) // Skip the initial empty value
            .take(1)
            .subscribe(onNext: { event in
                XCTAssertEqual(event.conferenceID, TestConstants.conferenceId, "Conference ID should match")
                XCTAssertEqual(event.state, ConferenceState.conferenceCreated.rawValue, "State should be conferenceCreated")
                XCTAssertEqual(event.calls.count, 2, "Should include 2 call IDs")
                eventExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        // Execute
        conferenceManagementService.handleConferenceCreated(conference: TestConstants.conferenceId, accountId: CallTestConstants.accountId)

        // Verify
        wait(for: [eventExpectation], timeout: 1.0)

        // Verify the conference was added to calls
        XCTAssertNotNil(calls.value[TestConstants.conferenceId], "Conference should be added to calls")
    }

    func testHandleConferenceChanged() {
        // Setup
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId])

        // Setup expectation
        let callsUpdatedExpectation = XCTestExpectation(description: "Calls updated")

        // Track calls dictionary updates
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

        // Execute
        conferenceManagementService.handleConferenceChanged(
            conference: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId,
            state: "changed"
        )

        // Verify
        wait(for: [callsUpdatedExpectation], timeout: 1.0)
        XCTAssertTrue(callsObserved, "Calls should have been updated")
    }

    func testHandleConferenceRemoved() {
        // Setup
        let eventExpectation = XCTestExpectation(description: "Conference removed event published")

        // Setup pending conference using public methods instead of directly calling private methods
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

        // Execute
        conferenceManagementService.handleConferenceRemoved(conference: TestConstants.conferenceId)

        // Verify
        wait(for: [eventExpectation], timeout: 1.0)

        // Verify conference was removed from calls
        XCTAssertNil(calls.value[TestConstants.conferenceId], "Conference should be removed from calls")

        // Verify conference was removed from pending conferences
        XCTAssertNil(
            conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.thirdCallId),
            "Conference should be removed from pending conferences"
        )
    }

    func testHandleConferenceInfoUpdated() {
        // Setup
        let participants = [
            ["uri": "participant1", "moderator": "true"],
            ["uri": "participant2", "moderator": "false"]
        ]

        let eventExpectation = XCTestExpectation(description: "Conference info updated event published")

        conferenceManagementService.currentConferenceEvent
            .skip(1) // Skip the initial empty value
            .take(1)
            .subscribe(onNext: { event in
                XCTAssertEqual(event.conferenceID, TestConstants.conferenceId, "Conference ID should match")
                XCTAssertEqual(event.state, ConferenceState.infoUpdated.rawValue, "State should be infoUpdated")
                eventExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        // Execute
        conferenceManagementService.handleConferenceInfoUpdated(
            conference: TestConstants.conferenceId,
            info: participants
        )

        // Verify
        wait(for: [eventExpectation], timeout: 1.0)

        // Verify participants were updated
        let storedParticipants = conferenceManagementService.getConferenceParticipants(for: TestConstants.conferenceId)
        XCTAssertNotNil(storedParticipants, "Participants should be stored")
        XCTAssertEqual(storedParticipants?.count, 2, "Should have 2 participants")
    }

    // MARK: - Pending Conferences Tests
    func testClearPendingConferences() {
        // Setup - use public methods to add calls to pending conferences
        let call1 = CallModel.createTestCall(withCallId: CallTestConstants.callId)

        // Add the call to multiple conferences using the public interface
        conferenceManagementService.addCall(call: call1, to: TestConstants.conferenceId)
        conferenceManagementService.addCall(call: call1, to: TestConstants.secondCallId)

        // Execute
        conferenceManagementService.clearPendingConferences(callId: CallTestConstants.callId)

        // Verify
        XCTAssertNil(
            conferenceManagementService.shouldCallBeAddedToConference(callId: CallTestConstants.callId),
            "Call should be removed from pending conferences"
        )
    }

    func testUpdateConferences() {
        // Setup
        setupMockConferenceCalls([CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId])

        // Add third call to dictionary
        var updatedCalls = calls.value
        updatedCalls[TestConstants.thirdCallId] = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)
        calls.accept(updatedCalls)

        // Setup expectation
        let callsUpdatedExpectation = XCTestExpectation(description: "Calls updated")

        // Track calls dictionary updates
        calls
            .skip(1) // Skip initial value
            .take(1)
            .subscribe(onNext: { _ in
                callsUpdatedExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        // Execute
        conferenceManagementService.updateConferences(callId: CallTestConstants.callId)

        // Verify
        wait(for: [callsUpdatedExpectation], timeout: 1.0)

        // Verify all calls have updated participantsCallId
        for callId in [CallTestConstants.callId, TestConstants.secondCallId, TestConstants.thirdCallId] {
            XCTAssertEqual(
                calls.value[callId]?.participantsCallId.count,
                3,
                "Call \(callId) should have 3 participants"
            )
        }
    }

