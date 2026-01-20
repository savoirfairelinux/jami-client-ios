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
    var menuButton: XCUIElement { app.images[SmartListAccessibilityIdentifiers.openMenuInSmartList] }
    var bookButton: XCUIElement { app.buttons[SmartListAccessibilityIdentifiers.bookButton] }
    var contactPicker: XCUIElement { app.buttons[SmartListAccessibilityIdentifiers.contactPicker] }
}
