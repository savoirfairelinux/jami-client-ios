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
@testable import Ring

final class ActiveCallsHelperTests: XCTestCase {
    private var activeCallsHelper: ActiveCallsHelper!

    override func setUp() {
        super.setUp()
        activeCallsHelper = ActiveCallsHelper()
    }

    override func tearDown() {
        activeCallsHelper = nil
        super.tearDown()
    }

    func testActiveCallsChanged_WithValidCalls_UpdatesCallsCorrectly() {
        let accountId = "account1"
        let conversationId = "conv1"
        let calls = [
            ["id": "call1", "uri": "uri1", "device": "device1"],
            ["id": "call2", "uri": "uri2", "device": "device2"]
        ]
        let account = AccountModel(withAccountId: accountId)

        activeCallsHelper.updateActiveCalls(conversationId: conversationId, accountId: accountId, calls: calls, account: account)

        let result = activeCallsHelper.activeCalls.value
        XCTAssertNotNil(result[accountId])
        let accountCalls = result[accountId]!
        let conversationCalls = accountCalls.calls(for: conversationId)
        XCTAssertEqual(conversationCalls.count, 2)
        XCTAssertEqual(conversationCalls[0].id, "call1")
        XCTAssertEqual(conversationCalls[1].id, "call2")
    }

    func testActiveCallsChanged_WithEmptyCalls_ClearsIgnoredCalls() {
        let accountId = "account1"
        let conversationId = "conv1"
        let account = AccountModel(withAccountId: accountId)
        let call = ActiveCall(id: "call1", uri: "uri1", device: "device1", conversationId: conversationId, accountId: accountId, isFromLocalDevice: false)

        activeCallsHelper.ignoreCall(call)
        activeCallsHelper.updateActiveCalls(conversationId: conversationId, calls: [], account: account)

        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let ignoredCalls = accountCalls.ignoredCalls(for: conversationId)
        XCTAssertTrue(ignoredCalls.isEmpty)
    }

    func testIgnoreCall_AddsCallToIgnoredCalls() {
        let accountId = "account1"
        let conversationId = "conv1"
        let call = ActiveCall(id: "call1", uri: "uri1", device: "device1", conversationId: conversationId, accountId: accountId, isFromLocalDevice: false)

        activeCallsHelper.ignoreCall(call)

        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let ignoredCalls = accountCalls.ignoredCalls(for: conversationId)
        XCTAssertEqual(ignoredCalls.count, 1)
        let callId: String = ignoredCalls.first!.id
        XCTAssertEqual(callId, "call1")
    }

    func testActiveCallsChanged_WithInvalidCallData_IgnoresInvalidCalls() {
        let accountId = "account1"
        let conversationId = "conv1"
        let calls = [
            ["id": "call1"], // Missing uri and device
            ["id": "call2", "uri": "uri2", "device": "device2"]
        ]

        let account = AccountModel(withAccountId: accountId)

        activeCallsHelper.updateActiveCalls(conversationId: conversationId, calls: calls, account: account)

        let result = activeCallsHelper.activeCalls.value
        let accountCalls = result[accountId]!
        let conversationCalls = accountCalls.calls(for: conversationId)
        XCTAssertEqual(conversationCalls.count, 1)
        XCTAssertEqual(conversationCalls[0].id, "call2")
    }

    func testActiveCallsChanged_UpdatesMultipleConversations() {
        let accountId = "account1"
        let conversationId1 = "conv1"
        let conversationId2 = "conv2"

        let account = AccountModel(withAccountId: accountId)

        activeCallsHelper.updateActiveCalls(conversationId: conversationId1, calls: [["id": "call1", "uri": "uri1", "device": "device1"]], account: account)
        activeCallsHelper.updateActiveCalls(conversationId: conversationId2, calls: [["id": "call2", "uri": "uri2", "device": "device2"]], account: account)

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
        let accountId1 = "account1"
        let accountId2 = "account2"
        let conversationId = "conv1"

        let account1 = AccountModel(withAccountId: accountId1)
        let account2 = AccountModel(withAccountId: accountId2)

        activeCallsHelper.updateActiveCalls(conversationId: conversationId, calls: [["id": "call1", "uri": "uri1", "device": "device1"]], account: account1)
        activeCallsHelper.updateActiveCalls(conversationId: conversationId, calls: [["id": "call2", "uri": "uri2", "device": "device2"]], account: account2)

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
