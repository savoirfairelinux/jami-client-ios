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

final class AccountCreationTest: JamiBaseNoAccountUITest {

    private static var isAppLaunched = false

    override func setUpWithError() throws {
        try super.setUpWithError()

        if !AccountCreationTest.isAppLaunched {
            if let serverAddress = ProcessInfo.processInfo.environment["TEST_SERVER_ADDRESS"] {
                app.launchEnvironment["SERVER_ADDRESS"] = serverAddress
            } else {
                app.launchEnvironment["SERVER_ADDRESS"] = "https://ns-test.jami.net"
            }

            app.launch()
            AccountCreationTest.isAppLaunched = true
        }
    }

    func openWelcomeViewFromConversation() {
        let welcomeWindow = app.images[AccessibilityIdentifiers.welcomeWindow]
        if welcomeWindow.exists && welcomeWindow.isHittable {
            return
        }

        let conversationWindow = app.otherElements[SmartListAccessibilityIdentifiers.conversationView]
        if !conversationWindow.exists {
            return
        }
        let accountsButton = XCUIApplication().navigationBars.buttons[SmartListAccessibilityIdentifiers.openAccountsButton]
        accountsButton.tap()

        waitForSeconds(2)

        // Try to find the add account button by identifier first
        let addAccount = app.buttons[SmartListAccessibilityIdentifiers.addAccountButton]

        if addAccount.exists {
            addAccount.tap()
        } else {
            // Fallback to finding by exact label if identifier doesn't work
            let addAccountByLabel = app.buttons[L10n.Smartlist.addAccountButton]
            if addAccountByLabel.exists {
                addAccountByLabel.tap()
            } else {
                // Try by accessibility label
                let addAccountByAccessibilityLabel = app.buttons[L10n.Accessibility.smartListAddAccount]
                if addAccountByAccessibilityLabel.exists {
                    addAccountByAccessibilityLabel.tap()
                } else {
                    XCTFail("addAccount button did not appear in time")
                }
            }
        }
    }

    func openAccountCreation() {
        openWelcomeViewFromConversation()
        app.buttons[AccessibilityIdentifiers.joinJamiButton].tap()

        let createAccountWindow = app.staticTexts[AccessibilityIdentifiers.createAccountTitle]
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
        let welcomeWindow = app.images[AccessibilityIdentifiers.welcomeWindow]
        XCTAssertTrue(welcomeWindow.exists)
    }

    func getRandomName() -> String {
        let randomInt = Int.random(in: 1...100000)

        let nameToRegister = "test\(randomInt)"
        return nameToRegister
    }

    func enterName(_ name: String) {
        let usernameField = app.textFields[AccessibilityIdentifiers.usernameTextField]
        usernameField.tap()

        // Directly insert the not registered name into the text field
        usernameField.typeText(name)
    }

    func testCancelJoinJami() {
        openAccountCreation()

        // Verify the state of the "Cancel" button
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelCreatingAccount]
        XCTAssertTrue(cancelButton.isEnabled, "Cancel button is not enabled")
        cancelButton.tap()

        // Verify that account creation view dismissed
        let createAccountWindow = app.otherElements[AccessibilityIdentifiers.createAccountView]
        waitForSeconds(1)
        XCTAssertFalse(createAccountWindow.exists)

        // Verify that welcome view is presented
        let welcomeWindow = app.images[AccessibilityIdentifiers.welcomeWindow]
        XCTAssertTrue(welcomeWindow.exists)
    }

    func testJoinTitle() {
        openAccountCreation()
        let title = app.staticTexts[AccessibilityIdentifiers.createAccountTitle]
        let expectedText = L10n.CreateAccount.newAccount

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

        let conversationWindow = app.otherElements[SmartListAccessibilityIdentifiers.conversationView]
        waitForSeconds(3)
        handleNotificationAlertIfPresent()
        waitForElementToAppear(conversationWindow, timeout: 10)
        waitForSeconds(2)

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

    func handleNotificationAlertIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        let okButton = springboard.buttons["OK"]

        if allowButton.waitForExistence(timeout: 5) {
            allowButton.tap()
        } else if okButton.waitForExistence(timeout: 5) {
            okButton.tap()
        }
    }
}
