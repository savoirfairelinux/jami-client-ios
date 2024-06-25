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

import Embassy
import XCTest

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
        let accountsButton = XCUIApplication().navigationBars
            .buttons[AccessibilityIdentifiers.openAccountsButton]
        accountsButton.tap()
        let addAccount = app.buttons[AccessibilityIdentifiers.addAccountButton]
        waitForElementToAppear(addAccount)
        if addAccount.exists {
            addAccount.tap()
        } else {
            XCTFail("addAccount button did not appear in time")
        }
    }

    func openAccountCreation() {
        openWelcomeViewFromConversation()
        app.scrollViews.otherElements.buttons[AccessibilityIdentifiers.joinJamiButton].tap()

        let createAccountWindow = app.otherElements[AccessibilityIdentifiers.createAccountView]
        waitForElementToAppear(createAccountWindow)
    }

    func enterName(_ name: String) {
        app.textFields[AccessibilityIdentifiers.usernameTextField].tap()

        // Directly insert the not registered name into the text field
        app.textFields[AccessibilityIdentifiers.usernameTextField].typeText(name)
    }

    func testCancelJoinJami() {
        openAccountCreation()

        // Verify the state of the "Cancel" button
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelCreatingAccount]
        XCTAssertTrue(cancelButton.isEnabled, "The Join button is not enabled")
        cancelButton.tap()

        // Verify that account creation view dismissed
        let createAccountWindow = app.otherElements[AccessibilityIdentifiers.createAccountView]
        waitForSeconds(1)
        XCTAssertFalse(createAccountWindow.exists)

        // Verify that welcome view is presented
        let welcomeWindow = app.otherElements[AccessibilityIdentifiers.welcomeWindow]
        XCTAssertTrue(welcomeWindow.exists)
    }

    func testJoinTitle() {
        openAccountCreation()
        let title = app.staticTexts[AccessibilityIdentifiers.createAccountTitle]
        let expectedText = "Join Jami"

        // Check the title of the navigation bar
        XCTAssertEqual(title.label, expectedText, "Navigation title is not correct")
    }

    func testMessageOnValidName() {
        openAccountCreation()

        let nameToRegister = nameServer.getNotRegisteredName()
        enterName(nameToRegister)
        // wait for answer from name server
        waitForSeconds(1)

        // Verify the text
        let label = app.staticTexts[AccessibilityIdentifiers.createAccountErrorLabel]

        let expectedText = "username is available"

        // Check the label's text
        XCTAssertEqual(label.label, expectedText, "Explanation lable is not correct")
    }

    func testErrorMessageOnAlreadyRegisteredName() {
        openAccountCreation()

        let nameToRegister = nameServer.getRegisteredName()
        enterName(nameToRegister)
        // wait for answer from name server
        waitForSeconds(1)

        // Verify the text
        let label = app.staticTexts[AccessibilityIdentifiers.createAccountErrorLabel]

        let expectedText = "username already taken"

        // Check the label's text
        XCTAssertEqual(label.label, expectedText, "Explanation lable is not correct")
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
        XCTAssertFalse(joinButton.isEnabled, "The Join button is enabled")
    }
}
