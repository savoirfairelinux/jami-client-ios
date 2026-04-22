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
import Foundation
@testable import Ring

class MockAccountsService: AccountsService {
    var mockAccountsId: [String]?
    var addDeviceCalls: [(accountId: String, token: String)] = []
    var addDeviceOperationId: UInt32 = 1

    var provideAccountAuthenticationCalls: [(accountId: String, password: String)] = []
    var temporaryAccountId: String = "temp-account-id"

    override func getAccountsId() -> [String]? {
        return mockAccountsId
    }

    override func addDevice(accountId: String, token: String) -> UInt32 {
        addDeviceCalls.append((accountId, token))
        return addDeviceOperationId
    }

    override func provideAccountAuthentication(accountId: String, password: String) {
        provideAccountAuthenticationCalls.append((accountId, password))
    }

    override func createTemporaryAccount() async throws -> String {
        return temporaryAccountId
    }
}
