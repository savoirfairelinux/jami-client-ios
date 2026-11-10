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
import RxRelay

/// Lays out the smart list and the open conversation side by side when the
/// window is wide enough. Collapsed, and on iPhone, detail screens are pushed
/// onto the list's navigation controller.
final class ConversationSplitNavigator: NSObject, UISplitViewControllerDelegate, UINavigationControllerDelegate {
    let splitViewController = UISplitViewController(style: .doubleColumn)
    private let listNavigationController: UINavigationController
    let usesSplitView: Bool
    let shownDetailChanged = PublishRelay<Void>()
    private(set) weak var shownDetail: UIViewController?
    private let makePlaceholder: () -> UIViewController
    private let isExpandedOverride: (() -> Bool)?
    private weak var placeholder: UIViewController?

    init(listNavigationController: UINavigationController = UINavigationController(),
         makePlaceholder: @escaping () -> UIViewController,
         usesSplitView: Bool = UIDevice.current.userInterfaceIdiom == .pad,
         isExpanded: (() -> Bool)? = nil) {
        self.listNavigationController = listNavigationController
        self.makePlaceholder = makePlaceholder
        self.usesSplitView = usesSplitView
        self.isExpandedOverride = isExpanded
        super.init()
        listNavigationController.delegate = self
        listNavigationController.navigationBar.tintColor = UIColor.jami
        guard usesSplitView else { return }
        splitViewController.delegate = self
        splitViewController.preferredDisplayMode = .oneBesideSecondary
        splitViewController.preferredSplitBehavior = .tile
        splitViewController.presentsWithGesture = false
        splitViewController.displayModeButtonVisibility = .never
        splitViewController.setViewController(listNavigationController, for: .primary)
        showPlaceholder()
    }

    var rootViewController: UIViewController {
        return usesSplitView ? splitViewController : listNavigationController
    }

    var isExpanded: Bool {
        guard usesSplitView else { return false }
        if let isExpandedOverride = isExpandedOverride {
            return isExpandedOverride()
        }
        return splitViewController.traitCollection.horizontalSizeClass != .compact
    }

    var detailNavigationController: UINavigationController? {
        guard usesSplitView else { return nil }
        return splitViewController.viewController(for: .secondary) as? UINavigationController
    }

    var isShowingPlaceholder: Bool {
        guard let placeholder = placeholder else { return false }
        return detailNavigationController?.viewControllers.first === placeholder
    }

    var detailStack: UINavigationController {
        if let navigation = shownDetail?.navigationController {
            return navigation
        }
        if isExpanded, let detail = detailNavigationController {
            return detail
        }
        return listNavigationController
    }

    func showInDetail(_ controller: UIViewController, animated: Bool) {
        if isExpanded {
            let navigation = makeDetailNavigationController(with: [controller])
            if animated {
                splitViewController.showDetailViewController(navigation, sender: nil)
            } else {
                splitViewController.setViewController(navigation, for: .secondary)
            }
        } else {
            listNavigationController.pushViewController(controller, animated: animated)
        }
        setShownDetail(controller)
    }

    func setListRoot(_ controller: UIViewController) {
        listNavigationController.setViewControllers([controller], animated: false)
    }

    func removeFromList(where shouldRemove: (UIViewController) -> Bool) {
        let controllers = listNavigationController.viewControllers
        let remaining = controllers.filter { !shouldRemove($0) }
        if remaining.count != controllers.count {
            listNavigationController.setViewControllers(remaining, animated: false)
        }
    }

    func pushOntoDetail(_ controller: UIViewController, animated: Bool) {
        detailStack.pushViewController(controller, animated: animated)
    }

    func reveal(_ controller: UIViewController, animated: Bool) -> Bool {
        var path = [(navigation: UINavigationController, child: UIViewController)]()
        var child = controller
        while let navigation = child.navigationController, navigation.viewControllers.contains(child) {
            path.append((navigation: navigation, child: child))
            child = navigation
        }
        guard !path.isEmpty,
              child === listNavigationController || child === detailNavigationController else {
            return false
        }
        for step in path where step.navigation.topViewController !== step.child {
            step.navigation.popToViewController(step.child, animated: animated)
        }
        return true
    }

    func popToList(animated: Bool) {
        listNavigationController.popToRootViewController(animated: animated)
        if usesSplitView {
            showPlaceholder()
        }
        setShownDetail(nil)
    }

    private func setShownDetail(_ controller: UIViewController?) {
        shownDetail = controller
        shownDetailChanged.accept(())
    }

    private func showPlaceholder() {
        let placeholder = makePlaceholder()
        self.placeholder = placeholder
        if let detail = detailNavigationController {
            detail.setViewControllers([placeholder], animated: false)
        } else {
            splitViewController.setViewController(makeDetailNavigationController(with: [placeholder]),
                                                  for: .secondary)
        }
    }

    private func makeDetailNavigationController(with controllers: [UIViewController]) -> UINavigationController {
        let navigation = UINavigationController()
        navigation.setViewControllers(controllers, animated: false)
        navigation.navigationBar.tintColor = UIColor.jami
        return navigation
    }

    // MARK: - UISplitViewControllerDelegate

    func splitViewController(_ svc: UISplitViewController,
                             topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column)
    -> UISplitViewController.Column {
        return shownDetail == nil ? .primary : proposedTopColumn
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        shownDetailChanged.accept(())
    }

    func splitViewController(_ svc: UISplitViewController,
                             displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode)
    -> UISplitViewController.DisplayMode {
        moveListDetailToDetailColumn()
        return proposedDisplayMode
    }

    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        let detail = detailNavigationController?.viewControllers ?? []
        let showsShownDetail = shownDetail.map { detail.contains($0) } ?? false
        if !showsShownDetail && !isShowingPlaceholder {
            showPlaceholder()
            shownDetail = nil
        }
        shownDetailChanged.accept(())
    }

    private func moveListDetailToDetailColumn() {
        let stack = listNavigationController.viewControllers
        guard let list = stack.first, stack.count > 1,
              let detail = detailNavigationController,
              !stack.contains(where: { $0 === detail }) else { return }
        listNavigationController.setViewControllers([list], animated: false)
        detail.setViewControllers(Array(stack.dropFirst()), animated: false)
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        guard navigationController === listNavigationController,
              viewController === listNavigationController.viewControllers.first,
              !isExpanded,
              shownDetail != nil else { return }
        popToList(animated: false)
    }
}
