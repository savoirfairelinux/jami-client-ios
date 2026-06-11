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

        // Return to the smart list so the shared app instance stays clean for other tests.
        swarmNav.buttons["Cancel"].firstMatch.tap()
        _ = smartListViewPage.conversationView.waitForExistence(timeout: 10)
    }
}
