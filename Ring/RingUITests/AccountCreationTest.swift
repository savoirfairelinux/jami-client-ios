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
    var nameServer: MockNameServer!

    override func setUp() {
        super.setUp()
        // Create and start name server
        nameServer = MockNameServer()
        app.launchEnvironment["SERVER_ADDRESS"] = "\(nameServer.localServer):\(nameServer.port)"
        try! nameServer.start()

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        app.launch()
    }

    override func tearDown() {
        nameServer.stop()
    }

    func openWelcomeViewFromConversation() {
        let conversationWindow = app.otherElements[AccessibilityIdentifiers.conversationView]
        if !conversationWindow.exists {
            return
        }
        let accountsButton = XCUIApplication().navigationBars.buttons[AccessibilityIdentifiers.openAccountsButton]
        accountsButton.tap()
        let addAccount = app.toolbars["Toolbar"].buttons[AccessibilityIdentifiers.addAccountButton]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: addAccount, handler: nil)
        waitForExpectations(timeout: 2, handler: nil)
        if addAccount.exists {
            addAccount.tap()
        } else {
            XCTFail("addAccount button did not appear in time")
        }
    }

    func openAccountCreation() {
        openWelcomeViewFromConversation()
        app.scrollViews.otherElements.buttons[AccessibilityIdentifiers.joinJamiButton].tap()
    }

    func enterName(_: String) {
        app.textFields[AccessibilityIdentifiers.usernameTextField].tap()

        // Directly insert the not registered name into the text field
        app.textFields[AccessibilityIdentifiers.usernameTextField].typeText(nameServer.getNotRegisteredName())
    }

    func testJoinButtonEnabledOnValidName() {
        openAccountCreation()

        let nameToRegister = nameServer.getNotRegisteredName()
        enterName(nameToRegister)
        // wait for answer from name server
        waitForSeconds(1)

        // Verify the state of the "Join" button
        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
    }

    func testJoinButtonEnabledOnEmptyName() {
        openAccountCreation()
        // Verify the state of the "Join" button
        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
    }

    func testCreateButtonDisabledOnInvalidName() {
        openAccountCreation()

        let nameToRegister = nameServer.getRegisteredName()
        enterName(nameToRegister)

        waitForSeconds(1)

        // Verify the state of the "Join" button
        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        XCTAssertFalse(joinButton.isEnabled, "The Join button is not enabled")
    }

    func testRegisteredNameOnAccountCreation() {
        openAccountCreation()

        app.textFields[AccessibilityIdentifiers.usernameTextField].tap()

        let nameToRegister = nameServer.getNotRegisteredName()
        enterName(nameToRegister)

        waitForSeconds(1)

        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]

        joinButton.tap()

        let conversationWindow = app.otherElements[AccessibilityIdentifiers.conversationView]
        // wait 30 second for conversatin view to appear after account creation
        waitForElementToAppear(conversationWindow, timeout: 30)

        let menuButton = XCUIApplication().navigationBars.buttons[AccessibilityIdentifiers.openMenuInSmartList]
        waitForElementToAppear(menuButton)
        menuButton.tap()

        let accountSettingsOption = app.buttons["Account Settings"]
        accountSettingsOption.tap()
        let registeredName = app.textViews[AccessibilityIdentifiers.accountRegisteredName]
        waitForElementToAppear(registeredName)

        XCTAssertEqual(registeredName.value as? String, nameToRegister)
    }
}
