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

/// Represents walkthrough navigation state
public enum WalkthroughState: State {
    case accountCreation(createAction: (String, String, String, UIImage?) -> Void)
    case linkDevice(linkAction: () -> Void)
    case importArchive(importAction: (_ url: URL, _ password: String) -> Void)
    case connectJAMS(connectAction: (_ username: String, _ password: String, _ server: String) -> Void)
    case connectSIP(connectAction: (_ username: String, _ password: String, _ server: String) -> Void)
    case aboutJami
    case completed
}

/// This Coordinator drives the walkthrough navigation (welcome / profile / creation or link)
class WalkthroughCoordinator: Coordinator, StateableResponsive {
    var presentingVC = [String: Bool]()
    var rootViewController: UIViewController {
        return self.navigationController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    var isAccountFirst: Bool = true
    var withAnimations: Bool = true

    internal var navigationController: UINavigationController = UINavigationController()
    private let injectionBag: InjectionBag
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? WalkthroughState else { return }
                switch state {
                case .completed:
                    finish()
                case .accountCreation(let createAction):
                    showAccountCreation(createAction: createAction)
                case .linkDevice(linkAction: let linkAction):
                    showLinkDevice(linkAction: linkAction)
                case .importArchive(importAction: let importAction):
                    showImportArchive(importAction: importAction)
                case .connectJAMS(connectAction: let connectAction):
                    showConnectJAMS(connectAction: connectAction)
                case .connectSIP(connectAction: let connectAction):
                    showConnectSIP(connectAction: connectAction)
                case .aboutJami:
                    showAboutJami()
                }
            })
            .disposed(by: self.disposeBag)
        self.navigationController.navigationBar.tintColor = UIColor.jamiButtonDark
    }

    func showAccountCreation(createAction: @escaping (String, String, String, UIImage?) -> Void) {
        let accountView = CreateAccountView(injectionBag: self.injectionBag, createAction: createAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.dismissHandler)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, disposeBag: self.disposeBag)
    }

    func showLinkDevice(linkAction: @escaping () -> Void) {
        let accountView = LinkToAccountView(injectionBag: self.injectionBag, linkAction: linkAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.dismissHandler)
        self.present(viewController: viewController, withStyle: .push, withAnimation: true, disposeBag: self.disposeBag)
    }

    func showImportArchive(importAction: @escaping (_ url: URL, _ password: String) -> Void) {
        let accountView = ImportFromArchiveView(injectionBag: self.injectionBag, importAction: importAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.dismissHandler)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, disposeBag: self.disposeBag)
    }

    func showConnectJAMS(connectAction: @escaping (_ username: String, _ password: String, _ server: String) -> Void) {
        let accountView = JamsConnectView(injectionBag: self.injectionBag, connectAction: connectAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.dismissHandler)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, disposeBag: self.disposeBag)
    }

    func showConnectSIP(connectAction: @escaping (_ username: String, _ password: String, _ server: String) -> Void) {
        let accountView = SIPConfigurationView(injectionBag: self.injectionBag, connectAction: connectAction)
        let viewController = createDismissableVC(accountView, dismissible: accountView.dismissHandler)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, disposeBag: self.disposeBag)
    }

    func showAboutJami() {
        let aboutView = AboutSwiftUIView()
        let viewController = createDismissableVC(aboutView, dismissible: aboutView.dismissHandler)
        self.present(viewController: viewController, withStyle: .formModal, withAnimation: true, disposeBag: self.disposeBag)
    }

    func start() {
        let welcomeView = WelcomeView(injectionBag: self.injectionBag,
                                      notCancelable: isAccountFirst)
        let viewController = createHostingVC(welcomeView)
        self.present(viewController: viewController, withStyle: .show, withAnimation: withAnimations, withStateable: welcomeView.stateEmitter)
    }

    func finish() {
        self.navigationController.setViewControllers([], animated: false)
        self.rootViewController.dismiss(animated: true)
    }
}
