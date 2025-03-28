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
    
    // MARK: - Properties
    
    private var service: MessageHandlingService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var mockDBManager: MockDBManager!
    private var callsRelay: BehaviorRelay<[String: CallModel]>!
    private var messagesStream: PublishSubject<ServiceEvent>!
    private var disposeBag: DisposeBag!
    private var messageEvents: [ServiceEvent] = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockCallsAdapter = ObjCMockCallsAdapter()
        mockDBManager = MockDBManager(profileHepler: ProfileDataHelper(),
                                      conversationHelper: ConversationDataHelper(),
                                      interactionHepler: InteractionDataHelper(),
                                      dbConnections: DBContainer())
        callsRelay = BehaviorRelay<[String: CallModel]>(value: [:])
        messagesStream = PublishSubject<ServiceEvent>()
        disposeBag = DisposeBag()
        messageEvents = []
        
        // Capture messages for testing
        messagesStream
            .subscribe(onNext: { [weak self] event in
                self?.messageEvents.append(event)
            })
            .disposed(by: disposeBag)
        
        service = MessageHandlingService(
            callsAdapter: mockCallsAdapter,
            dbManager: mockDBManager,
            calls: callsRelay,
            newMessagesStream: messagesStream
        )
    }
    
    override func tearDown() {
        service = nil
        mockCallsAdapter = nil
        mockDBManager = nil
        callsRelay = nil
        messagesStream = nil
        disposeBag = nil
        messageEvents = []
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    func testSendVCard_WithValidData_CallsDBManager() {
        // Given
        let callId = "test-call-id"
        let accountId = "test-account-id"
        
        // Configure mock profile
        let profile = Profile(uri: "test-uri", type: "RING")
        mockDBManager.accountVCardResult = profile
        
        // When
        service.sendVCard(callID: callId, accountID: accountId)
        
        // Allow background task to complete
        let expectation = XCTestExpectation(description: "VCard sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
        
        // Then
        XCTAssertTrue(mockDBManager.accountVCardCalled)
        XCTAssertEqual(mockDBManager.accountVCardId, accountId)
    }
    
    func testSendVCard_WithEmptyData_DoesNothing() {
        // Given
        let emptyCallId = ""
        let accountId = "test-account-id"
        
        // When
        service.sendVCard(callID: emptyCallId, accountID: accountId)
        
        // Then
        XCTAssertFalse(mockDBManager.accountVCardCalled)
        
        // Given
        let callId = "test-call-id"
        let emptyAccountId = ""
        
        // When
        service.sendVCard(callID: callId, accountID: emptyAccountId)
        
        // Then
        XCTAssertFalse(mockDBManager.accountVCardCalled)
    }
    
    func testSendInCallMessage_CallsAdapter() {
        // Given
        let callId = "test-call-id"
        let message = "test message"
        let accountModel = AccountModel()
        accountModel.id = "test-account-id"
        
        let call = CallModel()
        call.callId = callId
        call.participantUri = "test-participant"
        callsRelay.accept([callId: call])
        
        // Setup ObjCMockCallsAdapter to track the sendTextMessage call
        // This assumes we've added properties to ObjCMockCallsAdapter in the TestableModels folder
        mockCallsAdapter.sendTextMessageCalled = false
        mockCallsAdapter.sentTextMessageCallId = nil
        mockCallsAdapter.sentTextMessageAccountId = nil
        mockCallsAdapter.sentTextMessageMessage = nil
        
        // When
        service.sendInCallMessage(callID: callId, message: message, accountId: accountModel)
        
        // Then
        XCTAssertTrue(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should be called")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageCallId, callId)
        XCTAssertEqual(mockCallsAdapter.sentTextMessageAccountId, accountModel.id)
        
        // Check the message dictionary contains our message with the right key
        if let messageDictionary = mockCallsAdapter.sentTextMessageMessage as? [String: String] {
            XCTAssertEqual(messageDictionary["text/plain"], message)
        } else {
            XCTFail("Message dictionary should be a valid [String: String]")
        }
    }
    
    func testSendInCallMessage_WithInvalidCallID_DoesNothing() {
        // Given
        let invalidCallId = "invalid-call-id"
        let message = "test message"
        let accountModel = AccountModel()
        accountModel.id = "test-account-id"
        
        let call = CallModel()
        call.callId = "test-call-id"
        callsRelay.accept([call.callId: call])
        
        // Setup tracking for sendTextMessage
        var sendTextMessageCalled = false

        // When
        service.sendInCallMessage(callID: invalidCallId, message: message, accountId: accountModel)
        
        // Then
        XCTAssertFalse(sendTextMessageCalled)
        XCTAssertEqual(messageEvents.count, 0)
    }
    
    func testHandleIncomingMessage_VCardMessage_PostsNotification() {
        // Given
        let callId = "test-call-id"
        let fromURI = "test-uri"
        let message = ["x-ring/ring.profile.vcard;": "vcard-data"]
        
        let call = CallModel()
        call.callId = callId
        call.accountId = "test-account-id"
        callsRelay.accept([callId: call])
        
        let expectation = XCTestExpectation(description: "Notification posted")
        let notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(ProfileNotifications.messageReceived.rawValue),
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String, fromURI)
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String, call.accountId)
            expectation.fulfill()
        }
        
        // When
        service.handleIncomingMessage(callId: callId, fromURI: fromURI, message: message)
        
        // Then
        wait(for: [expectation], timeout: 0.1)
        NotificationCenter.default.removeObserver(notificationObserver)
    }
    
    func testHandleIncomingMessage_TextMessage_SendsEvent() {
        // Given
        let callId = "test-call-id"
        let fromURI = "test-uri"
        let messageContent = "Hello world"
        let message = ["text/plain": messageContent]
        
        let call = CallModel()
        call.callId = callId
        call.accountId = "test-account-id"
        call.displayName = "John Doe"
        call.registeredName = "john"
        callsRelay.accept([callId: call])
        
        // When
        service.handleIncomingMessage(callId: callId, fromURI: fromURI, message: message)
        
        // Then
        XCTAssertEqual(messageEvents.count, 1)
        let event = messageEvents.first!
        XCTAssertEqual(event.getEventInput(.content) as String?, messageContent)
        XCTAssertEqual(event.getEventInput(.name) as String?, call.displayName)
    }
    
    func testHandleIncomingMessage_WithInvalidCallID_DoesNothing() {
        // Given
        let invalidCallId = "invalid-call-id"
        let fromURI = "test-uri"
        let message = ["text/plain": "Hello world"]
        
        // When
        service.handleIncomingMessage(callId: invalidCallId, fromURI: fromURI, message: message)
        
        // Then
        XCTAssertEqual(messageEvents.count, 0)
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


