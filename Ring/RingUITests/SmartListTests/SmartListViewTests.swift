/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

final class SmartListViewTests: JamiBaseOneAccountUITest {

    var smartListViewPage: SmartListViewPage!

    private static var isAppLaunched = false

    override func setUpWithError() throws {
        try super.setUpWithError()

        if !SmartListViewTests.isAppLaunched {
            app.launch()
            SmartListViewTests.isAppLaunched = true
        }
        smartListViewPage = SmartListViewPage(app: app)
    }

    func testInitialState() {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        // Check that the search bar is exists
        XCTAssertTrue(app.searchFields.element.exists)
        // Check that account list is hidden
        XCTAssertFalse(smartListViewPage.accountListView.exists)
    }

    func testOpenAccountsButton() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        XCTAssertTrue(smartListViewPage.openAccountsButton.exists)
        XCTAssertTrue(smartListViewPage.openAccountsButton.isHittable)

        smartListViewPage.openAccountsButton.tap()

        XCTAssertTrue(smartListViewPage.accountListView.waitForExistence(timeout: 5))
        // Tap again to close the account list
        smartListViewPage.openAccountsButton.tap()

        // Verify that the account list disappears
        XCTAssertFalse(smartListViewPage.accountListView.exists)
    }

    func testMenuButton() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        let menuButton = smartListViewPage.menuButton
        XCTAssertTrue(menuButton.exists)
        XCTAssertTrue(menuButton.isHittable)

        menuButton.tap()

        let settings = app.collectionViews.buttons[L10n.AccountPage.settingsHeader]

        waitForElementToAppear(settings)

        XCTAssertTrue(settings.exists)

        // Tap outside the menu to dismiss it
        let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
        waitForSeconds(1)
    }

    func testBackgroundCoverTap() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        smartListViewPage.openAccountsButton.tap()

        XCTAssertTrue(smartListViewPage.backgroundCover.exists)

        smartListViewPage.backgroundCover.tap()

        XCTAssertFalse(smartListViewPage.accountListView.exists)
    }

    func testActivateSearchBar() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        let searchField = app.searchFields[SmartListAccessibilityIdentifiers.searchBarTextField]

        XCTAssertTrue(searchField.exists)

        searchField.tap()

        let cancelButton = app.buttons["Cancel"]
        cancelButton.tap()
    }

    // Regression test for the iPad/iOS 26 bug where tapping a compose shortcut while
    // the (empty) search was active only dismissed the search instead of opening the
    // target screen. The compose content is now hosted in the search results controller.
    func testComposeNewGroupOpens() throws {
        XCTAssertTrue(smartListViewPage.conversationView.waitForExistence(timeout: 10))

        // Restore the smart list even if an assertion below fails, so the shared app
        // instance stays clean for the other tests in this class.
        addTeardownBlock { [app] in
            let navCancel = app.navigationBars.buttons["Cancel"].firstMatch
            if navCancel.exists { navCancel.tap() }
            let searchCancel = app.buttons["Cancel"]
            if searchCancel.exists { searchCancel.tap() }
        }

        // Activate compose via the pencil button (the previously failing path).
        let compose = app.buttons[SmartListAccessibilityIdentifiers.composeButton]
        XCTAssertTrue(compose.waitForExistence(timeout: 10))
        compose.tap()

        let newGroup = app.otherElements[SmartListAccessibilityIdentifiers.newGroupButton]
        XCTAssertTrue(newGroup.waitForExistence(timeout: 15), "New group option should appear")
        XCTAssertTrue(newGroup.isHittable, "New group option should be tappable")
        newGroup.tap()

        let swarmNav = app.navigationBars[L10n.Swarm.selectContacts]
        XCTAssertTrue(swarmNav.waitForExistence(timeout: 10), "Swarm creation should open after tapping New group")

        // Canceling creates no conversation, so the search stays active; dismiss it too.
        swarmNav.buttons["Cancel"].firstMatch.tap()
        let searchCancel = app.buttons["Cancel"]
        if searchCancel.waitForExistence(timeout: 10) {
            searchCancel.tap()
        }
        XCTAssertTrue(smartListViewPage.conversationView.waitForExistence(timeout: 10),
                      "Smart list should be restored after dismissing search")
    }

    func testSearchDismissedAfterCreatingGroup() throws {
        waitForElementToAppear(smartListViewPage.conversationView, timeout: 10)

        addTeardownBlock { [app] in
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists && back.isHittable { back.tap() }
            let searchCancel = app.buttons["Cancel"]
            if searchCancel.exists { searchCancel.tap() }
        }

        let compose = app.buttons[SmartListAccessibilityIdentifiers.composeButton]
        XCTAssertTrue(compose.waitForExistence(timeout: 10))
        compose.tap()

        let newGroup = app.otherElements[SmartListAccessibilityIdentifiers.newGroupButton]
        XCTAssertTrue(newGroup.waitForExistence(timeout: 15), "New group option should appear")
        newGroup.tap()

        let swarmNav = app.navigationBars[L10n.Swarm.selectContacts]
        XCTAssertTrue(swarmNav.waitForExistence(timeout: 10), "Swarm creation should open")
        let createButton = swarmNav.buttons[L10n.Global.create]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create button should exist")
        createButton.tap()

        // Creating the group may open the new conversation; return to the smart list if so.
        let messageField = app.textViews[L10n.Accessibility.conversationComposeMessage].firstMatch
        if messageField.waitForExistence(timeout: 10) {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.waitForExistence(timeout: 10) { back.tap() }
        }

        waitForElementToAppear(smartListViewPage.conversationView, timeout: 10)
        let cancelButton = app.buttons["Cancel"]
        let cancelGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancelButton)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelGone], timeout: 10), .completed,
                       "Search must be dismissed after creating a group")
    }

    func testSearchDoesNotReappearAfterPromotingTemporaryConversation() throws {
        waitForElementToAppear(smartListViewPage.conversationView, timeout: 10)

        let jamiId = "0000000000000000000000000000000000000001"

        addTeardownBlock { [app] in
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists && back.isHittable { back.tap() }
            let searchCancel = app.buttons["Cancel"]
            if searchCancel.exists { searchCancel.tap() }
        }

        let searchField = app.searchFields[SmartListAccessibilityIdentifiers.searchBarTextField]
        waitForElementToAppear(searchField, timeout: 10)
        searchField.tap()
        searchField.typeText(jamiId)

        let tempRow = app.descendants(matching: .any)[SmartListAccessibilityIdentifiers.temporaryConversationRow]
        waitForElementToAppear(tempRow, timeout: 10)
        tempRow.tap()

        let sendInvitation = app.buttons[ConversationAccessibilityIdentifiers.sendInvitationButton]
        waitForElementToAppear(sendInvitation, timeout: 10)
        sendInvitation.tap()

        let back = app.navigationBars.buttons.element(boundBy: 0)
        waitForElementToAppear(back, timeout: 10)
        back.tap()

        waitForElementToAppear(smartListViewPage.conversationView, timeout: 10)
        // Promotion completes asynchronously, so wait for the Cancel button to disappear.
        let cancelButton = app.buttons["Cancel"]
        let cancelGone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancelButton)
        XCTAssertEqual(XCTWaiter.wait(for: [cancelGone], timeout: 10), .completed,
                       "Search must not still be active after promoting a temporary conversation")
    }
}
