//
//  SmartListViewTests.swift
//  RingUITests
//
//  Created by kateryna on 2024-05-28.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import XCTest

final class SmartListViewTests: XCTestCase {

    var app: XCUIApplication!
    var smartListViewPage: SmartListViewPage!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        smartListViewPage = SmartListViewPage(app: app)
    }

    func testOpenAccountsButton() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        XCTAssertTrue(smartListViewPage.openAccountsButton.exists)
        XCTAssertTrue(smartListViewPage.openAccountsButton.isHittable)

        smartListViewPage.openAccountsButton.tap()

        XCTAssertTrue(smartListViewPage.accountListView.waitForExistence(timeout: 5))
    }

    func testMenuButton() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        XCTAssertTrue(smartListViewPage.menuButton.exists)
        XCTAssertTrue(smartListViewPage.menuButton.isHittable)

        smartListViewPage.menuButton.tap()

        XCTAssertTrue(smartListViewPage.overlay.waitForExistence(timeout: 5))
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
    }

    func testContactPicker() throws {
        XCTAssertTrue(smartListViewPage.conversationView.exists)
        let bookButton = smartListViewPage.bookButton

        XCTAssertTrue(bookButton.exists)
        XCTAssertTrue(bookButton.isHittable)

        bookButton.tap()
    }
}
