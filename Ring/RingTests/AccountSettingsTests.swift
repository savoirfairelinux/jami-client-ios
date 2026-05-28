/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

class AccountSettingsTests: XCTestCase {

    func testIsValidAcceptsInRangeValues() {
        XCTAssertTrue(AccountSettings.isValid("0", in: AccountSettings.publishedPortRange))
        XCTAssertTrue(AccountSettings.isValid("5060", in: AccountSettings.publishedPortRange))
        XCTAssertTrue(AccountSettings.isValid("65535", in: AccountSettings.publishedPortRange))
        XCTAssertTrue(AccountSettings.isValid("60", in: AccountSettings.registrationExpireRange))
        XCTAssertTrue(AccountSettings.isValid("3600", in: AccountSettings.registrationExpireRange))
        XCTAssertTrue(AccountSettings.isValid("604800", in: AccountSettings.registrationExpireRange))
    }

    func testIsValidRejectsOutOfRangeValues() {
        XCTAssertFalse(AccountSettings.isValid("65536", in: AccountSettings.publishedPortRange))
        XCTAssertFalse(AccountSettings.isValid("-1", in: AccountSettings.publishedPortRange))
        XCTAssertFalse(AccountSettings.isValid("59", in: AccountSettings.registrationExpireRange))
        XCTAssertFalse(AccountSettings.isValid("604801", in: AccountSettings.registrationExpireRange))
    }

    func testIsValidRejectsInvalidInput() {
        XCTAssertFalse(AccountSettings.isValid("", in: AccountSettings.publishedPortRange))
        XCTAssertFalse(AccountSettings.isValid("abc", in: AccountSettings.publishedPortRange))
        XCTAssertFalse(AccountSettings.isValid("80a", in: AccountSettings.publishedPortRange))
        XCTAssertFalse(AccountSettings.isValid("99999999999999999999", in: AccountSettings.registrationExpireRange))
    }

    func testIsValidStunServerAcceptsHostAndHostPort() {
        XCTAssertTrue(AccountSettings.isValidStunServer("stun.jami.net"))
        XCTAssertTrue(AccountSettings.isValidStunServer("stun.jami.net:3478"))
        XCTAssertTrue(AccountSettings.isValidStunServer("192.168.1.1:0"))
    }

    func testIsValidStunServerRejectsInvalidPortAndEmpty() {
        XCTAssertFalse(AccountSettings.isValidStunServer(""))
        XCTAssertFalse(AccountSettings.isValidStunServer("stun.jami.net:abc"))
        XCTAssertFalse(AccountSettings.isValidStunServer("stun.jami.net:"))
        XCTAssertFalse(AccountSettings.isValidStunServer("stun.jami.net:99999"))
        XCTAssertFalse(AccountSettings.isValidStunServer(":3478"))
        XCTAssertFalse(AccountSettings.isValidStunServer("2001:db8::1"))
    }
}
