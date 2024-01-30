//
//  RingUITests.swift
//  RingUITests
//
//  Created by Edric on 16-06-23.
//  Copyright © 2016 Savoir-faire Linux. All rights reserved.
//

import XCTest

class RingUITests: XCTestCase {

    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testAccountCreationWithRegisteredName_NameNotFound() {
        let app = XCUIApplication()
        app.launch()

        // Tap the "Join Jami" button
        app.scrollViews.otherElements.buttons["Join Jami"].tap()
        let expectation = XCTestExpectation(description: "Name does not exists")

        // Interact with the keyboard, enter "name"
        app.keys["n"].tap()
        app.keys["a"].tap()
        app.keys["m"].tap()
        app.keys["e"].tap()

        // Tap the "Join" button
        app.buttons["Join"].tap()

        // Handle the notification alert
        app.alerts["“Jami” Would Like to Send You Notifications"].scrollViews.otherElements.buttons["Allow"].tap()
    }

}
