//
//  GeneralSettingsCoordinator.swift
//  Ring
//
//  Created by kateryna on 2023-01-17.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import RxSwift

public enum SettingsState: State {
    case openLog
}

class GeneralSettingsCoordinator: Coordinator, StateableResponsive {
    var presentingVC: [String: Bool]

    var rootViewController: UIViewController {
        return self.navigationViewController
    }
    var parentCoordinator: Coordinator?

    var childCoordinators = [Coordinator]()

    private var navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        presentingVC = [String: Bool]()
        self.stateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? SettingsState else { return }
                switch state {
                case .openLog:
                    self.openLog()
                }
            })
            .disposed(by: self.disposeBag)
    }

    func start() {
        let settingsViewController = GeneralSettingsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: settingsViewController, withStyle: .show, withAnimation: true, withStateable: settingsViewController.viewModel)
    }

    func setNavigationController(controller: UINavigationController) {
        navigationViewController = controller
    }

    func openLog() {
        let logVC = LogViewController.instantiate(with: self.injectionBag)
        self.present(viewController: logVC, withStyle: .show, withAnimation: true, disposeBag: self.disposeBag)
    }
}
