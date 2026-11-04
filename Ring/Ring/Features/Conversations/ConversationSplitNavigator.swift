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

/// Lays out the smart list and the open conversation side by side when the
/// window is wide enough. When the split view collapses, UIKit stacks the
/// detail column's screens onto the list's navigation controller, and moves
/// them back when it expands. iPhone has no split view: everything is pushed
/// onto the list's navigation controller.
final class ConversationSplitNavigator: NSObject, UISplitViewControllerDelegate {
    let splitViewController = UISplitViewController(style: .doubleColumn)
    let listNavigationController: UINavigationController
    let usesSplitView: Bool
    private let makePlaceholder: () -> UIViewController
    private let isExpandedOverride: (() -> Bool)?
    private weak var placeholder: UIViewController?

    /// Called when the screen at the root of the detail column may have changed.
    var onDetailChange: (() -> Void)?

    init(listNavigationController: UINavigationController,
         makePlaceholder: @escaping () -> UIViewController,
         usesSplitView: Bool = UIDevice.current.userInterfaceIdiom == .pad,
         isExpanded: (() -> Bool)? = nil) {
        self.listNavigationController = listNavigationController
        self.makePlaceholder = makePlaceholder
        self.usesSplitView = usesSplitView
        self.isExpandedOverride = isExpanded
        super.init()
        guard usesSplitView else { return }
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredSplitBehavior = .tile
        splitViewController.presentsWithGesture = false
        splitViewController.displayModeButtonVisibility = .never
        splitViewController.setViewController(listNavigationController, for: .primary)
        showPlaceholder()
    }

    /// The view controller to install: the split view, or the list stack on iPhone.
    var rootViewController: UIViewController {
        return usesSplitView ? splitViewController : listNavigationController
    }

    /// Whether the list and the detail column are on screen side by side.
    var isExpanded: Bool {
        guard usesSplitView else { return false }
        if let isExpandedOverride = isExpandedOverride {
            return isExpandedOverride()
        }
        return !splitViewController.isCollapsed
    }

    var detailNavigationController: UINavigationController? {
        guard usesSplitView else { return nil }
        return splitViewController.viewController(for: .secondary) as? UINavigationController
    }

    var isShowingPlaceholder: Bool {
        guard let placeholder = placeholder else { return false }
        return detailNavigationController?.viewControllers.first === placeholder
    }

    /// The stack holding the open detail screen: the detail column when
    /// expanded, the list stack it was merged onto otherwise.
    var contentNavigationController: UINavigationController {
        if isExpanded, let detail = detailNavigationController {
            return detail
        }
        return listNavigationController
    }

    /// The screen at the root of the detail column, while it is on screen.
    var selectedController: UIViewController? {
        guard isExpanded, !isShowingPlaceholder else { return nil }
        return detailNavigationController?.viewControllers.first
    }

    /// Replaces the detail column with `controller`. Collapsed, UIKit pushes
    /// it onto the list stack instead.
    func showDetail(_ controller: UIViewController, animated: Bool) {
        guard usesSplitView else {
            listNavigationController.pushViewController(controller, animated: animated)
            onDetailChange?()
            return
        }
        let navigation = makeDetailNavigationController(root: controller)
        if animated {
            splitViewController.showDetailViewController(navigation, sender: nil)
        } else {
            UIView.performWithoutAnimation {
                splitViewController.showDetailViewController(navigation, sender: nil)
            }
        }
        onDetailChange?()
    }

    func popToList(animated: Bool) {
        listNavigationController.popToRootViewController(animated: animated)
        if isExpanded {
            showPlaceholder()
        }
        onDetailChange?()
    }

    private func showPlaceholder() {
        let placeholder = makePlaceholder()
        self.placeholder = placeholder
        splitViewController.setViewController(makeDetailNavigationController(root: placeholder),
                                              for: .secondary)
    }

    private func makeDetailNavigationController(root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.tintColor = UIColor.jami
        return navigation
    }

    // MARK: - UISplitViewControllerDelegate

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column)
    -> UISplitViewController.Column {
        return isShowingPlaceholder ? .primary : proposedTopColumn
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        onDetailChange?()
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        // Closing the detail screen while collapsed leaves the column empty.
        if detailNavigationController?.viewControllers.isEmpty ?? true {
            showPlaceholder()
        }
        onDetailChange?()
    }
}
