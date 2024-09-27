/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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
import RxCocoa

public enum SettingsState: State {
    case linkNewDevice
    case blockedContacts
    case needToOnboard
    case accountRemoved
    case accountModeChanged
    case needAccountMigration(accountId: String)
    case dismiss
}

class SettingsCoordinator: Coordinator, StateableResponsive {

    var presentingVC = [String: Bool]()

    var rootViewController: UIViewController {
        return self.navigationController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?

    internal var navigationController: UINavigationController = UINavigationController()
    let injectionBag: InjectionBag
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    var account: AccountModel?

    required init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.stateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? SettingsState else { return }
                switch state {
                    case .dismiss:
                        self.finish()
                    default:
                        break
                }
            })
            .disposed(by: self.disposeBag)
//        self.callbackPlaceCall()
    }

    func start() {
//        func showAccountSettings(account: AccountModel) {
//            let view = AccountSummaryView(injectionBag: self.injectionBag, account: account)
//            let viewController = createHostingVC(view)
//            self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: view.model)
//        }
        if let account = account {
            let view = AccountSummaryView(injectionBag: self.injectionBag, account: account)
            let viewController = createHostingVC(view)
            self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: view.model)
        }
    }

    func addLockFlags() {

    }

    func finish() {
        self.rootViewController.dismiss(animated: true)
    }
}
