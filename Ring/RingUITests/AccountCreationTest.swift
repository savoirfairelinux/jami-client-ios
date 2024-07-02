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

final class AccountCreationTest: XCTestCase {

    let app = XCUIApplication()

    override class func setUp() {
        super.setUp()

        let app = XCUIApplication()

        if let serverAddress = ProcessInfo.processInfo.environment["TEST_SERVER_ADDRESS"] {
            app.launchEnvironment["SERVER_ADDRESS"] = serverAddress
        } else {
            app.launchEnvironment["SERVER_ADDRESS"] = "https://ns-test.jami.net"
        }
        app.launch()
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func openWelcomeViewFromConversation() {
        let welcomeWindow = app.otherElements[AccessibilityIdentifiers.welcomeWindow]
        if welcomeWindow.exists && welcomeWindow.isHittable {
            return
        }

        let conversationWindow = app.otherElements[AccessibilityIdentifiers.conversationView]

        if !conversationWindow.exists {
            return
        }
        let accountsButton = XCUIApplication().navigationBars.buttons[AccessibilityIdentifiers.openAccountsButton]
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

    func closeAccountCreationView() {
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelCreatingAccount]
        if !cancelButton.exists {
            return
        }
        cancelButton.tap()
        waitForSeconds(2)
        // Verify that welcome view is presented
        let welcomeWindow = app.otherElements[AccessibilityIdentifiers.welcomeWindow]
        XCTAssertTrue(welcomeWindow.exists)
    }

    func getRandomName() -> String {
        let randomInt = Int.random(in: 1...10000)

        let nameToRegister = "test\(randomInt)"
        return nameToRegister
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
        let expectedText = L10n.CreateAccount.createAccountFormTitle

        // Check the title of the navigation bar
        XCTAssertEqual(title.label, expectedText, "Navigation title is not correct")
        closeAccountCreationView()
    }

    func testMessageOnValidName() {
        openAccountCreation()
        let nameToRegister = getRandomName()

        enterName(nameToRegister)
        // wait for answer from name server
        waitForSeconds(1)

        // Verify the text
        let label = app.staticTexts[AccessibilityIdentifiers.createAccountErrorLabel]

        let expectedText = L10n.CreateAccount.usernameValid

        // Check the label's text
        XCTAssertEqual(label.label, expectedText, "Explanation label is not correct")
        closeAccountCreationView()
    }

    func testJoinButtonEnabledOnValidName() {
        openAccountCreation()

        let nameToRegister = getRandomName()
        enterName(nameToRegister)
        // wait for answer from name server
        waitForSeconds(1)

        // Verify the state of the "Join" button
        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
        closeAccountCreationView()
    }

    func testJoinButtonEnabledOnEmptyName() {
        openAccountCreation()
        // Verify the state of the "Join" button
        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        XCTAssertTrue(joinButton.isEnabled, "The Join button is not enabled")
        closeAccountCreationView()
    }

    func testStateOnAlreadyRegisteredName() {
        openAccountCreation()

        // 1 register name
        let name = getRandomName()
        enterName(name)
        // wait for answer from name server
        waitForSeconds(1)

        let joinButton = app.buttons[AccessibilityIdentifiers.joinButton]
        joinButton.tap()

        let conversationWindow = app.otherElements[AccessibilityIdentifiers.conversationView]
        waitForElementToAppear(conversationWindow, timeout: 5)
        waitForSeconds(5)

        // try to create account with registered name
        openAccountCreation()

        enterName(name)
        waitForSeconds(1)

        // Verify the error text
        let label = app.staticTexts[AccessibilityIdentifiers.createAccountErrorLabel]
        let expectedText = L10n.CreateAccount.usernameAlreadyTaken
        XCTAssertEqual(label.label, expectedText, "Explanation label is not correct")

        // Verify the state of the "Join" button
        XCTAssertFalse(joinButton.isEnabled, "The Join button is enabled")
        closeAccountCreationView()
    }
}
