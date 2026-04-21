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

/// Drift-detection UI test: drives the app to create a Jami account and seed a
/// known active/banned contact pair, then asserts that the daemon's on-disk
/// contacts file round-trips correctly through the `ContactShallow` msgpack
/// mirror shared with the notification extension. If the daemon ever renames,
/// reorders, or retypes a `jami::Contact` field, the app-side `DriftCheck`
/// publishes a FAIL result and this test fails with the per-field reason.
final class ContactShallowDriftUITest: JamiBaseOneAccountUITest {

    override func setUpWithError() throws {
        try super.setUpWithError()
        app.launchEnvironment[TestEnvironmentConst.seedDriftContacts.rawValue] = "true"
        app.terminate()
        app.launch()
    }

    func testDaemonContactsFileDecodesThroughContactShallow() throws {
        let element = app.descendants(matching: .any)["driftTestResult"]
        XCTAssertTrue(element.waitForExistence(timeout: 30), "drift result element did not appear")
        let result = element.label
        XCTAssertEqual(result, "PASS", "ContactShallow drift check failed: \(result)")
    }
}
