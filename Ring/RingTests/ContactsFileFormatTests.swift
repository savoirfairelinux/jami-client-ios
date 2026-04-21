/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

final class ContactsFileFormatTests: XCTestCase {

    private let activePeer = jamiId1
    private let bannedPeer = jamiId2

    private var accountAdapter: AccountAdapter!
    private var preExistingAccountIds: Set<String> = []
    private var testAccountId: String?

    override func setUpWithError() throws {
        try super.setUpWithError()
        accountAdapter = AccountAdapter()
        preExistingAccountIds = Set((accountAdapter.getAccountList() as? [String]) ?? [])
    }

    override func tearDownWithError() throws {
        if let id = testAccountId {
            accountAdapter.removeAccount(id)
        }
        try super.tearDownWithError()
    }

    func testStoredContactDecodesActiveAndBannedContacts() throws {
        let accountId = try createJamiAccount()
        testAccountId = accountId

        try waitForAccountReady(accountId: accountId)

        let contacts = ContactsAdapter()
        contacts.addContact(withURI: activePeer, accountId: accountId)
        contacts.addContact(withURI: bannedPeer, accountId: accountId)
        contacts.removeContact(withURI: bannedPeer, accountId: accountId, ban: true)

        let decoded = try waitForDecodedContacts(accountId: accountId, expectedCount: 2)
        let active = try XCTUnwrap(decoded.first { $0[ContactsFileKeyURI] as? String == activePeer },
                                   "active contact \(activePeer) missing from decoded file")
        let banned = try XCTUnwrap(decoded.first { $0[ContactsFileKeyURI] as? String == bannedPeer },
                                   "banned contact \(bannedPeer) missing from decoded file")

        XCTAssertGreaterThan(active.int64(ContactsFileKeyAdded), 0, "active.added should be a positive timestamp")
        XCTAssertEqual(active.int64(ContactsFileKeyRemoved), 0, "active.removed should be 0")
        XCTAssertFalse(active.bool(ContactsFileKeyBanned), "active.banned should be false")
        XCTAssertFalse(active.bool(ContactsFileKeyConfirmed), "active.confirmed should be false for a freshly added contact")
        XCTAssertFalse(active.string(ContactsFileKeyConversationId).isEmpty,
                       "active.conversationId should be non-empty (startConversation on addContact)")

        XCTAssertGreaterThan(banned.int64(ContactsFileKeyAdded), 0, "banned.added should be a positive timestamp")
        XCTAssertGreaterThan(banned.int64(ContactsFileKeyRemoved), 0, "banned.removed should be a positive timestamp after ban")
        XCTAssertTrue(banned.bool(ContactsFileKeyBanned), "banned.banned should be true")
        XCTAssertFalse(banned.bool(ContactsFileKeyConfirmed), "banned.confirmed should be false")
        XCTAssertTrue(banned.string(ContactsFileKeyConversationId).isEmpty,
                      "banned.conversationId should be cleared after ban")

        let activeEntries = ContactsFileReader.activeContactURIs(forAccount: accountId)
        let activeURIs = activeEntries.compactMap { $0[FilterKeys.contactId] }
        XCTAssertEqual(activeURIs, [activePeer],
                       "active peer should be the only entry returned to IncomingCallFilter")
    }

    // MARK: - Helpers

    private func createJamiAccount() throws -> String {
        let template = try XCTUnwrap(accountAdapter.getAccountTemplate(AccountType.ring.rawValue) as? [String: String],
                                     "missing account template")
        var details = template
        details[ConfigKey.accountType.rawValue] = AccountType.ring.rawValue
        let accountId = try XCTUnwrap(accountAdapter.addAccount(details as [AnyHashable: Any]),
                                      "addAccount returned nil")
        XCTAssertFalse(preExistingAccountIds.contains(accountId), "test account id collided with an existing account")
        return accountId
    }

    private func waitForAccountReady(accountId: String) throws {
        let initializing = AccountState.initializing.rawValue
        let readyExpectation = expectation(description: "account leaves initializing state")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [accountAdapter] _ in
            let volatile = accountAdapter!.getVolatileAccountDetails(accountId) as? [String: String] ?? [:]
            let status = volatile[ConfigKey.accountRegistrationStatus.rawValue] ?? initializing
            if status != initializing {
                readyExpectation.fulfill()
            }
        }
        defer { timer.invalidate() }
        let result = XCTWaiter().wait(for: [readyExpectation], timeout: 15)
        if result != .completed {
            throw XCTSkip("account \(accountId) did not leave \(initializing) within 15s")
        }
    }

    private func waitForDecodedContacts(accountId: String, expectedCount: Int) throws -> [[String: Any]] {
        var lastDecoded: [[String: Any]] = []
        let contactsExpectation = expectation(description: "contacts file contains \(expectedCount) entries")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let decoded = ContactsFileReader.read(forAccount: accountId)
            if decoded.count >= expectedCount {
                lastDecoded = decoded
                contactsExpectation.fulfill()
            }
        }
        defer { timer.invalidate() }
        let result = XCTWaiter().wait(for: [contactsExpectation], timeout: 10)
        if result != .completed {
            XCTFail("contacts file did not contain \(expectedCount) entries within 10s — addContact was called synchronously, so this is a regression in the contacts file format or write path")
        }
        return lastDecoded
    }
}

private extension Dictionary where Key == String, Value == Any {
    func int64(_ key: String) -> Int64 { (self[key] as? NSNumber)?.int64Value ?? 0 }
    func bool(_ key: String) -> Bool { (self[key] as? NSNumber)?.boolValue ?? false }
    func string(_ key: String) -> String { self[key] as? String ?? "" }
}
