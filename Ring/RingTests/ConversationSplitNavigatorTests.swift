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
import RxSwift
@testable import Ring

final class ConversationSplitNavigatorTests: XCTestCase {
    private var isExpanded = false
    private var list: UIViewController!
    private var listNavigation: UINavigationController!
    private var placeholders = [UIViewController]()
    private var navigator: ConversationSplitNavigator!
    private var disposeBag = DisposeBag()

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
        disposeBag = DisposeBag()
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

    private func returnToList() {
        listNavigation.setViewControllers([list], animated: false)
        navigator.navigationController(listNavigation, didShow: list, animated: false)
    }

    func testStartsWithListAndPlaceholder() {
        XCTAssertTrue(navigator.rootViewController === navigator.splitViewController)
        XCTAssertEqual(navigator.splitViewController.style, .doubleColumn)
        XCTAssertTrue(navigator.splitViewController.viewController(for: .primary) === listNavigation)
        XCTAssertEqual(placeholders.count, 1)
        XCTAssertEqual(detailControllers, placeholders)
        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertNil(navigator.shownDetail)
    }

    // MARK: - Routing

    func testCompactShowInDetailPushesOntoList() {
        let conversation = UIViewController()

        navigator.showInDetail(conversation, animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list, conversation])
        XCTAssertTrue(navigator.shownDetail === conversation)
        XCTAssertTrue(navigator.detailStack === listNavigation)
    }

    func testExpandedShowInDetailReplacesDetailColumn() {
        isExpanded = true
        let first = UIViewController()
        let second = UIViewController()

        navigator.showInDetail(first, animated: false)
        navigator.pushOntoDetail(UIViewController(), animated: false)
        navigator.showInDetail(second, animated: false)

        XCTAssertEqual(detailControllers, [second])
        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertTrue(navigator.shownDetail === second)
        XCTAssertFalse(navigator.isShowingPlaceholder)
    }

    func testPushOntoDetailStacksOnShownDetail() {
        isExpanded = true
        let conversation = UIViewController()
        let info = UIViewController()
        navigator.showInDetail(conversation, animated: false)

        navigator.pushOntoDetail(info, animated: false)

        XCTAssertEqual(detailControllers, [conversation, info])
        XCTAssertTrue(navigator.shownDetail === conversation)
    }

    func testExpandedPopToListShowsPlaceholder() {
        isExpanded = true
        navigator.showInDetail(UIViewController(), animated: false)

        navigator.popToList(animated: false)

        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertNil(navigator.shownDetail)
    }

    func testCompactPopToListKeepsOnlyList() {
        navigator.showInDetail(UIViewController(), animated: false)

        navigator.popToList(animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertNil(navigator.shownDetail)
    }

    func testShownDetailChangesAreReported() {
        var changes = 0
        navigator.shownDetailChanged
            .subscribe(onNext: { changes += 1 })
            .disposed(by: disposeBag)

        navigator.showInDetail(UIViewController(), animated: false)
        navigator.popToList(animated: false)

        XCTAssertEqual(changes, 2)
    }

    func testReturningToListClosesShownDetail() {
        navigator.showInDetail(UIViewController(), animated: false)

        returnToList()

        XCTAssertNil(navigator.shownDetail)
        XCTAssertTrue(navigator.isShowingPlaceholder)
    }

    // MARK: - Reveal

    func testRevealPopsBackToShownDetail() {
        let conversation = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        navigator.pushOntoDetail(UIViewController(), animated: false)

        XCTAssertTrue(navigator.reveal(conversation, animated: false))

        XCTAssertEqual(listNavigation.viewControllers, [list, conversation])
    }

    func testRevealRejectsControllerNotOnScreen() {
        XCTAssertFalse(navigator.reveal(UIViewController(), animated: false))
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

    func testPhoneShowInDetailPushesOntoList() {
        navigator = makePhoneNavigator()
        let first = UIViewController()
        let second = UIViewController()

        navigator.showInDetail(first, animated: false)
        navigator.showInDetail(second, animated: false)

        XCTAssertEqual(listNavigation.viewControllers, [list, first, second])
        XCTAssertTrue(navigator.detailStack === listNavigation)
        XCTAssertTrue(navigator.shownDetail === second)
    }

    func testPhoneReturningToListClosesShownDetail() {
        navigator = makePhoneNavigator()
        navigator.showInDetail(UIViewController(), animated: false)

        returnToList()

        XCTAssertNil(navigator.shownDetail)
        XCTAssertTrue(placeholders.isEmpty)
    }

    // MARK: - Collapse

    func testCollapsingWithoutShownDetailShowsList() {
        XCTAssertEqual(topColumnForCollapsing(), .primary)
    }

    func testCollapsingWithShownDetailKeepsDetailOnTop() {
        isExpanded = true
        navigator.showInDetail(UIViewController(), animated: false)

        XCTAssertEqual(topColumnForCollapsing(), .secondary)
    }

    // MARK: - Expand

    private func expand() {
        isExpanded = true
        _ = navigator.splitViewController(navigator.splitViewController,
                                          displayModeForExpandingToProposedDisplayMode: .oneBesideSecondary)
        navigator.splitViewControllerDidExpand(navigator.splitViewController)
    }

    func testExpandingMovesListDetailToDetailColumn() {
        let conversation = UIViewController()
        let info = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        navigator.pushOntoDetail(info, animated: false)

        expand()

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertEqual(detailControllers, [conversation, info])
        XCTAssertTrue(navigator.shownDetail === conversation)
    }

    func testListShownDuringExpansionKeepsShownDetail() {
        let conversation = UIViewController()
        navigator.showInDetail(conversation, animated: false)

        _ = navigator.splitViewController(navigator.splitViewController,
                                          displayModeForExpandingToProposedDisplayMode: .oneBesideSecondary)
        navigator.navigationController(listNavigation, didShow: list, animated: false)
        isExpanded = true
        navigator.splitViewControllerDidExpand(navigator.splitViewController)

        XCTAssertTrue(navigator.shownDetail === conversation)
        XCTAssertEqual(detailControllers, [conversation])
    }

    func testExpandingAfterReturningToListShowsPlaceholder() {
        navigator.showInDetail(UIViewController(), animated: false)
        returnToList()

        expand()

        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertNil(navigator.shownDetail)
    }

    func testExpandingWithEmptyDetailShowsPlaceholder() {
        navigator.detailNavigationController?.setViewControllers([], animated: false)

        expand()

        XCTAssertTrue(navigator.isShowingPlaceholder)
    }
}

private final class SizeClassHost: UIViewController {
    func setCompact(_ compact: Bool, for child: UIViewController) {
        setOverrideTraitCollection(UITraitCollection(horizontalSizeClass: compact ? .compact : .regular),
                                   forChildViewController: child)
    }
}

final class ConversationSplitNavigatorTransitionTests: XCTestCase {
    private var window: UIWindow!
    private var host: SizeClassHost!
    private var list: UIViewController!
    private var listNavigation: UINavigationController!
    private var navigator: ConversationSplitNavigator!

    override func setUp() {
        super.setUp()
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        host = SizeClassHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        list = UIViewController()
        listNavigation = UINavigationController(rootViewController: list)
        navigator = ConversationSplitNavigator(listNavigationController: listNavigation,
                                               makePlaceholder: { UIViewController() },
                                               usesSplitView: true)
        let split = navigator.splitViewController
        host.addChildViewController(split)
        split.view.frame = host.view.bounds
        split.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.addSubview(split.view)
        split.didMove(toParentViewController: host)
        setCompact(false)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        host = nil
        navigator = nil
        listNavigation = nil
        list = nil
        super.tearDown()
    }

    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func setCompact(_ compact: Bool) {
        host.setCompact(compact, for: navigator.splitViewController)
        settle()
    }

    private var detailControllers: [UIViewController] {
        return navigator.detailNavigationController?.viewControllers ?? []
    }

    func testDetailSurvivesNarrowingAndWidening() {
        let conversation = UIViewController()
        let info = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        navigator.pushOntoDetail(info, animated: false)
        settle()

        setCompact(true)
        XCTAssertTrue(navigator.shownDetail === conversation)
        setCompact(false)

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertEqual(detailControllers, [conversation, info])
        XCTAssertTrue(navigator.shownDetail === conversation)
    }

    func testScreensOpenedWhileNarrowMoveToDetailOnWidening() {
        setCompact(true)
        let conversation = UIViewController()
        let info = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        navigator.pushOntoDetail(info, animated: false)
        settle()

        setCompact(false)

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertEqual(detailControllers, [conversation, info])
        XCTAssertTrue(navigator.shownDetail === conversation)
    }

    func testBackToListWhileNarrowShowsPlaceholderOnWidening() {
        navigator.showInDetail(UIViewController(), animated: false)
        settle()
        setCompact(true)

        listNavigation.popToRootViewController(animated: false)
        settle()
        XCTAssertNil(navigator.shownDetail)
        setCompact(false)

        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertEqual(listNavigation.viewControllers, [list])
    }

    func testNarrowingWithPlaceholderShowsOnlyList() {
        setCompact(true)

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertNil(navigator.shownDetail)
    }

    func testRevealWhileNarrow() {
        let conversation = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        navigator.pushOntoDetail(UIViewController(), animated: false)
        settle()
        setCompact(true)

        XCTAssertTrue(navigator.reveal(conversation, animated: false))
        settle()

        XCTAssertTrue(conversation.navigationController?.topViewController === conversation)
    }

    func testPopToListWhileNarrowShowsPlaceholderOnWidening() {
        navigator.showInDetail(UIViewController(), animated: false)
        settle()
        setCompact(true)

        navigator.popToList(animated: false)
        settle()
        setCompact(false)

        XCTAssertTrue(navigator.isShowingPlaceholder)
        XCTAssertNil(navigator.shownDetail)
        XCTAssertEqual(listNavigation.viewControllers, [list])
    }

    func testRepeatedResizesKeepDetail() {
        let conversation = UIViewController()
        navigator.showInDetail(conversation, animated: false)
        settle()

        for _ in 1...3 {
            setCompact(true)
            setCompact(false)
        }

        XCTAssertEqual(listNavigation.viewControllers, [list])
        XCTAssertEqual(detailControllers, [conversation])
        XCTAssertTrue(navigator.shownDetail === conversation)
    }
}
