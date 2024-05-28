//
//  SmartListViewPage.swift
//  RingUITests
//
//  Created by kateryna on 2024-05-28.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import Foundation
import XCTest

class SmartListViewPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var openAccountsButton: XCUIElement { app.buttons[SmartListAccessibilityIdentifiers.openAccountsButton] }
    var conversationView: XCUIElement { app.otherElements[SmartListAccessibilityIdentifiers.conversationView] }
    var backgroundCover: XCUIElement { app.otherElements[SmartListAccessibilityIdentifiers.backgroundCover] }
    var accountListView: XCUIElement { app.otherElements[SmartListAccessibilityIdentifiers.accountListView] }
    var menuButton: XCUIElement { app.buttons[SmartListAccessibilityIdentifiers.openMenuInSmartList] }
    var overlay: XCUIElement { app.otherElements[SmartListAccessibilityIdentifiers.overlay] }
    var bookButton: XCUIElement { app.buttons[SmartListAccessibilityIdentifiers.bookButton] }
}
