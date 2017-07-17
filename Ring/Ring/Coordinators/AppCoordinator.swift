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

public enum AppState: State {
    case needToOnboard
}

class AppCoordinator: Coordinator, StateableResponsive {

    /// the root View Controller to display
    var rootViewController: UIViewController {
        return self.tabBarViewController
    }

    /// The array containing any child Coordinators
    var childCoordinators = [Coordinator]()

    private let tabBarViewController = UITabBarController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? AppState else { return }
            switch state {
            case .needToOnboard:
                self.showWalkthrough()
                break
            }
        }).disposed(by: self.disposeBag)

    }

    func start () {
    }

    private func showWalkthrough () {
        let walkthroughCoordinator = WalkthroughCoordinator(with: self.injectionBag)
        self.addChildCoordinator(childCoordinator: walkthroughCoordinator)
        let walkthroughViewController = walkthroughCoordinator.rootViewController
        self.present(viewController: walkthroughViewController, withStyle: .popup, withAnimation: true)
        walkthroughViewController.rx.viewDidDisappear.subscribe(onNext: { [weak self, weak walkthroughCoordinator] (_) in
            self?.removeChildCoordinator(childCoordinator: walkthroughCoordinator)
        }).disposed(by: self.disposeBag)
    }
    
}
