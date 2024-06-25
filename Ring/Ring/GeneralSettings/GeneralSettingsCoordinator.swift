/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

public enum SettingsState: State {
    case openLog
}

class GeneralSettingsCoordinator: Coordinator, StateableResponsive {
    var presentingVC: [String: Bool]

    var rootViewController: UIViewController {
        return navigationViewController
    }

    var parentCoordinator: Coordinator?

    var childCoordinators = [Coordinator]()

    private var navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        presentingVC = [String: Bool]()
        stateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                guard let self = self, let state = state as? SettingsState else { return }
                switch state {
                case .openLog:
                    self.openLog()
                }
            })
            .disposed(by: disposeBag)
    }

    func start() {
        let settingsViewController = GeneralSettingsViewController.instantiate(with: injectionBag)
        present(
            viewController: settingsViewController,
            withStyle: .show,
            withAnimation: true,
            withStateable: settingsViewController.viewModel
        )
    }

    func setNavigationController(controller: UINavigationController) {
        navigationViewController = controller
    }

    func openLog() {
        let logVC = LogViewController.instantiate(with: injectionBag)
        present(
            viewController: logVC,
            withStyle: .show,
            withAnimation: true,
            disposeBag: disposeBag
        )
    }
}
