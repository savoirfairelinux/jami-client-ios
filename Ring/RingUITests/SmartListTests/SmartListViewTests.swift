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
        // Check menu overly is hidden
        XCTAssertFalse(smartListViewPage.overlay.exists)
        XCTAssertFalse(smartListViewPage.overlay.isHittable)
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
        XCTAssertFalse(smartListViewPage.overlay.exists)
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
}
