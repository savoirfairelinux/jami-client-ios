/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

import XCTest

/**
 A test class designed to validate that the AccountModel helper runs as expected.
 */
class AccountModelHelperTests: XCTestCase {

    /// The account used for the tests.
    var account: AccountModel?

    override func setUp() {
        super.setUp()
        //~ Dummy account
        account = AccountModel(withAccountId: "identifier")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    /**
     Tests that the SIP account type is properly detected.
     */
    func testIsSip() {
        var data = Dictionary<String, String>()
        data[ConfigKey.AccountType.rawValue] = AccountType.SIP.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isAccountSip())

        data[ConfigKey.AccountType.rawValue] = AccountType.Ring.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.details = config

        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isAccountSip())
    }

    /**
     Tests that the Ring account type is properly detected.
     */
    func testIsRing() {
        var data = Dictionary<String, String>()
        data[ConfigKey.AccountType.rawValue] = AccountType.Ring.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isAccountRing())

        data[ConfigKey.AccountType.rawValue] = AccountType.SIP.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.details = config

        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isAccountRing())
    }

    /**
     Tests that the account's enabled state is properly detected.
     */
    func testIsEnabled() {
        var data = Dictionary<String, String>()
        data[ConfigKey.AccountEnable.rawValue] = "true"
        var config = AccountConfigModel(withDetails: data)
        account?.details = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertTrue(helper.isEnabled())

        data[ConfigKey.AccountEnable.rawValue] = "false"
        config = AccountConfigModel(withDetails: data)
        account?.details = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isEnabled())

        data.removeValue(forKey: ConfigKey.AccountEnable.rawValue)
        config = AccountConfigModel(withDetails: data)
        account?.details = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isEnabled())
    }

    /**
     Tests that the account's registration state is properly detected.
     */
    func testRegistrationState() {
        var data = Dictionary<String, String>()
        data[ConfigKey.AccountRegistrationStatus.rawValue] = AccountState.Registered.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertEqual(helper.getRegistrationState(), AccountState.Registered.rawValue)

        data[ConfigKey.AccountRegistrationStatus.rawValue] = AccountState.Error.rawValue
        config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config
        helper = AccountModelHelper(withAccount: account!)
        XCTAssertNotEqual(helper.getRegistrationState(), AccountState.Registered.rawValue)
    }

    /**
     Tests that the account's error state is properly detected.
     */
    func testIsInError() {
        var data = Dictionary<String, String>()
        data[ConfigKey.AccountRegistrationStatus.rawValue] = AccountState.Registered.rawValue
        var config = AccountConfigModel(withDetails: data)
        account?.volatileDetails = config

        var helper = AccountModelHelper(withAccount: account!)
        XCTAssertFalse(helper.isInError());

        data[ConfigKey.AccountRegistrationStatus.rawValue] = AccountState.Error.rawValue
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

        var credentials = Array<Dictionary<String, String>>()
        var credential = Dictionary<String, String>()
        credential[ConfigKey.AccountUsername.rawValue] = username
        credential[ConfigKey.AccountPassword.rawValue] = password
        credential[ConfigKey.AccountRealm.rawValue] = realm
        credentials.append(credential)

        var helper = AccountModelHelper(withAccount: account!)
        var modifiedAccount = helper.setCredentials(credentials)

        XCTAssertEqual(modifiedAccount.credentialDetails.count, 1)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].username, username)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].password, password)
        XCTAssertEqual(modifiedAccount.credentialDetails[0].realm, realm)

        modifiedAccount = helper.setCredentials(nil)
        XCTAssertEqual(modifiedAccount.credentialDetails.count, 0)
    }

}
