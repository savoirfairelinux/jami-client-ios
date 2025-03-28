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
    private var queueHelper: ThreadSafeQueueHelper!

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
        queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagementTest", qos: .userInitiated)
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
            calls: calls,
            queueHelper: queueHelper
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
    
    private func setupCallWithSingleParticipant(_ callId: String) {
        var callsDict = calls.value
        let singleCall = CallModel.createTestCall(withCallId: callId)
        singleCall.participantsCallId = Set([callId]) // One participant (itself)
        callsDict[callId] = singleCall
        calls.accept(callsDict)
    }
    
    private func setupCallWithMultipleParticipants(_ callId: String, participants: [String]) {
        var callsDict = calls.value
        let conferenceCall = CallModel.createTestCall(withCallId: callId)
        conferenceCall.participantsCallId = Set(participants)
        callsDict[callId] = conferenceCall
        calls.accept(callsDict)
    }
    
    private func setupCallWithLayout(_ callId: String, layout: CallLayout) {
        var callsDict = calls.value
        let call = callsDict[callId] ?? CallModel.createTestCall(withCallId: callId)
        call.layout = layout
        callsDict[callId] = call
        calls.accept(callsDict)
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

    // MARK: - Participant Testing Helpers
    private func createParticipantInfo(uri: String, isModerator: Bool, isActive: Bool = true) -> [String: String] {
        return [
            "uri": uri,
            "isModerator": isModerator ? "true" : "false",
            "active": isActive ? "true" : "false"
        ]
    }
    
    private func setupConferenceInfoWithParticipants(conferenceId: String, participants: [[String: String]]) async {
        await conferenceManagementService.handleConferenceInfoUpdated(
            conference: conferenceId,
            info: participants
        )
    }
    
    private func verifyModerator(participantId: String, conferenceId: String, expectedResult: Bool, message: String) {
        XCTAssertEqual(
            conferenceManagementService.isModerator(
                participantId: participantId,
                inConference: conferenceId
            ),
            expectedResult,
            message
        )
    }

    private func verifyStoredParticipants(forConference conferenceId: String, count: Int, moderatorCount: Int, moderatorUris: [String] = []) {
        let storedParticipants = conferenceManagementService.getConferenceParticipants(for: conferenceId)
        XCTAssertNotNil(storedParticipants, "Participants should be stored")
        XCTAssertEqual(storedParticipants?.count, count, "Should have \(count) participants")
        
        if let participants = storedParticipants {
            let moderators = participants.filter { $0.isModerator }
            XCTAssertEqual(moderators.count, moderatorCount, "\(moderatorCount) participant(s) should be moderator(s)")
            
            for moderatorUri in moderatorUris where !moderatorUri.isEmpty {
                XCTAssertTrue(
                    moderators.contains(where: { $0.uri == moderatorUri }),
                    "Participant with URI '\(moderatorUri)' should be a moderator"
                )
            }
        }
    }

    // MARK: - Join Conference Tests
    func testJoinConference_WithSingleCall() {
        let expectation = XCTestExpectation(description: "Join conference completed")
        setupCallWithSingleParticipant(CallTestConstants.callId)

        Task {
            await conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: CallTestConstants.callId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)

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

        let conferenceId = conferenceManagementService.shouldCallBeAddedToConference(callId: CallTestConstants.callId)
        XCTAssertEqual(conferenceId, TestConstants.conferenceId, "Call should be added to the expected pending conference")
    }
    
    func testJoinConference_WithConferenceCall() {
        let expectation = XCTestExpectation(description: "Join conference completed")
        setupCallWithMultipleParticipants(
            TestConstants.secondCallId,
            participants: [TestConstants.secondCallId, TestConstants.thirdCallId]
        )
        
        Task {
            await conferenceManagementService.joinConference(confID: TestConstants.conferenceId, callID: TestConstants.secondCallId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
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
        
        let conferenceId = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.secondCallId)
        XCTAssertEqual(conferenceId, TestConstants.conferenceId, "Call should be added to the expected pending conference")
    }

    func testJoinCall() {
        let expectation = XCTestExpectation(description: "Join call completed")
        
        Task {
            await conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify the adapter was called with correct parameters
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
        
        // Verify the result
        let conferenceId = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.secondCallId)
        XCTAssertEqual(conferenceId, CallTestConstants.callId, "Call should be added to the expected pending conference")
    }

    func testAddCall() {
        let newCall = CallModel.createTestCall(withCallId: TestConstants.thirdCallId)
        
        // Create expectations
        let inConferenceExpectation = XCTestExpectation(description: "Call added to conference")
        let addCallExpectation = XCTestExpectation(description: "Add call completed")
        
        // Subscribe to the inConferenceCalls subject
        conferenceManagementService.inConferenceCalls
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, TestConstants.thirdCallId, "Added call should match the expected call")
                inConferenceExpectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        // Execute the method that triggers the async operation
        Task {
            await conferenceManagementService.addCall(call: newCall, to: TestConstants.conferenceId)
            addCallExpectation.fulfill()
        }
        
        // Wait for both async operations to complete
        wait(for: [inConferenceExpectation, addCallExpectation], timeout: 1.0)
        
        // Verify the result
        let conferenceId = conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.thirdCallId)
        XCTAssertEqual(conferenceId, TestConstants.conferenceId, "Call should be added to the expected pending conference")
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
        // Setup - create active and inactive participant info
        let activeParticipantId = "active-participant-id"
        let inactiveParticipantId = "inactive-participant-id"
        let nonExistentId = "non-existent-id"
        
        let participants = [
            createParticipantInfo(uri: activeParticipantId, isModerator: false, isActive: true),
            createParticipantInfo(uri: inactiveParticipantId, isModerator: false, isActive: false)
        ]
        
        // Set up return value from adapter
        mockCallsAdapter.getConferenceInfoReturnValue = participants
        
        // Add conference participant info directly to conferenceInfosRelay
        let infoUpdateExpectation = XCTestExpectation(description: "Conference info updated")
        
        Task {
            await conferenceManagementService.handleConferenceInfoUpdated(
                conference: TestConstants.conferenceId,
                info: participants
            )
            infoUpdateExpectation.fulfill()
        }
        
        wait(for: [infoUpdateExpectation], timeout: 1.0)
        
        // Test active participant
        let activeResult = conferenceManagementService.isParticipant(
            participantURI: activeParticipantId,
            activeIn: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId
        )
        XCTAssertEqual(activeResult, true, "User with active=true should be identified as an active participant")
        
        // Test inactive participant
        let inactiveResult = conferenceManagementService.isParticipant(
            participantURI: inactiveParticipantId,
            activeIn: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId
        )
        XCTAssertEqual(inactiveResult, false, "User with active=false should not be identified as an active participant")
        
        // Test non-existent participant
        let nonExistentResult = conferenceManagementService.isParticipant(
            participantURI: nonExistentId,
            activeIn: TestConstants.conferenceId,
            accountId: CallTestConstants.accountId
        )
        XCTAssertTrue(nonExistentResult == nil || nonExistentResult == false, "Non-existent user should return nil or false")
    }

    func testIsModerator() {
        // Setup - create moderator and non-moderator participant info
        let moderatorId = "moderator-id"
        let participantId = "participant-id"
        let nonExistentId = "non-existent-id"
        
        let participants = [
            createParticipantInfo(uri: moderatorId, isModerator: true),
            createParticipantInfo(uri: participantId, isModerator: false)
        ]
        
        // Add conference participant info directly to conferenceInfosRelay
        // Create an expectation to wait for the async operation
        let infoUpdateExpectation = XCTestExpectation(description: "Conference info updated")
        
        Task {
            await conferenceManagementService.handleConferenceInfoUpdated(
                conference: TestConstants.conferenceId,
                info: participants
            )
            infoUpdateExpectation.fulfill()
        }
        
        wait(for: [infoUpdateExpectation], timeout: 1.0)
        
        // Test all scenarios
        verifyModerator(
            participantId: moderatorId,
            conferenceId: TestConstants.conferenceId,
            expectedResult: true,
            message: "User with isModerator=true should be identified as a moderator"
        )
        
        verifyModerator(
            participantId: participantId,
            conferenceId: TestConstants.conferenceId,
            expectedResult: false,
            message: "User with isModerator=false should not be identified as a moderator"
        )
        
        verifyModerator(
            participantId: nonExistentId,
            conferenceId: TestConstants.conferenceId,
            expectedResult: false,
            message: "Non-existent user should not be identified as a moderator"
        )
    }

    // MARK: - Layout Tests
    func testSetActiveParticipant_Maximize() {
        setupMockGetConferenceInfo(participants: [
            ["uri": TestConstants.participantURI, "active": "true"]
        ])
        setupCallWithLayout(TestConstants.conferenceId, layout: .grid)

        let expectation = XCTestExpectation(description: "Set active participant completed")
        
        Task {
            await conferenceManagementService.setActiveParticipant(
                conferenceId: TestConstants.conferenceId,
                maximixe: true,
                jamiId: TestConstants.participantURI
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)

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

        let expectation = XCTestExpectation(description: "Set active participant completed")
        
        Task {
            await conferenceManagementService.setActiveParticipant(
                conferenceId: TestConstants.conferenceId,
                maximixe: false,
                jamiId: TestConstants.participantURI
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)

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

        let expectation = XCTestExpectation(description: "Set active participant completed")
        
        Task {
            await conferenceManagementService.setActiveParticipant(
                conferenceId: TestConstants.conferenceId,
                maximixe: true,
                jamiId: TestConstants.participantURI
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)

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
        let joinCallExpectation = XCTestExpectation(description: "Join call completed")
        
        Task {
            await conferenceManagementService.joinCall(firstCallId: CallTestConstants.callId, secondCallId: TestConstants.secondCallId)
            joinCallExpectation.fulfill()
        }
        
        wait(for: [joinCallExpectation], timeout: 1.0)
        
        setupMockGetConferenceDetails(details: ["accountId": CallTestConstants.accountId, "audioOnly": "false"])

        let eventExpectation = expectConferenceEvent(
            conferenceId: TestConstants.conferenceId,
            state: .conferenceCreated
        )
        
        let createExpectation = XCTestExpectation(description: "Conference created completed")
        Task {
            await conferenceManagementService.handleConferenceCreated(conference: TestConstants.conferenceId, accountId: CallTestConstants.accountId)
            createExpectation.fulfill()
        }

        wait(for: [createExpectation, eventExpectation], timeout: 1.0)
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
        let changeExpectation = XCTestExpectation(description: "Conference changed completed")

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

        Task {
            await conferenceManagementService.handleConferenceChanged(
                conference: TestConstants.conferenceId,
                accountId: CallTestConstants.accountId,
                state: "changed"
            )
            changeExpectation.fulfill()
        }

        wait(for: [changeExpectation, callsUpdatedExpectation], timeout: 1.0)
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
        let addCallExpectation = XCTestExpectation(description: "Add call completed")
        
        Task {
            await conferenceManagementService.addCall(call: thirdCall, to: TestConstants.conferenceId)
            addCallExpectation.fulfill()
        }
        
        wait(for: [addCallExpectation], timeout: 1.0)

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

        Task {
            await conferenceManagementService.handleConferenceRemoved(conference: TestConstants.conferenceId)
        }

        wait(for: [eventExpectation], timeout: 1.0)
        XCTAssertNil(calls.value[TestConstants.conferenceId], "Conference should be removed from calls")
        XCTAssertNil(
            conferenceManagementService.shouldCallBeAddedToConference(callId: TestConstants.thirdCallId),
            "Conference should be removed from pending conferences"
        )
    }

    func testHandleConferenceInfoUpdated() {
        // Setup participant info
        let moderatorUri = "participant1"
        let regularUri = "participant2"
        
        let participants = [
            createParticipantInfo(uri: moderatorUri, isModerator: true),
            createParticipantInfo(uri: regularUri, isModerator: false)
        ]
        
        // Setup expectation for event
        let eventExpectation = expectConferenceEvent(
            conferenceId: TestConstants.conferenceId,
            state: .infoUpdated
        )
        
        // Execute with async handling
        let setupExpectation = XCTestExpectation(description: "Setup completed")
        Task {
            await conferenceManagementService.handleConferenceInfoUpdated(
                conference: TestConstants.conferenceId,
                info: participants
            )
            setupExpectation.fulfill()
        }
        
        // Wait for the async operation to complete
        wait(for: [setupExpectation], timeout: 1.0)
        
        // Verify event was published
        wait(for: [eventExpectation], timeout: 1.0)
        
        // Verify participants were stored and have correct attributes
        verifyStoredParticipants(
            forConference: TestConstants.conferenceId,
            count: 2, 
            moderatorCount: 1,
            moderatorUris: [moderatorUri]
        )
    }

    // MARK: - Pending Conferences Tests
    func testClearPendingConferences() {
        let call1 = CallModel.createTestCall(withCallId: CallTestConstants.callId)
        let addCallExpectation1 = XCTestExpectation(description: "First add call completed")
        let addCallExpectation2 = XCTestExpectation(description: "Second add call completed")
        let clearExpectation = XCTestExpectation(description: "Clear pending conferences completed")
        
        Task {
            await conferenceManagementService.addCall(call: call1, to: TestConstants.conferenceId)
            addCallExpectation1.fulfill()
        }
        
        wait(for: [addCallExpectation1], timeout: 1.0)
        
        Task {
            await conferenceManagementService.addCall(call: call1, to: TestConstants.secondCallId)
            addCallExpectation2.fulfill()
        }
        
        wait(for: [addCallExpectation2], timeout: 1.0)

        Task {
            await conferenceManagementService.clearPendingConferences(callId: CallTestConstants.callId)
            clearExpectation.fulfill()
        }
        
        wait(for: [clearExpectation], timeout: 1.0)

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
        let updateExpectation = XCTestExpectation(description: "Update conferences completed")

        calls
            .skip(1) // Skip initial value
            .take(1)
            .subscribe(onNext: { _ in
                callsUpdatedExpectation.fulfill()
            })
            .disposed(by: disposeBag)

        Task {
            await conferenceManagementService.updateConferences(callId: CallTestConstants.callId)
            updateExpectation.fulfill()
        }

        wait(for: [updateExpectation, callsUpdatedExpectation], timeout: 1.0)
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

    // MARK: - Participant Management Tests
    
    func testSetModeratorParticipant() {
        let expectation = XCTestExpectation(description: "Set moderator participant completed")
        setupCallWithSingleParticipant(TestConstants.conferenceId)
        
        Task {
            await conferenceManagementService.setModeratorParticipant(
                confId: TestConstants.conferenceId,
                participantId: TestConstants.participantURI,
                active: true
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        verifyAdapter(
            property: mockCallsAdapter.setConferenceModeratorCallCount,
            expectedValue: 1,
            message: "Set conference moderator should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceModeratorParticipantId,
            expectedValue: TestConstants.participantURI,
            message: "Participant ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceModeratorConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.setConferenceModeratorActive,
            expectedValue: true,
            message: "Active state should match"
        )
    }
    
    func testHangupParticipant() {
        let expectation = XCTestExpectation(description: "Hangup participant completed")
        setupCallWithSingleParticipant(TestConstants.conferenceId)
        
        Task {
            await conferenceManagementService.hangupParticipant(
                confId: TestConstants.conferenceId,
                participantId: TestConstants.participantURI,
                device: TestConstants.deviceId
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        verifyAdapter(
            property: mockCallsAdapter.hangupConferenceParticipantCallCount,
            expectedValue: 1,
            message: "Hangup conference participant should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangupConferenceParticipantParticipantId,
            expectedValue: TestConstants.participantURI,
            message: "Participant ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangupConferenceParticipantConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.hangupConferenceParticipantDeviceId,
            expectedValue: TestConstants.deviceId,
            message: "Device ID should match"
        )
    }
    
    func testMuteStream() {
        let expectation = XCTestExpectation(description: "Mute stream completed")
        
        Task {
            await conferenceManagementService.muteStream(
                confId: TestConstants.conferenceId,
                participantId: TestConstants.participantURI,
                device: TestConstants.deviceId,
                accountId: CallTestConstants.accountId,
                streamId: TestConstants.streamId,
                state: true
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        verifyAdapter(
            property: mockCallsAdapter.muteStreamCallCount,
            expectedValue: 1,
            message: "Mute stream should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.muteStreamParticipantId,
            expectedValue: TestConstants.participantURI,
            message: "Participant ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.muteStreamConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.muteStreamDeviceId,
            expectedValue: TestConstants.deviceId,
            message: "Device ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.muteStreamStreamId,
            expectedValue: TestConstants.streamId,
            message: "Stream ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.muteStreamState,
            expectedValue: true,
            message: "State should match"
        )
    }
    
    func testSetRaiseHand() {
        let expectation = XCTestExpectation(description: "Set raise hand completed")
        
        Task {
            await conferenceManagementService.setRaiseHand(
                confId: TestConstants.conferenceId,
                participantId: TestConstants.participantURI,
                state: true,
                accountId: CallTestConstants.accountId,
                deviceId: TestConstants.deviceId
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        verifyAdapter(
            property: mockCallsAdapter.raiseHandCallCount,
            expectedValue: 1,
            message: "Raise hand should be called"
        )
        verifyAdapter(
            property: mockCallsAdapter.raiseHandParticipantId,
            expectedValue: TestConstants.participantURI,
            message: "Participant ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.raiseHandConferenceId,
            expectedValue: TestConstants.conferenceId,
            message: "Conference ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.raiseHandDeviceId,
            expectedValue: TestConstants.deviceId,
            message: "Device ID should match"
        )
        verifyAdapter(
            property: mockCallsAdapter.raiseHandState,
            expectedValue: true,
            message: "State should match"
        )
    }
}

