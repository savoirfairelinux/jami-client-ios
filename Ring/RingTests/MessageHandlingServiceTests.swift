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
        let callId = "test-call-id"
        let accountId = "test-account-id"
        
        let profileUri = "test-uri"
        let profile = Profile(uri: profileUri, type: "RING")
        mockDBManager.accountVCardResult = profile
        
        service.sendVCard(callID: callId, accountID: accountId)
        
        let expectation = XCTestExpectation(description: "VCard sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
        
        XCTAssertTrue(mockDBManager.accountVCardCalled, "DBManager accountVCard method should be called")
        XCTAssertEqual(mockDBManager.accountVCardId, accountId, "DBManager accountVCard should be called with correct accountId")
        XCTAssertEqual(mockDBManager.accountVCardResult?.uri, profileUri, "The correct profile should be retrieved")
    }
    
    func testSendVCard_WithEmptyData_DoesNothing() {
        let emptyCallId = ""
        let accountId = "test-account-id"
        
        service.sendVCard(callID: emptyCallId, accountID: accountId)
        
        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty callId")
        
        let callId = "test-call-id"
        let emptyAccountId = ""
        
        service.sendVCard(callID: callId, accountID: emptyAccountId)
        
        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty accountId")
    }
    
    func testSendInCallMessage_CallsAdapter() {
        let callId = "test-call-id"
        let message = "test message"
        let accountModel = AccountModel()
        accountModel.id = "test-account-id"
        let details: NSDictionary = [ConfigKey.accountUsername.rawValue: "test-account-id"]
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        accountModel.details = accountDetails

        let call = CallModel()
        call.callId = callId
        call.participantUri = "test-participant"
        callsRelay.accept([callId: call])

        service.sendInCallMessage(callID: callId, message: message, accountId: accountModel)
        
        XCTAssertTrue(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should be called")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageCallId, callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageAccountId, accountModel.id, "Account ID should match")
            let event = messageEvents.first!
            XCTAssertEqual(event.eventType, .newOutgoingMessage, "Event type should be newOutgoingMessage")
            
            if let content: String = event.getEventInput(.content) {
                XCTAssertEqual(content, message, "Event content should match the message")
            } else {
                XCTFail("Event should contain content")
            }
            
            if let eventAccountId: String = event.getEventInput(.accountId) {
                XCTAssertEqual(eventAccountId, accountModel.id, "Event account ID should match")
            }
    }
    
    func testSendInCallMessage_WithInvalidCallID_DoesNothing() {
        let invalidCallId = "invalid-call-id"
        let message = "test message"
        let accountModel = AccountModel()
        accountModel.id = "test-account-id"
        let details: NSDictionary = [ConfigKey.accountUsername.rawValue: "test-account-id"]
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        accountModel.details = accountDetails

        let call = CallModel()
        call.callId = "test-call-id"
        callsRelay.accept([call.callId: call])
        service.sendInCallMessage(callID: invalidCallId, message: message, accountId: accountModel)
        
        XCTAssertFalse(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should not be called with invalid call ID")
        XCTAssertEqual(messageEvents.count, 0, "No message events should be created for invalid call ID")
    }
    
    func testHandleIncomingMessage_VCardMessage_PostsNotification() {
        let callId = "test-call-id"
        let fromURI = "test-uri"
        let vCardData = "vcard-data"
        let message = ["x-ring/ring.profile.vcard;": vCardData]
        
        let call = CallModel()
        call.callId = callId
        call.accountId = "test-account-id"
        callsRelay.accept([callId: call])
        
        let expectation = XCTestExpectation(description: "Notification posted")
        var notificationReceived = false
        let notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(ProfileNotifications.messageReceived.rawValue),
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String, fromURI, "Ring ID should match fromURI")
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String, call.accountId, "Account ID should match call account ID")
            
            // Verify message content is included in notification
            if let notificationMessage = notification.userInfo?[ProfileNotificationsKeys.message.rawValue] as? [String: String] {
                XCTAssertEqual(notificationMessage["x-ring/ring.profile.vcard;"], vCardData, "VCard data should be included in notification")
            } else {
                XCTFail("Notification should include message data")
            }
            
            expectation.fulfill()
        }
        
        service.handleIncomingMessage(callId: callId, fromURI: fromURI, message: message)
        
        wait(for: [expectation], timeout: 0.1)
        XCTAssertTrue(notificationReceived, "Notification should be received")
        NotificationCenter.default.removeObserver(notificationObserver)
    }
    
    func testHandleIncomingMessage_TextMessage_SendsEvent() {
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

        service.handleIncomingMessage(callId: callId, fromURI: fromURI, message: message)
        
        XCTAssertEqual(messageEvents.count, 1, "One message event should be created")
        if let event = messageEvents.first {
            if let content: String = event.getEventInput(.content) {
                XCTAssertEqual(content, messageContent, "Event content should match the message")
            } else {
                XCTFail("Event should contain content")
            }
            
            if let name: String = event.getEventInput(.name) {
                XCTAssertEqual(name, call.displayName, "Event name should match call display name")
            } else {
                XCTFail("Event should contain name")
            }
            
            if let peerUri: String = event.getEventInput(.peerUri) {
                XCTAssertEqual(peerUri, fromURI.filterOutHost(), "Peer URI should match the filtered fromURI")
            } else {
                XCTFail("Event should contain peer URI")
            }
            
            if let accountId: String = event.getEventInput(.accountId) {
                XCTAssertEqual(accountId, call.accountId, "Event account ID should match call account ID")
            } else {
                XCTFail("Event should contain account ID")
            }
            
            XCTAssertEqual(event.eventType, .newIncomingMessage, "Event type should be newIncomingMessage")
        }
    }
    
    func testHandleIncomingMessage_WithInvalidCallID_DoesNothing() {
        let invalidCallId = "invalid-call-id"
        let fromURI = "test-uri"
        let message = ["text/plain": "Hello world"]
        
        service.handleIncomingMessage(callId: invalidCallId, fromURI: fromURI, message: message)
        
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


