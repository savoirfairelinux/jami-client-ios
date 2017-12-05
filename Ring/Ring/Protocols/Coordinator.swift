/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

/**
 Represents how a UIViewController should be displayed

 - show: the system adapts the presentation mecanism to fit the context (can be a push in case of a UINavigationViewController for instance)
 - present: simply presents the UIViewController
 - popup: presents the UIViewController as a modal popup with a .coverVertical transition
 */
public enum PresentationStyle {
    case show
    case present
    case popup
    case appear
}

/// A Coordinator drives the navigation of a whole part of the application
protocol Coordinator: class {

    /// the root View Controller to display
    var rootViewController: UIViewController { get }

    /// The array containing any child Coordinators
    var childCoordinators: [Coordinator] { get set }

    /// Initializes a new Coordinator with a dependancy injection bag
    ///
    /// - Parameter injectionBag: The injection Bag that will be passed to every sub components that need it
    init (with injectionBag: InjectionBag)

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
                 withAnimation animation: Bool) {
        switch style {
        case .present: self.rootViewController.present(viewController,
                                                       animated: animation,
                                                       completion: nil)
        case .popup:
            viewController.modalPresentationStyle = .overCurrentContext
            viewController.modalTransitionStyle = .coverVertical
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
        case .show:
            self.rootViewController.show(viewController, sender: nil)
        case .appear:
            viewController.modalPresentationStyle = .overFullScreen
            viewController.modalTransitionStyle = .crossDissolve
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
        }
    }
}
