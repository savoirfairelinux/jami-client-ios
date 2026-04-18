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

final class LinkDeviceVMTests: XCTestCase {

    private static let emptyInput = ""
    private static let nonJamiUri = "https://example.com"
    private static let uriBodyFiller: Character = "a"

    private var accountService: MockAccountsService!
    private var account: AccountModel!
    private var viewModel: LinkDeviceVM!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dBManager = DBManager(profileHepler: ProfileDataHelper(),
                                  conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        accountService = MockAccountsService(withAccountAdapter: AccountAdapter(), dbManager: dBManager)
        account = AccountModel()
        account.id = accountId1
        viewModel = LinkDeviceVM(account: account, accountService: accountService)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        account = nil
        accountService = nil
        try super.tearDownWithError()
    }

    private func validUri(totalLength: Int) -> String {
        let bodyLength = totalLength - LinkDeviceVM.schema.count
        return LinkDeviceVM.schema + String(repeating: Self.uriBodyFiller, count: bodyLength)
    }

    private var anyValidUri: String {
        validUri(totalLength: LinkDeviceVM.validLengths.sorted().first!)
    }

    private var invalidLengthUri: String {
        validUri(totalLength: LinkDeviceVM.validLengths.min()! - 1)
    }

    func testHandleAuthenticationUri_invalidPrefix_setsEntryError() {
        let invalidInputs = [Self.emptyInput, Self.nonJamiUri]

        for input in invalidInputs {
            viewModel = LinkDeviceVM(account: account, accountService: accountService)
            viewModel.handleAuthenticationUri(input)

            XCTAssertEqual(viewModel.entryError, L10n.LinkDevice.wrongEntry, "input: \(input)")
            XCTAssertFalse(viewModel.codeProvided, "input: \(input)")
        }
    }

    func testHandleAuthenticationUri_correctSchemaWrongLength_setsEntryError() {
        viewModel.handleAuthenticationUri(invalidLengthUri)

        XCTAssertEqual(viewModel.entryError, L10n.LinkDevice.wrongEntry)
        XCTAssertFalse(viewModel.codeProvided)
    }

    func testHandleAuthenticationUri_everyValidLength_marksCodeProvided() {
        for length in LinkDeviceVM.validLengths {
            viewModel = LinkDeviceVM(account: account, accountService: accountService)
            accountService.addDeviceCalls.removeAll()

            viewModel.handleAuthenticationUri(validUri(totalLength: length))

            XCTAssertNil(viewModel.entryError, "length: \(length)")
            XCTAssertTrue(viewModel.codeProvided, "length: \(length)")
            XCTAssertEqual(accountService.addDeviceCalls.count, 1, "length: \(length)")
            XCTAssertEqual(accountService.addDeviceCalls.first?.accountId, accountId1, "length: \(length)")
        }
    }

    func testHandleAuthenticationUri_validAfterInvalid_clearsEntryError() {
        viewModel.handleAuthenticationUri(Self.emptyInput)
        XCTAssertEqual(viewModel.entryError, L10n.LinkDevice.wrongEntry)

        viewModel.handleAuthenticationUri(anyValidUri)

        XCTAssertNil(viewModel.entryError)
        XCTAssertTrue(viewModel.codeProvided)
    }

    func testHandleAuthenticationUri_afterCodeProvided_isNoop() {
        viewModel.handleAuthenticationUri(anyValidUri)
        XCTAssertTrue(viewModel.codeProvided)
        XCTAssertEqual(accountService.addDeviceCalls.count, 1)

        viewModel.handleAuthenticationUri(Self.emptyInput)

        XCTAssertNil(viewModel.entryError)
        XCTAssertTrue(viewModel.codeProvided)
        XCTAssertEqual(accountService.addDeviceCalls.count, 1)
    }
}
