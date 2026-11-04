/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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
@testable import Ring

final class ConversationSplitNavigatorTests: XCTestCase {
    private var isExpanded = false
    private var list: UIViewController!
    private var listNavigation: UINavigationController!
    private var placeholder: UIViewController!
    private var navigator: ConversationSplitNavigator!

    override func setUp() {
        super.setUp()
        list = UIViewController()
        listNavigation = UINavigationController(rootViewController: list)
        placeholder = UIViewController()
        navigator = ConversationSplitNavigator(listNavigationController: listNavigation,
                                               placeholder: placeholder,
                                               isExpanded: { [unowned self] in self.isExpanded })
    }

    override func tearDown() {
        navigator = nil
        placeholder = nil
        listNavigation = nil
        list = nil
        super.tearDown()
    }

    private func showConversation(_ controller: UIViewController) {
        navigator.prepareToShowConversation()
        navigator.contentNavigationController.pushViewController(controller, animated: false)
    }

    // MARK: - Compact

    func testCompactShowConversationPushesOntoList() {
        let conversation = UIViewController()

        showConversation(conversation)

        XCTAssertEqual(listNavigation.viewControllers, [list, conversation])
        XCTAssertTrue(navigator.contentNavigationController === listNavigation)
        XCTAssertEqual(navigator.contentControllers, [conversation])
    }

    func testCompactPopToListKeepsOnlyList() {
        showConversation(UIViewController())
        listNavigation.pushViewController(UIViewController(), animated: false)

        navigator.popToList(animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertTrue(navigator.contentControllers.isEmpty)
    }

    // MARK: - Expanded

    func testExpandedShowConversationReplacesDetail() {
        isExpanded = true
        let first = UIViewController()
        let second = UIViewController()

        showConversation(first)
        navigator.detailNavigationController.pushViewController(UIViewController(), animated: false)
        showConversation(second)

        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [second])
        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertTrue(navigator.contentNavigationController === navigator.detailNavigationController)
        XCTAssertEqual(navigator.contentControllers, [second])
    }

    func testExpandedPushReplacesPlaceholder() {
        isExpanded = true
        let screen = UIViewController()

        navigator.contentNavigationController.pushViewController(screen, animated: false)

        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [screen])
    }

    func testExpandedPushStacksOnConversation() {
        isExpanded = true
        let conversation = UIViewController()
        let info = UIViewController()

        showConversation(conversation)
        navigator.contentNavigationController.pushViewController(info, animated: false)

        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [conversation, info])
    }

    func testExpandedPopToListShowsPlaceholder() {
        isExpanded = true
        showConversation(UIViewController())

        navigator.popToList(animated: false)

        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [placeholder])
        XCTAssertTrue(navigator.contentControllers.isEmpty)
    }

    func testExpandedPoppingLastScreenShowsPlaceholder() {
        isExpanded = true
        let conversation = UIViewController()
        showConversation(conversation)

        let popped = navigator.detailNavigationController.popViewController(animated: false)

        XCTAssertTrue(popped === conversation)
        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [placeholder])
    }

    func testExpandedPoppingPlaceholderDoesNothing() {
        isExpanded = true

        let popped = navigator.detailNavigationController.popViewController(animated: false)

        XCTAssertNil(popped)
        XCTAssertEqual(navigator.detailNavigationController.viewControllers, [placeholder])
    }
}
