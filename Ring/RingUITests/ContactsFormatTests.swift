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

/// Verifies that the daemon's on-disk contacts file still decodes correctly
/// through the `ContactShallow` msgpack mirror shared with the notification
/// extension. The app seeds a known active/banned contact pair during launch
/// (gated by the `seedTestContacts` launch environment flag), runs
/// `ContactsFormatCheck` against the resulting file, and publishes the result
/// on a hidden accessibility element. If the daemon ever renames, reorders, or
/// retypes a `jami::Contact` field, the check returns a specific FAIL reason
/// and this test surfaces it in the assertion message.
final class ContactsFormatTests: JamiBaseOneAccountUITest {

    override func setUpWithError() throws {
        try super.setUpWithError()
        app.launchEnvironment[TestEnvironmentConst.seedTestContacts.rawValue] = "true"
        app.terminate()
        app.launch()
    }

    func testContactsFileDecodesThroughContactShallow() throws {
        let element = app.descendants(matching: .any)[TestSupportAccessibilityIdentifiers.contactsFormatCheckResult]
        XCTAssertTrue(element.waitForExistence(timeout: 30), "contacts format check element did not appear")
        let result = element.label
        XCTAssertEqual(result, "PASS", "ContactShallow format check failed: \(result)")
    }
}
