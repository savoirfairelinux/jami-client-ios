import XCTest
@testable import Ring

final class ActiveCallsHelperTests: XCTestCase {
    // MARK: - Properties
    private var activeCallsHelper: ActiveCallsHelper!

    // MARK: - Setup & Teardown
    override func setUp() {
        super.setUp()
        activeCallsHelper = ActiveCallsHelper()
    }

    override func tearDown() {
        activeCallsHelper = nil
        super.tearDown()
    }

    // MARK: - Tests
    func testActiveCallsChanged_WithValidCalls_UpdatesCallsCorrectly() {
        // Given
        let accountId = "account1"
        let conversationId = "conv1"
        let calls = [
            ["id": "call1", "uri": "uri1", "device": "device1"],
            ["id": "call2", "uri": "uri2", "device": "device2"]
        ]
        let account = AccountModel(withAccountId: accountId)

        // When
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId, calls: calls, account: account)

        // Then
        let result = activeCallsHelper.activeCalls.value
        XCTAssertNotNil(result[accountId])
        let accountCalls = result[accountId]!
        let conversationCalls = accountCalls.calls(for: conversationId)
        XCTAssertEqual(conversationCalls.count, 2)
        XCTAssertEqual(conversationCalls[0].id, "call1")
        XCTAssertEqual(conversationCalls[1].id, "call2")
    }

    func testActiveCallsChanged_WithEmptyCalls_ClearsIgnoredCalls() {
        // Given
        let accountId = "account1"
        let conversationId = "conv1"
        let account = AccountModel(withAccountId: accountId)
        let call = ActiveCall(id: "call1", uri: "uri1", device: "device1", conversationId: conversationId, accountId: accountId, isfromLocalDevice: false)

        // When
        activeCallsHelper.ignoreCall(call)
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId, calls: [], account: account)

        // Then
        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let ignoredCalls = accountCalls.ignoredCalls(for: conversationId)
        XCTAssertTrue(ignoredCalls.isEmpty)
    }

    func testIgnoreCall_AddsCallToIgnoredCalls() {
        // Given
        let accountId = "account1"
        let conversationId = "conv1"
        let call = ActiveCall(id: "call1", uri: "uri1", device: "device1", conversationId: conversationId, accountId: accountId, isfromLocalDevice: false)

        // When
        activeCallsHelper.ignoreCall(call)

        // Then
        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let ignoredCalls = accountCalls.ignoredCalls(for: conversationId)
        XCTAssertEqual(ignoredCalls.count, 1)
        XCTAssertEqual(ignoredCalls[0].id, "call1")
    }

    func testActiveCallsChanged_WithInvalidCallData_IgnoresInvalidCalls() {
        // Given
        let accountId = "account1"
        let conversationId = "conv1"
        let calls = [
            ["id": "call1"], // Missing uri and device
            ["id": "call2", "uri": "uri2", "device": "device2"]
        ]

        let account = AccountModel(withAccountId: accountId)

        // When
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId, calls: calls, account: account)

        // Then
        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let conversationCalls = accountCalls.calls(for: conversationId)
        XCTAssertEqual(conversationCalls.count, 1)
        XCTAssertEqual(conversationCalls[0].id, "call2")
    }

    func testActiveCallsChanged_UpdatesMultipleConversations() {
        // Given
        let accountId = "account1"
        let conversationId1 = "conv1"
        let conversationId2 = "conv2"

        let account = AccountModel(withAccountId: accountId)

        // When
        activeCallsHelper.activeCallsChanged(conversationId: conversationId1, accountId: accountId, calls: [["id": "call1", "uri": "uri1", "device": "device1"]], account: account)
        activeCallsHelper.activeCallsChanged(conversationId: conversationId2, accountId: accountId, calls: [["id": "call2", "uri": "uri2", "device": "device2"]], account: account)

        // Then
        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let calls1 = accountCalls.calls(for: conversationId1)
        let calls2 = accountCalls.calls(for: conversationId2)
        XCTAssertEqual(calls1.count, 1)
        XCTAssertEqual(calls2.count, 1)
        XCTAssertEqual(calls1[0].id, "call1")
        XCTAssertEqual(calls2[0].id, "call2")
    }

    func testActiveCallsChanged_UpdatesMultipleAccounts() {
        // Given
        let accountId1 = "account1"
        let accountId2 = "account2"
        let conversationId = "conv1"

        let account1 = AccountModel(withAccountId: accountId1)
        let account2 = AccountModel(withAccountId: accountId2)

        // When
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId1, calls: [["id": "call1", "uri": "uri1", "device": "device1"]], account: account1)
        activeCallsHelper.activeCallsChanged(conversationId: conversationId, accountId: accountId2, calls: [["id": "call2", "uri": "uri2", "device": "device2"]], account: account2)

        // Then
        let result = activeCallsHelper.activeCalls.value
        let accountCalls1 = result[accountId1]!
        let accountCalls2 = result[accountId2]!
        let calls1 = accountCalls1.calls(for: conversationId)
        let calls2 = accountCalls2.calls(for: conversationId)
        XCTAssertEqual(calls1.count, 1)
        XCTAssertEqual(calls2.count, 1)
        XCTAssertEqual(calls1[0].id, "call1")
        XCTAssertEqual(calls2[0].id, "call2")
    }
}
