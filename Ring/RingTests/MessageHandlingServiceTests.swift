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
import Contacts
@testable import Ring

class MessageHandlingServiceTests: XCTestCase {

    private enum TestConstants {
        static let vCardData = "vcard-data"
    }

    private var service: MessageHandlingService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var mockDBManager: MockDBManager!
    private var calls: SynchronizedRelay<CallsDictionary>!
    private var messagesStream: PublishSubject<ServiceEvent>!
    private var disposeBag: DisposeBag!
    private var messageEvents: [ServiceEvent] = []
    private var queueHelper: ThreadSafeQueueHelper!

    override func setUp() {
        super.setUp()
        setupMocks()
        setupService()
        setupEventListeners()
    }

    override func tearDown() {
        service = nil
        mockCallsAdapter = nil
        mockDBManager = nil
        calls = nil
        messagesStream = nil
        disposeBag = nil
        queueHelper = nil
        messageEvents = []
        super.tearDown()
    }

    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        mockDBManager = MockDBManager(profileHepler: ProfileDataHelper(),
                                      conversationHelper: ConversationDataHelper(),
                                      interactionHepler: InteractionDataHelper(),
                                      dbConnections: DBContainer())
        queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagementTest", qos: .userInitiated)
        calls = SynchronizedRelay<CallsDictionary>(initialValue: [:], queueHelper: queueHelper)
        messagesStream = PublishSubject<ServiceEvent>()
        disposeBag = DisposeBag()
        messageEvents = []
    }

    private func setupService() {
        service = MessageHandlingService(
            callsAdapter: mockCallsAdapter,
            dbManager: mockDBManager,
            calls: calls,
            newMessagesStream: messagesStream
        )
    }

    private func setupEventListeners() {
        messagesStream
            .subscribe(onNext: { [weak self] event in
                self?.messageEvents.append(event)
            })
            .disposed(by: disposeBag)
    }

    private func setupCallWithId(_ callId: String = CallTestConstants.callId) {
        let call = CallModel.createTestCall(withCallId: callId)
        calls.update { calls in
            calls[callId] = call
        }
    }

    // MARK: - VCard Tests

    func testSendVCard_WithValidData_CallsDBManager() {
        let profile = Profile.createTestProfile()
        mockDBManager.accountVCardResult = profile

        service.sendVCard(callID: CallTestConstants.callId, accountID: CallTestConstants.accountId)

        let expectation = XCTestExpectation(description: "VCard sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)

        XCTAssertTrue(mockDBManager.accountVCardCalled, "DBManager accountVCard method should be called")
        XCTAssertEqual(mockDBManager.accountVCardId, CallTestConstants.accountId, "DBManager accountVCard should be called with correct accountId")
        XCTAssertEqual(mockDBManager.accountVCardResult?.uri, CallTestConstants.profileUri, "The correct profile should be retrieved")
    }

    func testSendVCard_WithEmptyCallId_DoesNothing() {
        service.sendVCard(callID: "", accountID: CallTestConstants.accountId)

        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty callId")
    }

    func testSendVCard_WithEmptyAccountId_DoesNothing() {
        service.sendVCard(callID: CallTestConstants.callId, accountID: "")

        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty accountId")
    }

    // MARK: - In-Call Message Tests

    func testSendInCallMessage_CallsAdapter() {
        setupCallWithId()
        let accountModel = AccountModel.createTestAccount()

        service.sendInCallMessage(callID: CallTestConstants.callId, message: CallTestConstants.messageContent, accountId: accountModel)

        XCTAssertTrue(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should be called")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageCallId, CallTestConstants.callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageAccountId, accountModel.id, "Account ID should match")

        XCTAssertEqual(messageEvents.count, 1, "One message event should be created")

        let event = messageEvents.first!
        XCTAssertEqual(event.eventType, .newOutgoingMessage, "Event type should be newOutgoingMessage")

        if let content: String = event.getEventInput(.content) {
            XCTAssertEqual(content, CallTestConstants.messageContent, "Event content should match the message")
        } else {
            XCTFail("Event should contain content")
        }

        if let accountId: String = event.getEventInput(.accountId) {
            XCTAssertEqual(accountId, accountModel.id, "Event account ID should match")
        } else {
            XCTFail("Event should contain account ID")
        }
    }

    func testSendInCallMessage_WithInvalidCallID_DoesNothing() {
        setupCallWithId()
        let accountModel = AccountModel.createTestAccount()

        service.sendInCallMessage(callID: CallTestConstants.invalidCallId, message: CallTestConstants.messageContent, accountId: accountModel)

        XCTAssertFalse(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should not be called with invalid call ID")
        XCTAssertEqual(messageEvents.count, 0, "No message events should be created for invalid call ID")
    }

    // MARK: - Incoming Message Tests

    func testHandleIncomingMessage_VCardMessage_PostsNotification() {
        setupCallWithId()
        let vCardMessage = [TestMIMETypes.vCard: TestConstants.vCardData]

        let expectation = XCTestExpectation(description: "Notification posted")
        var notificationReceived = false
        let notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(ProfileNotifications.messageReceived.rawValue),
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String, CallTestConstants.profileUri, "Ring ID should match fromURI")
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String, CallTestConstants.accountId, "Account ID should match call account ID")

            if let notificationMessage = notification.userInfo?[ProfileNotificationsKeys.message.rawValue] as? [String: String] {
                XCTAssertEqual(notificationMessage[TestMIMETypes.vCard], TestConstants.vCardData, "VCard data should be included in notification")
            } else {
                XCTFail("Notification should include message data")
            }

            expectation.fulfill()
        }

        service.handleIncomingMessage(callId: CallTestConstants.callId, fromURI: CallTestConstants.profileUri, message: vCardMessage)

        wait(for: [expectation], timeout: 0.1)
        XCTAssertTrue(notificationReceived, "Notification should be received")
        NotificationCenter.default.removeObserver(notificationObserver)
    }

    func testHandleIncomingMessage_TextMessage_SendsEvent() {
        setupCallWithId()
        let textMessage = [TestMIMETypes.textPlain: CallTestConstants.messageContent]

        service.handleIncomingMessage(callId: CallTestConstants.callId, fromURI: CallTestConstants.profileUri, message: textMessage)

        XCTAssertEqual(messageEvents.count, 1, "One message event should be created")

        if let event = messageEvents.first {
            if let content: String = event.getEventInput(.content) {
                XCTAssertEqual(content, CallTestConstants.messageContent, "Event content should match the message")
            } else {
                XCTFail("Event should contain content")
            }

            if let name: String = event.getEventInput(.name) {
                XCTAssertEqual(name, CallTestConstants.displayName, "Event name should match call display name")
            } else {
                XCTFail("Event should contain name")
            }

            if let peerUri: String = event.getEventInput(.peerUri) {
                XCTAssertEqual(peerUri, CallTestConstants.profileUri.filterOutHost(), "Peer URI should match the filtered fromURI")
            } else {
                XCTFail("Event should contain peer URI")
            }

            if let accountId: String = event.getEventInput(.accountId) {
                XCTAssertEqual(accountId, CallTestConstants.accountId, "Event account ID should match call account ID")
            } else {
                XCTFail("Event should contain account ID")
            }

            XCTAssertEqual(event.eventType, .newIncomingMessage, "Event type should be newIncomingMessage")
        } else {
            XCTFail("Event should be created")
        }
    }

    func testHandleIncomingMessage_WithInvalidCallID_DoesNothing() {
        setupCallWithId()
        let textMessage = [TestMIMETypes.textPlain: CallTestConstants.messageContent]

        service.handleIncomingMessage(callId: CallTestConstants.invalidCallId, fromURI: CallTestConstants.profileUri, message: textMessage)

        XCTAssertEqual(messageEvents.count, 0, "No events should be created for invalid call ID")
    }
}

// MARK: - Mock Classes

class MockDBManager: DBManager {
    var accountVCardCalled = false
    var accountVCardId: String?
    var accountVCardResult: Profile?

    override func accountVCard(for accountId: String) -> Profile? {
        accountVCardCalled = true
        accountVCardId = accountId
        return accountVCardResult
    }
}
