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

/// Tests for the `AccountSettings` view model.
class AccountSettingsTests: XCTestCase {

    // MARK: - clampedPort
    // `clampedPort` keeps a SIP published port inside the valid TCP/UDP range
    // (0...65535).

    func testValidPortsAreUnchanged() {
        XCTAssertEqual(AccountSettings.clampedPort("0"), "0")
        XCTAssertEqual(AccountSettings.clampedPort("5060"), "5060")
        XCTAssertEqual(AccountSettings.clampedPort("65535"), "65535")
    }

    func testOutOfRangePortsAreClamped() {
        // Above the uint16_t maximum is clamped down to 65535.
        XCTAssertEqual(AccountSettings.clampedPort("65536"), "65535")
        XCTAssertEqual(AccountSettings.clampedPort("99999"), "65535")
        // Negative values are clamped up to 0.
        XCTAssertEqual(AccountSettings.clampedPort("-1"), "0")
    }

    func testNonNumericInputReturnsNil() {
        XCTAssertNil(AccountSettings.clampedPort(""))
        XCTAssertNil(AccountSettings.clampedPort("abc"))
        XCTAssertNil(AccountSettings.clampedPort("80a"))
    }
}
