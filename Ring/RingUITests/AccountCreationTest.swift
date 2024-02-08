/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import Embassy

final class AccountCreationTest: XCTestCase {

    let app = XCUIApplication()
    var nameServer: NameServer!

    override func setUp() {
        super.setUp()
        // Create and start name server
        nameServer = NameServer()
        app.launchEnvironment["SERVER_ADDRESS"] = "\(nameServer.localServer):\(nameServer.port)"
        try! nameServer.start()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        app.launch()
    }

    override func tearDown() {
        nameServer.stop()
    }

    func testAccountCreationWithRegisteredName_NameNotFound_JoinButtonState() {
        // Tap the "Join Jami" button
        app.scrollViews.otherElements.buttons["Join Jami"].tap()

        app.textFields["Enter user name"].tap()

        // Directly insert the not registered name into the text field
        app.textFields["Enter user name"].typeText(nameServer.getNotRegisteredName())

        // Create an expectation with a timeout
        let expectation = XCTestExpectation(description: "Waiting for a name registration answer")
        let result = XCTWaiter.wait(for: [expectation], timeout: 1.0)

        // Ensure that the waiter completed due to the timeout
        XCTAssertEqual(result, .timedOut, "Waiter did not time out")

        // Verify the state of the "Join" button
        let joinButton = app.buttons["Join"]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
    }
}
