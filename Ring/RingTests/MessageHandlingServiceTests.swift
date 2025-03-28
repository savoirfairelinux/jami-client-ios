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
    
    // MARK: - Test Constants
    
    private enum TestConstants {
        static let accountId = "test-account-id"
        static let callId = "test-call-id"
        static let invalidCallId = "invalid-call-id"
        static let profileUri = "test-uri"
        static let messageContent = "test message"
        static let participantUri = "test-participant"
        static let displayName = "John Doe"
        static let registeredName = "john"
        static let vCardData = "vcard-data"
    }
    
    // MARK: - MIME Types
    
    private enum MIMETypes {
        static let textPlain = "text/plain"
        static let vCard = "x-ring/ring.profile.vcard;"
    }
    
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
        setupMocks()
        setupService()
        setupEventListeners()
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
    
    // MARK: - Test Setup Helpers
    
    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        mockDBManager = MockDBManager(profileHepler: ProfileDataHelper(),
                                      conversationHelper: ConversationDataHelper(),
                                      interactionHepler: InteractionDataHelper(),
                                      dbConnections: DBContainer())
        callsRelay = BehaviorRelay<[String: CallModel]>(value: [:])
        messagesStream = PublishSubject<ServiceEvent>()
        disposeBag = DisposeBag()
        messageEvents = []
    }
    
    private func setupService() {
        service = MessageHandlingService(
            callsAdapter: mockCallsAdapter,
            dbManager: mockDBManager,
            calls: callsRelay,
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
    
    // MARK: - Test Fixture Helpers
    
    private func createTestProfile() -> Profile {
        return Profile(uri: TestConstants.profileUri, type: "RING")
    }
    
    private func createTestCall(withCallId callId: String = TestConstants.callId) -> CallModel {
        let call = CallModel()
        call.callId = callId
        call.accountId = TestConstants.accountId
        call.participantUri = TestConstants.participantUri
        call.displayName = TestConstants.displayName
        call.registeredName = TestConstants.registeredName
        return call
    }
    
    private func createTestAccount() -> AccountModel {
        let accountModel = AccountModel()
        accountModel.id = TestConstants.accountId
        
        let details: NSDictionary = [ConfigKey.accountUsername.rawValue: TestConstants.accountId]
        let accountDetailsDict = details as NSDictionary? as? [String: String] ?? nil
        let accountDetails = AccountConfigModel(withDetails: accountDetailsDict)
        
        accountModel.details = accountDetails
        return accountModel
    }
    
    private func setupCallWithId(_ callId: String) {
        let call = createTestCall(withCallId: callId)
        callsRelay.accept([callId: call])
    }
    
    // MARK: - VCard Tests
    
    func testSendVCard_WithValidData_CallsDBManager() {
        let profile = createTestProfile()
        mockDBManager.accountVCardResult = profile
        
        service.sendVCard(callID: TestConstants.callId, accountID: TestConstants.accountId)
        
        let expectation = XCTestExpectation(description: "VCard sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.2)
        
        XCTAssertTrue(mockDBManager.accountVCardCalled, "DBManager accountVCard method should be called")
        XCTAssertEqual(mockDBManager.accountVCardId, TestConstants.accountId, "DBManager accountVCard should be called with correct accountId")
        XCTAssertEqual(mockDBManager.accountVCardResult?.uri, TestConstants.profileUri, "The correct profile should be retrieved")
    }
    
    func testSendVCard_WithEmptyCallId_DoesNothing() {
        service.sendVCard(callID: "", accountID: TestConstants.accountId)
        
        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty callId")
    }
    
    func testSendVCard_WithEmptyAccountId_DoesNothing() {
        service.sendVCard(callID: TestConstants.callId, accountID: "")
        
        XCTAssertFalse(mockDBManager.accountVCardCalled, "DBManager accountVCard should not be called with empty accountId")
    }
    
    // MARK: - In-Call Message Tests
    
    func testSendInCallMessage_CallsAdapter() {
        setupCallWithId(TestConstants.callId)
        let accountModel = createTestAccount()
        
        service.sendInCallMessage(callID: TestConstants.callId, message: TestConstants.messageContent, accountId: accountModel)
        
        XCTAssertTrue(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should be called")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageCallId, TestConstants.callId, "Call ID should match")
        XCTAssertEqual(mockCallsAdapter.sentTextMessageAccountId, accountModel.id, "Account ID should match")
        
        XCTAssertEqual(messageEvents.count, 1, "One message event should be created")
        
        let event = messageEvents.first!
        XCTAssertEqual(event.eventType, .newOutgoingMessage, "Event type should be newOutgoingMessage")
        
        if let content: String = event.getEventInput(.content) {
            XCTAssertEqual(content, TestConstants.messageContent, "Event content should match the message")
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
        setupCallWithId(TestConstants.callId)
        let accountModel = createTestAccount()
        
        service.sendInCallMessage(callID: TestConstants.invalidCallId, message: TestConstants.messageContent, accountId: accountModel)
        
        XCTAssertFalse(mockCallsAdapter.sendTextMessageCalled, "sendTextMessage should not be called with invalid call ID")
        XCTAssertEqual(messageEvents.count, 0, "No message events should be created for invalid call ID")
    }
    
    // MARK: - Incoming Message Tests
    
    func testHandleIncomingMessage_VCardMessage_PostsNotification() {
        setupCallWithId(TestConstants.callId)
        let vCardMessage = [MIMETypes.vCard: TestConstants.vCardData]
        
        let expectation = XCTestExpectation(description: "Notification posted")
        var notificationReceived = false
        let notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name(ProfileNotifications.messageReceived.rawValue),
            object: nil,
            queue: .main
        ) { notification in
            notificationReceived = true
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.ringID.rawValue] as? String, TestConstants.profileUri, "Ring ID should match fromURI")
            XCTAssertEqual(notification.userInfo?[ProfileNotificationsKeys.accountId.rawValue] as? String, TestConstants.accountId, "Account ID should match call account ID")
            
            if let notificationMessage = notification.userInfo?[ProfileNotificationsKeys.message.rawValue] as? [String: String] {
                XCTAssertEqual(notificationMessage[MIMETypes.vCard], TestConstants.vCardData, "VCard data should be included in notification")
            } else {
                XCTFail("Notification should include message data")
            }
            
            expectation.fulfill()
        }
        
        service.handleIncomingMessage(callId: TestConstants.callId, fromURI: TestConstants.profileUri, message: vCardMessage)
        
        wait(for: [expectation], timeout: 0.1)
        XCTAssertTrue(notificationReceived, "Notification should be received")
        NotificationCenter.default.removeObserver(notificationObserver)
    }
    
    func testHandleIncomingMessage_TextMessage_SendsEvent() {
        setupCallWithId(TestConstants.callId)
        let textMessage = [MIMETypes.textPlain: TestConstants.messageContent]
        
        service.handleIncomingMessage(callId: TestConstants.callId, fromURI: TestConstants.profileUri, message: textMessage)
        
        XCTAssertEqual(messageEvents.count, 1, "One message event should be created")
        
        if let event = messageEvents.first {
            if let content: String = event.getEventInput(.content) {
                XCTAssertEqual(content, TestConstants.messageContent, "Event content should match the message")
            } else {
                XCTFail("Event should contain content")
            }
            
            if let name: String = event.getEventInput(.name) {
                XCTAssertEqual(name, TestConstants.displayName, "Event name should match call display name")
            } else {
                XCTFail("Event should contain name")
            }
            
            if let peerUri: String = event.getEventInput(.peerUri) {
                XCTAssertEqual(peerUri, TestConstants.profileUri.filterOutHost(), "Peer URI should match the filtered fromURI")
            } else {
                XCTFail("Event should contain peer URI")
            }
            
            if let accountId: String = event.getEventInput(.accountId) {
                XCTAssertEqual(accountId, TestConstants.accountId, "Event account ID should match call account ID")
            } else {
                XCTFail("Event should contain account ID")
            }
            
            XCTAssertEqual(event.eventType, .newIncomingMessage, "Event type should be newIncomingMessage")
        } else {
            XCTFail("Event should be created")
        }
    }
    
    func testHandleIncomingMessage_WithInvalidCallID_DoesNothing() {
        setupCallWithId(TestConstants.callId)
        let textMessage = [MIMETypes.textPlain: TestConstants.messageContent]
        
        service.handleIncomingMessage(callId: TestConstants.invalidCallId, fromURI: TestConstants.profileUri, message: textMessage)
        
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


