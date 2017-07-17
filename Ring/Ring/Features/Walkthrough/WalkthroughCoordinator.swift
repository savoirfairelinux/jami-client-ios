//
//  WalkthroughCoordinator.swift
//  Ring
//
//  Created by Thibault Wittemberg on 2017-07-17.
//  Copyright © 2017 Savoir-faire Linux. All rights reserved.
//

import Foundation


class WalkthroughCoordinator: Coordinator {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    private let navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
    }

    func start () {
        self.navigationViewController.setToolbarHidden(true, animated: false)
        self.navigationViewController.viewControllers = [WelcomeViewController.instantiate()]
    }

    /// The array containing any child Coordinators
    var childCoordinators = [Coordinator]()
}
