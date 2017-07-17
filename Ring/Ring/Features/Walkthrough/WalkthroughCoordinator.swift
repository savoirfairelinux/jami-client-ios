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
import RxSwift

public enum WalkthroughType {
    case createAccount
    case linkDevice
}

public enum WalkthroughState: State {
    case welcomeDone(withType: WalkthroughType)
    case profileCreated(withType: WalkthroughType)
    case accountCreated
    case deviceLinked
}

class WalkthroughCoordinator: Coordinator, StateableResponsive {

    /// the root View Controller to display
    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    /// The array containing any child Coordinators
    var childCoordinators = [Coordinator]()

    private let navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? WalkthroughState else { return }
            switch state {
            case .welcomeDone(let walkthroughType):
                self.showCreateProfile(with: walkthroughType)
                break
            case .profileCreated(let walkthroughType):
                self.showFinalStep(with: walkthroughType)
                break
            case .accountCreated, .deviceLinked:
                print ("---------->>>>>>>>>>>> SHOULD DISMISS THIS STUFF")
                self.rootViewController.dismiss(animated: true, completion: nil)
                break
            }
        }).disposed(by: self.disposeBag)

    }

    func start () {
        let welcomeViewModel = WelcomeViewModel()
        let welcomeViewController = WelcomeViewController.instantiate(with: welcomeViewModel)
        self.present(viewController: welcomeViewController, withStyle: .show, withAnimation: true, withStateable: welcomeViewModel)
    }

    private func showCreateProfile (with walkthroughType: WalkthroughType) {
        let createProfileViewModel = CreateProfileViewModel(with: walkthroughType)
        let createProfileViewController = CreateProfileViewController.instantiate(with: createProfileViewModel)
        self.present(viewController: createProfileViewController, withStyle: .show, withAnimation: true, withStateable: createProfileViewModel)
    }

    private func showFinalStep (with walkthroughType: WalkthroughType) {
        if walkthroughType == .createAccount {
            let createAccountViewModel = CreateAccountViewModel(with: self.injectionBag)
            let createAccountViewController = CreateAccountViewController.instantiate(with: createAccountViewModel)
            self.present(viewController: createAccountViewController, withStyle: .show, withAnimation: true, withStateable: createAccountViewModel)
        } else {

        }
    }
}
