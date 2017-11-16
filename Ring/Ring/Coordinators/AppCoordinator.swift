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

import UIKit
import RxSwift

/// Represents Application global navigation state
///
/// - needToOnboard: user has to onboard because he has no account
public enum AppState: State {
    case initialLoading
    case needToOnboard
    case allSet
}

/// This Coordinator drives the global navigation of the app (presents the UITabBarController + popups the Walkthrough)
class AppCoordinator: Coordinator, StateableResponsive {

    // MARK: - Coordinator
    var rootViewController: UIViewController {
        return self.navigationController
    }

    var childCoordinators = [Coordinator]()
    // MARK: -

    // MARK: - StateableResponsive
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    // MARK: -

    private let navigationController = UINavigationController()
    private let tabBarViewController = UITabBarController()
    private let injectionBag: InjectionBag

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.navigationController.setNavigationBarHidden(true, animated: false)
        self.prepareMainInterface()

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? AppState else { return }
            switch state {
            case .initialLoading:
                self.showInitialLoading()
            case .needToOnboard:
                self.showWalkthrough()
            case .allSet:
                self.showMainInterface()
            }
        }).disposed(by: self.disposeBag)
    }

    func start () {
        self.stateSubject.onNext(AppState.initialLoading)
        self.dispatchApplication()
    }

    private func dispatchApplication() {
        self.injectionBag.newAccountsService
            .loadAccounts()
            .map({ (accounts) -> Bool in
                return !accounts.isEmpty
            })
            .subscribe(onSuccess: { [unowned self] (hasAccounts) in
                if hasAccounts {
                    self.stateSubject.onNext(AppState.allSet)
                } else {
                    self.stateSubject.onNext(AppState.needToOnboard)
                }
            }, onError: { (error) in
                print(error)
            })
            .disposed(by: self.disposeBag)
    }

    private func showInitialLoading () {
        let initialLoading = InitialLoadingViewController.instantiate()
        self.navigationController.setViewControllers([initialLoading], animated: false)
    }

    private func showWalkthrough () {
        let walkthroughCoordinator = WalkthroughCoordinator(with: self.injectionBag)
        walkthroughCoordinator.start()

        self.addChildCoordinator(childCoordinator: walkthroughCoordinator)
        let walkthroughViewController = walkthroughCoordinator.rootViewController
        self.present(viewController: walkthroughViewController,
                     withStyle: .appear,
                     withAnimation: true)

        walkthroughViewController.rx.controllerWasDismissed.subscribe(onNext: { [weak self, weak walkthroughCoordinator] (_) in
            walkthroughCoordinator?.stateSubject.dispose()
            self?.removeChildCoordinator(childCoordinator: walkthroughCoordinator)
            self?.dispatchApplication()
        }).disposed(by: self.disposeBag)
    }

    private func prepareMainInterface() {
        let conversationsCoordinator = ConversationsCoordinator(with: self.injectionBag)
        let contactRequestsCoordinator = ContactRequestsCoordinator(with: self.injectionBag)
        let meCoordinator = MeCoordinator(with: self.injectionBag)

        self.tabBarViewController.viewControllers = [conversationsCoordinator.rootViewController,
                                                     contactRequestsCoordinator.rootViewController,
                                                     meCoordinator.rootViewController]

        self.addChildCoordinator(childCoordinator: conversationsCoordinator)
        self.addChildCoordinator(childCoordinator: contactRequestsCoordinator)
        self.addChildCoordinator(childCoordinator: meCoordinator)

        conversationsCoordinator.start()
        contactRequestsCoordinator.start()
        meCoordinator.start()
    }

    private func showMainInterface () {
        self.navigationController.setViewControllers([self.tabBarViewController], animated: true)
    }

}
