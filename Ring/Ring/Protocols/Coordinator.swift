/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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
import UIKit
import RxSwift
import SwiftUI

/**
 Represents how a UIViewController should be displayed
 */
public enum PresentationStyle {
    /// Pushes a view controller onto the navigation stack.
    case push

    /// Presents a view controller modally.
    case present

    /// Displays a view controller over the current context, keeping the background visible.
    case overCurrentContext

    /// Presents a view controller with a fade-in transition over the full screen.
    case fadeInOverFullScreen

    /// Pops the navigation stack to its root and then pushes a new view controller.
    case popToRootAndPush

    /// Presents a view controller modally in a form sheet style.
    case formModal

    /// Displays a view controller using the most appropriate method based on the context.
    case show

    /// Replaces the current navigation stack with a new stack containing the specified view controller.
    case replaceNavigationStack
}

/// A Coordinator drives the navigation of a whole part of the application
protocol Coordinator: AnyObject {

    /// the root View Controller to display
    var rootViewController: UIViewController { get }

    /// The array containing any child Coordinators
    var childCoordinators: [Coordinator] { get set }

    /// Parent coordinator
    var parentCoordinator: Coordinator? { get set }

    /// flag to be setting to true during particular viewController is presenting
    /// this property is added to prevent controller to be presenting multiple times, caused by UI lag
    var presentingVC: [String: Bool] { get set }

    var disposeBag: DisposeBag { get set }

    /// Nothing will happen until this function is called
    /// it bootstraps the initial UIViewController (after the rooViewController) that will
    /// be displayed by this Coordinator
    func start ()
}

extension Coordinator {

    /// Adds a child coordinator so that there is a reference to it
    ///
    /// - Parameter childCoordinator: The coordinator on which we need to keep a reference
    func addChildCoordinator(childCoordinator: Coordinator) {
        self.childCoordinators.append(childCoordinator)
    }

    /// Removes a child coordinator that is no longer used
    ///
    /// - Parameter childCoordinator: The coordinator we want to remove
    func removeChildCoordinator(childCoordinator: Coordinator?) {
        guard let child = childCoordinator else { return }
        self.childCoordinators = self.childCoordinators.filter { $0 !== child }
    }

    /// Present a view controller according to PresentationStyle
    ///
    /// - Parameters:
    ///   - viewController: The ViewController we want to present (it will be presented by the rootViewController)
    ///   - style: The presentation style (show, present or popup)
    ///   - animation: Wether the transition should be animated or not
    func present(viewController: UIViewController,
                 withStyle style: PresentationStyle,
                 withAnimation animation: Bool,
                 lockWhilePresenting VCType: String? = nil,
                 disposeBag: DisposeBag) {
        switch style {
        case .present: self.rootViewController.present(viewController,
                                                       animated: animation,
                                                       completion: nil)
        case .overCurrentContext:
            viewController.modalPresentationStyle = .overCurrentContext
            viewController.modalTransitionStyle = .coverVertical
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
        case .formModal:
            viewController.modalPresentationStyle = .formSheet
            viewController.modalTransitionStyle = .coverVertical
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
        case .show:
            self.rootViewController.show(viewController, sender: nil)
        case .fadeInOverFullScreen:
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalTransitionStyle = .crossDissolve
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
        case .popToRootAndPush:
            if let contoller: UINavigationController = self.rootViewController as? UINavigationController {
                // ensure we on the root view controller
                contoller.popViewController(animated: false)
                contoller.pushViewController(viewController, animated: false)
            }

        case .push:
            if let contoller: UINavigationController = self.rootViewController as? UINavigationController {
                contoller.pushViewController(viewController, animated: animation)
            }
        case .replaceNavigationStack:
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalTransitionStyle = .coverVertical
            if let contoller: UINavigationController = self.rootViewController as? UINavigationController {
                contoller.setViewControllers([viewController], animated: animation)
            }

        }

        if let viewControllerType = VCType {
            viewController.rx.viewDidLoad
                .subscribe(onNext: { [weak self] _ in
                    self?.presentingVC[viewControllerType] = false
                }, onError: { [weak self] _ in
                    self?.presentingVC[viewControllerType] = false
                }, onCompleted: { [weak self] in
                    self?.presentingVC[viewControllerType] = false
                }, onDisposed: {  [weak self] in
                    self?.presentingVC[viewControllerType] = false
                })
                .disposed(by: disposeBag)
        }
    }

    func createHostingVC<Content: View>(
        _ view: Content
    ) -> UIViewController {
        let hostingController = UIHostingController(rootView: view)
        return hostingController
    }

    func createDismissableVC<Content: View>(
        _ view: Content,
        dismissible: DismissHandler
    ) -> UIViewController {
        let hostingController = UIHostingController(rootView: view)
        dismissible
            .dismiss
            .take(1)
            .subscribe(onNext: { [weak self] shouldDismiss in
                if shouldDismiss {
                    self?.dismiss(viewController: hostingController, animated: true)
                }
            })
            .disposed(by: self.disposeBag)
        return hostingController
    }

    func getTopController() -> UIViewController? {
        guard var topController = UIApplication.shared.windows.first?.rootViewController else {
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }

    private func dismiss(viewController: UIViewController, animated: Bool) {
        if let navigationController = viewController.navigationController {
            navigationController.popViewController(animated: animated)
        } else {
            viewController.dismiss(animated: animated, completion: nil)
        }
    }
}

/// The `RootCoordinator` protocol is designed for the root coordinator that manages
/// the primary `UINavigationController` of the application.
///
/// Unlike other coordinators, which create and manage their own navigation controllers
/// internally, the `RootCoordinator` requires a navigation controller to be passed in
/// from `AppCoordinator`.
protocol RootCoordinator: Coordinator {
    var navigationController: UINavigationController { get }
    init(navigationController: UINavigationController, injectionBag: InjectionBag)
}
