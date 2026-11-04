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

import UIKit

/// Detail column of the conversations split view. Shows a placeholder
/// whenever nothing else is on its stack.
final class DetailNavigationController: UINavigationController {
    let placeholder: UIViewController

    init(placeholder: UIViewController) {
        self.placeholder = placeholder
        super.init(nibName: nil, bundle: nil)
        setViewControllers([placeholder], animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isShowingPlaceholder: Bool {
        return viewControllers.isEmpty || viewControllers == [placeholder]
    }

    /// The stack without the placeholder.
    var contentControllers: [UIViewController] {
        return viewControllers.filter { $0 !== placeholder }
    }

    func showPlaceholder() {
        guard !isShowingPlaceholder else { return }
        setViewControllers([placeholder], animated: false)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if isShowingPlaceholder {
            setViewControllers([viewController], animated: false)
        } else {
            super.pushViewController(viewController, animated: animated)
        }
    }

    override func show(_ vc: UIViewController, sender: Any?) {
        pushViewController(vc, animated: true)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        guard viewControllers.count == 1, !isShowingPlaceholder else {
            return super.popViewController(animated: animated)
        }
        let popped = viewControllers.first
        showPlaceholder()
        return popped
    }
}

/// Lays out the smart list and the open conversation side by side when the
/// window is wide enough. In compact width the split view collapses and
/// everything is stacked on the list's navigation controller, as on iPhone.
final class ConversationSplitNavigator: NSObject, UISplitViewControllerDelegate, UINavigationControllerDelegate {
    let splitViewController = UISplitViewController()
    let listNavigationController: UINavigationController
    let detailNavigationController: DetailNavigationController
    private let isExpandedOverride: (() -> Bool)?

    /// Called when the screen at the root of the detail column may have changed.
    var onDetailChange: (() -> Void)?

    init(listNavigationController: UINavigationController,
         placeholder: UIViewController,
         isExpanded: (() -> Bool)? = nil) {
        self.listNavigationController = listNavigationController
        self.detailNavigationController = DetailNavigationController(placeholder: placeholder)
        self.isExpandedOverride = isExpanded
        super.init()
        splitViewController.viewControllers = [listNavigationController, detailNavigationController]
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.presentsWithGesture = false
        splitViewController.delegate = self
        detailNavigationController.delegate = self
    }

    /// Whether the list and the detail column are on screen side by side.
    var isExpanded: Bool {
        if let isExpandedOverride = isExpandedOverride {
            return isExpandedOverride()
        }
        return UIDevice.current.userInterfaceIdiom == .pad && !splitViewController.isCollapsed
    }

    /// The stack that screens opened from the list go onto.
    var contentNavigationController: UINavigationController {
        return isExpanded ? detailNavigationController : listNavigationController
    }

    /// The screens opened from the list, without the list itself.
    var contentControllers: [UIViewController] {
        if isExpanded {
            return detailNavigationController.contentControllers
        }
        return Array(listNavigationController.viewControllers.dropFirst())
    }

    /// The screen at the root of the detail column, while it is on screen.
    var selectedController: UIViewController? {
        guard isExpanded else { return nil }
        return detailNavigationController.contentControllers.first
    }

    /// A conversation replaces whatever the detail column shows, so the
    /// next push onto the content stack takes the whole column.
    func prepareToShowConversation() {
        if isExpanded {
            detailNavigationController.showPlaceholder()
        }
    }

    func popToList(animated: Bool) {
        listNavigationController.popToRootViewController(animated: animated)
        if isExpanded {
            detailNavigationController.showPlaceholder()
        }
    }

    // MARK: - UISplitViewControllerDelegate

    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        let moved = detailNavigationController.contentControllers
        detailNavigationController.showPlaceholder()
        if !moved.isEmpty {
            listNavigationController.setViewControllers(listNavigationController.viewControllers + moved,
                                                        animated: false)
        }
        onDetailChange?()
        return true
    }

    func splitViewController(_ splitViewController: UISplitViewController,
                             separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        let stack = listNavigationController.viewControllers
        let moved = Array(stack.dropFirst())
        if moved.isEmpty {
            detailNavigationController.showPlaceholder()
        } else {
            listNavigationController.setViewControllers(Array(stack.prefix(1)), animated: false)
            detailNavigationController.setViewControllers(moved, animated: false)
        }
        onDetailChange?()
        return detailNavigationController
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        onDetailChange?()
    }
}
