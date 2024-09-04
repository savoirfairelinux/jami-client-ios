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
import SwiftUI

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
public enum WalkthroughState: State {
    case accountCreation(createAction: (String, String, String, UIImage?) -> Void)
    case completed
}

/// This Coordinator drives the walkthrough navigation (welcome / profile / creation or link)
class WalkthroughCoordinator: Coordinator, StateableResponsive {
    
    var presentingVC = [String: Bool]()
    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    var isAccountFirst: Bool = true
    var withAnimations: Bool = true

    private let navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? WalkthroughState else { return }
                switch state {
                case .completed:
                    self.navigationViewController.setViewControllers([], animated: false)
                    self.rootViewController.dismiss(animated: true)
                    case .accountCreation(let createAction):
                        showAccountCreation(createAction: createAction)
                }
            })
            .disposed(by: self.disposeBag)

    }

    func showAccountCreation(createAction: @escaping (String, String, String, UIImage?) -> Void) {
        let accountView = CreateAccountView(injectionBag: self.injectionBag, createAction: createAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.viewModel)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, withStateable: accountView.viewModel)
    }

//    func showLinkDevice(linkAction: @escaping (_ pin: String, _ password: String) -> Void) {
//        let accountView = LinkToAccountView(linkAction: linkAction)
//        let viewController = createVC(accountView)
//        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, withStateable: accountView.model)
//    }

    func start() {
        let welcomeView = WelcomeView(injectionBag: self.injectionBag)
        let viewController = createVC(welcomeView)
        welcomeView.viewModel.notCancelable = false
        self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: welcomeView.viewModel)
    }
}
