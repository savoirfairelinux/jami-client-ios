/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import RxSwift

/// Represents the choice made by the user in the Walkthrough for the creation account type
///
/// - createAccount: create an account from scratch (profile / username / password)
/// - linkDevice: link the device to an existing account (profile / pin / password)
public enum WalkthroughType {
    case createAccount
    case linkDevice
    case createSipAccount
    case linkToAccountManager
}

/// Represents walkthrough navigation state
///
/// - welcomeDone: user has made the WalkthroughType choice (first page)
/// - profileCreated: profile has been created
/// - accountCreated: account has finish creating
/// - deviceLinked: linking has finished
public enum WalkthroughState: State {
    case welcomeDone(withType: WalkthroughType)
    case accountCreated
    case deviceLinked
    case walkthroughCanceled
    case aboutJami
}

/// This Coordinator drives the walkthrough navigation (welcome / profile / creation or link)
class WalkthroughCoordinator: Coordinator, StateableResponsive {
    var presentingVC = [String: Bool]()
    var rootViewController: UIViewController {
        return navigationViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    var isAccountFirst: Bool = true
    var withAnimations: Bool = true

    private let navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        stateSubject
            .subscribe(onNext: { [weak self] state in
                guard let self = self, let state = state as? WalkthroughState else { return }
                switch state {
                case let .welcomeDone(walkthroughType):
                    self.showAddAccount(with: walkthroughType)
                case .accountCreated, .deviceLinked:
                    if self.rootViewController.presentedViewController != nil {
                        self.rootViewController
                            .dismiss(animated: true) { [weak self] in
                                // dismiss the pop up form modal view
                                self?.rootViewController
                                    .dismiss(animated: true) // dismiss the welcome view and check
                                // for user account state
                            }
                    }
                case .walkthroughCanceled:
                    self.rootViewController.dismiss(animated: true)
                case .aboutJami:
                    self.openAboutJami()
                }
            })
            .disposed(by: disposeBag)
    }

    func openAboutJami() {
        let aboutJamiController = AboutViewController.instantiate()
        present(
            viewController: aboutJamiController,
            withStyle: .show,
            withAnimation: true,
            disposeBag: disposeBag
        )
    }

    func start() {
        let welcomeViewController = WelcomeViewController.instantiate(with: injectionBag)
        welcomeViewController.viewModel.notCancelable = isAccountFirst
        welcomeViewController.viewModel.isAnimatable = withAnimations
        present(
            viewController: welcomeViewController,
            withStyle: .show,
            withAnimation: false,
            withStateable: welcomeViewController.viewModel
        )
    }

    private func showAddAccount(with walkthroughType: WalkthroughType) {
        switch walkthroughType {
        case .createAccount:
            let createAccountViewController = CreateAccountViewController
                .instantiate(with: injectionBag)
            present(
                viewController: createAccountViewController,
                withStyle: .formModal,
                withAnimation: true,
                withStateable: createAccountViewController.viewModel
            )
        case .createSipAccount:
            let sipAccountViewController = CreateSipAccountViewController
                .instantiate(with: injectionBag)
            present(
                viewController: sipAccountViewController,
                withStyle: .formModal,
                withAnimation: true,
                withStateable: sipAccountViewController.viewModel
            )
        case .linkDevice:
            let linkDeviceViewController = LinkDeviceViewController.instantiate(with: injectionBag)
            present(
                viewController: linkDeviceViewController,
                withStyle: .formModal,
                withAnimation: true,
                withStateable: linkDeviceViewController.viewModel
            )
        case .linkToAccountManager:
            let linkToManagerViewController = LinkToAccountManagerViewController
                .instantiate(with: injectionBag)
            present(
                viewController: linkToManagerViewController,
                withStyle: .formModal,
                withAnimation: true,
                withStateable: linkToManagerViewController.viewModel
            )
        }
    }
}
