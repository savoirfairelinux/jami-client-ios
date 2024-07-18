/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

final class AccountsServiceTest: XCTestCase {

    let account1 = "1"
    let account2 = "2"
    let account3 = "3"
    let account4 = "4"
    let account5 = "5"

    let dBManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper(),
                              dbConnections: DBContainer())

    var accountService: MockAccountsService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        accountService = MockAccountsService(withAccountAdapter: AccountAdapter(), dbManager: self.dBManager)
    }

    override func tearDownWithError() throws {
        // Perform any necessary cleanup
        accountService = nil
        try super.tearDownWithError()
    }

    private func setupInitialAccounts(initialAccountIds: [String] ) {
        let initialAccounts = initialAccountIds.map { AccountModel(withAccountId: $0) }
        accountService.setAccountList(initialAccounts)
    }

    func testAccountsChanged_RemovesAccountsCorrectly() throws {
        var initialAccountIds: [String] { [account1, account2, account3] }
        var newAccountIds: [String] { [account2, account3] }
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 2)
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account2 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account3 }))
        XCTAssertFalse(accountService.accountList.contains(where: { $0.id == account1 }))
    }

    func testAccountsChanged_AddsAccountsCorrectly() throws {
        let initialAccountIds = [account2, account3]
        let newAccountIds = [account2, account3, account4]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 3)
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account2 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account3 }))
        XCTAssertTrue(accountService.accountList.contains(where: { $0.id == account4 }))
    }

    func testAccountsChanged_NoChanges() throws {
        let initialAccountIds = [account1, account2, account3]
        let newAccountIds = [account1, account2, account3]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = newAccountIds

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 3)
        XCTAssertTrue(accountService.accountList.contains { $0.id == account1 })
        XCTAssertTrue(accountService.accountList.contains { $0.id == account2 })
        XCTAssertTrue(accountService.accountList.contains { $0.id == account3 })
    }

    func testAccountsChanged_AllAccountsRemoved() throws {
        let initialAccountIds = [account1, account2, account3]
        setupInitialAccounts(initialAccountIds: initialAccountIds)
        accountService.mockAccountsId = nil

        accountService.accountsChanged()

        XCTAssertEqual(accountService.accountList.count, 0)
    }

    func testPerformanceExample() throws {
        let largeAccountList = (1...1000).map { AccountModel(withAccountId: "\($0)") }
        accountService.setAccountList(largeAccountList)
        accountService.mockAccountsId = (500...1500).map { "\($0)" }

        measure {
            accountService.accountsChanged()
        }
    }
}
