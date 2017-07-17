/*
 *  Copyright (C) 2016 Savoir-faire Linux Inc.
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

public enum PresentationStyle {
    case show
    case present
    case popup
}

protocol Coordinator: class {

    var rootViewController: UIViewController { get }

    init (with injectionBag: InjectionBag)
    func start ()

    /// The array containing any child Coordinators
    var childCoordinators: [Coordinator] { get set }

}

extension Coordinator {

    /// Add a child coordinator to the parent
    func addChildCoordinator(childCoordinator: Coordinator) {
        self.childCoordinators.append(childCoordinator)
    }

    /// Remove a child coordinator from the parent
    func removeChildCoordinator(childCoordinator: Coordinator) {
        self.childCoordinators = self.childCoordinators.filter { $0 !== childCoordinator }
    }

    func present(viewController: UIViewController, withStyle style: PresentationStyle, withAnimation animation: Bool) {
        switch style {
        case .present: self.rootViewController.present(viewController,
                                                       animated: animation,
                                                       completion: nil)
            break
        case .popup:
            viewController.modalPresentationStyle = .overCurrentContext
            viewController.modalTransitionStyle = .crossDissolve
            self.rootViewController.present(viewController,
                                            animated: animation,
                                            completion: nil)
            break
        case .show: self.rootViewController.show(viewController, sender: nil)
            break
        }
    }
}
