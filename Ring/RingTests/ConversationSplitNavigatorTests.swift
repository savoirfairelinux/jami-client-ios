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
    private var placeholders = [UIViewController]()
    private var navigator: ConversationSplitNavigator!

    override func setUp() {
        super.setUp()
        list = UIViewController()
        listNavigation = UINavigationController(rootViewController: list)
        navigator = makeNavigator(usesSplitView: true)
    }

    private func makeNavigator(usesSplitView: Bool) -> ConversationSplitNavigator {
        return ConversationSplitNavigator(listNavigationController: listNavigation,
                                          makePlaceholder: { [unowned self] in
                                            let placeholder = UIViewController()
                                            self.placeholders.append(placeholder)
                                            return placeholder
                                          },
                                          usesSplitView: usesSplitView,
                                          isExpanded: { [unowned self] in self.isExpanded })
    }

    override func tearDown() {
        navigator = nil
        placeholders = []
        listNavigation = nil
        list = nil
        super.tearDown()
    }

    private var detailControllers: [UIViewController] {
        return navigator.detailNavigationController?.viewControllers ?? []
    }

    private func topColumnForCollapsing() -> UISplitViewController.Column {
        return navigator.splitViewController(navigator.splitViewController,
                                             topColumnForCollapsingToProposedTopColumn: .secondary)
    }

    func testStartsWithListAndPlaceholder() {
        XCTAssertTrue(navigator.rootViewController === navigator.splitViewController)
        XCTAssertEqual(navigator.splitViewController.style, .doubleColumn)
        XCTAssertTrue(navigator.splitViewController.viewController(for: .primary) === listNavigation)
        XCTAssertEqual(placeholders.count, 1)
        XCTAssertEqual(detailControllers, placeholders)
        XCTAssertTrue(navigator.isShowingPlaceholder)
    }

    // MARK: - Routing

    func testCompactContentStackIsList() {
        XCTAssertTrue(navigator.contentNavigationController === listNavigation)
        XCTAssertNil(navigator.selectedController)
    }

    func testExpandedShowDetailReplacesDetailColumn() {
        isExpanded = true
        let first = UIViewController()
        let second = UIViewController()

        navigator.showDetail(first, animated: false)
        navigator.contentNavigationController.pushViewController(UIViewController(), animated: false)
        navigator.showDetail(second, animated: false)

        XCTAssertEqual(detailControllers, [second])
        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertTrue(navigator.contentNavigationController === navigator.detailNavigationController)
        XCTAssertFalse(navigator.isShowingPlaceholder)
    }

    func testExpandedSelectedControllerIsDetailRoot() {
        isExpanded = true
        let conversation = UIViewController()
        navigator.showDetail(conversation, animated: false)
        navigator.contentNavigationController.pushViewController(UIViewController(), animated: false)

        XCTAssertTrue(navigator.selectedController === conversation)
    }

    func testExpandedPlaceholderIsNotSelected() {
        isExpanded = true

        XCTAssertNil(navigator.selectedController)
    }

    func testExpandedPopToListShowsPlaceholder() {
        isExpanded = true
        navigator.showDetail(UIViewController(), animated: false)

        navigator.popToList(animated: false)

        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertNil(navigator.selectedController)
    }

    func testCompactPopToListKeepsOnlyList() {
        listNavigation.pushViewController(UIViewController(), animated: false)

        navigator.popToList(animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list])
    }

    func testShowDetailAndPopToListNotifyDetailChange() {
        isExpanded = true
        var changes = 0
        navigator.onDetailChange = { changes += 1 }

        navigator.showDetail(UIViewController(), animated: false)
        navigator.popToList(animated: false)

        XCTAssertEqual(changes, 2)
    }

    // MARK: - iPhone

    private func makePhoneNavigator() -> ConversationSplitNavigator {
        navigator = nil
        placeholders = []
        list = UIViewController()
        listNavigation = UINavigationController(rootViewController: list)
        return makeNavigator(usesSplitView: false)
    }

    func testPhoneInstallsListStackWithoutSplitView() {
        navigator = makePhoneNavigator()
        isExpanded = true

        XCTAssertTrue(navigator.rootViewController === listNavigation)
        XCTAssertNil(navigator.splitViewController.viewController(for: .primary))
        XCTAssertTrue(placeholders.isEmpty)
        XCTAssertFalse(navigator.isExpanded)
    }

    func testPhoneShowDetailPushesOntoList() {
        navigator = makePhoneNavigator()
        let first = UIViewController()
        let second = UIViewController()

        navigator.showDetail(first, animated: false)
        navigator.showDetail(second, animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list, first, second])
        XCTAssertTrue(navigator.contentNavigationController === listNavigation)
        XCTAssertNil(navigator.selectedController)
    }

    // MARK: - Collapse and expand

    func testCollapsingWithPlaceholderShowsList() {
        XCTAssertEqual(topColumnForCollapsing(), .primary)
    }

    func testCollapsingWithDetailKeepsDetailOnTop() {
        isExpanded = true
        navigator.showDetail(UIViewController(), animated: false)

        XCTAssertEqual(topColumnForCollapsing(), .secondary)
    }

    func testExpandingWithEmptyDetailShowsPlaceholder() {
        navigator.detailNavigationController?.setViewControllers([], animated: false)

        navigator.splitViewControllerDidExpand(navigator.splitViewController)

        XCTAssertTrue(navigator.isShowingPlaceholder)
    }
}
