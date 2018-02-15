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

/// Represents Me navigation state
///
/// - meDetail: user want its account detail
/// -linkDevice: link new device to account
public enum MeState: State {
    case meDetail
    case linkNewDevice
    case blockedContacts
}

/// This Coordinator drives the me/settings navigation
class MeCoordinator: Coordinator, StateableResponsive {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()

    private let navigationViewController = BaseViewController(with: TabBarItemType.account)
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? MeState else { return }
            switch state {
            case .meDetail:
                self.showMeDetail()

            case .linkNewDevice:
                 self.showLinkDeviceWindow()
            case .blockedContacts:
                self.showBlockedContacts()
            }
        }).disposed(by: self.disposeBag)
    }

    func start () {
        let meViewController = MeViewController.instantiate(with: self.injectionBag)
        self.present(viewController: meViewController, withStyle: .show, withAnimation: true, withStateable: meViewController.viewModel)
    }

    private func showBlockedContacts() {
        let blockedContactsViewController = BlockListViewController.instantiate(with: self.injectionBag)
        self.present(viewController: blockedContactsViewController, withStyle: .show, withAnimation: true)
    }

    private func showMeDetail () {
        let meDetailViewController = MeDetailViewController.instantiate(with: self.injectionBag)
        self.present(viewController: meDetailViewController, withStyle: .show, withAnimation: true)
    }

    private func showLinkDeviceWindow() {
        let linkDeviceVC = LinkNewDeviceViewController.instantiate(with: self.injectionBag)
        self.present(viewController: linkDeviceVC, withStyle: .popup, withAnimation: false)
    }
}
