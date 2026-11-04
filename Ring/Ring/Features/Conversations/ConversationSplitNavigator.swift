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
}

/// Lays out the smart list and the open conversation side by side when the
/// window is wide enough. In compact width the split view collapses and
/// everything is stacked on the list's navigation controller, as on iPhone.
final class ConversationSplitNavigator: NSObject, UISplitViewControllerDelegate {
    let splitViewController = UISplitViewController()
    let listNavigationController: UINavigationController
    let detailNavigationController: DetailNavigationController

    init(listNavigationController: UINavigationController,
         placeholder: UIViewController) {
        self.listNavigationController = listNavigationController
        self.detailNavigationController = DetailNavigationController(placeholder: placeholder)
        super.init()
        splitViewController.viewControllers = [listNavigationController, detailNavigationController]
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.presentsWithGesture = false
        splitViewController.delegate = self
    }

    // MARK: - UISplitViewControllerDelegate

    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    func splitViewController(_ splitViewController: UISplitViewController,
                             separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        detailNavigationController.showPlaceholder()
        return detailNavigationController
    }
}
