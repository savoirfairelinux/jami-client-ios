/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

@testable import Ring
import XCTest

/**
 A test class designed to validate that the AccountModel helper runs as expected.
 */
class AccountModelHelperTests: XCTestCase {
    /// The account used for the tests.
    var account: AccountModel?

    override func setUp() {
        super.setUp()
        // ~ Dummy account
        account = AccountModel(withAccountId: "identifier")
    }

    /**
     Tests that the SIP account type is properly detected.
     */
    func testIsSip() {
        var data = [String: String]()
        data[ConfigKey.accountType.rawValue] = AccountType.sip.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isAccountSip())

        data[ConfigKey.accountType.rawValue] = AccountType.ring.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.details = config

        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isAccountSip())
    }

    /**
     Tests that the Ring account type is properly detected.
     */
    func testIsRing() {
        var data = [String: String]()
        data[ConfigKey.accountType.rawValue] = AccountType.ring.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isAccountRing())

        data[ConfigKey.accountType.rawValue] = AccountType.sip.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.details = config

        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isAccountRing())
    }

    /**
     Tests that the account's enabled state is properly detected.
     */
    func testIsEnabled() {
        var data = [String: String]()
        data[ConfigKey.accountEnable.rawValue] = "true"
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isEnabled())

        data[ConfigKey.accountEnable.rawValue] = "false"
        config = AccountConfigModel(withDetails: data)
        account?.details = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isEnabled())

        data.removeValue(forKey: ConfigKey.accountEnable.rawValue)
        config = AccountConfigModel(withDetails: data)
        account?.details = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isEnabled())
    }

    /**
     Tests that the account's registration state is properly detected.
     */
    func testRegistrationState() {
        var data = [String: String]()
        data[ConfigKey.accountRegistrationStatus.rawValue] = AccountState.registered.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertEqual(helper.getRegistrationState(), AccountState.registered.rawValue)

        data[ConfigKey.accountRegistrationStatus.rawValue] = AccountState.error.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertNotEqual(helper.getRegistrationState(), AccountState.registered.rawValue)
    }

    /**
     Tests that the account's error state is properly detected.
     */
    func testIsInError() {
        var data = [String: String]()
        data[ConfigKey.accountRegistrationStatus.rawValue] = AccountState.registered.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isInError())

        data[ConfigKey.accountRegistrationStatus.rawValue] = AccountState.error.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isInError())
    }

    /**
     Tests that the account's credentials are properly inserted and retrieved.
     */
    func testCredentials() {
        let username = "username"
        let password = "password"
        let realm = "realm"

        var credentials = [[String: String]]()
        var credential = [String: String]()
        credential[ConfigKey.accountUsername.rawValue] = username
        credential[ConfigKey.accountPassword.rawValue] = password
        credential[ConfigKey.accountRealm.rawValue] = realm
        credentials.append(credential)

        var helper = AccountModelHelper(withAccount: account!)
        var modifiedAccount = helper.setCredentials(credentials)

        XCTAssertEqual(modifiedAccount.credentialDetails.count, 1)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].username, username)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].password, password)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].accountRealm, realm)

        modifiedAccount = helper.setCredentials(nil)
        XCTAssertEqual(modifiedAccount.credentialDetails.count, 0)
    }
}
