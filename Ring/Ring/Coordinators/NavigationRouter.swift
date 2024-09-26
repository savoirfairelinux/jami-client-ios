//
//  NavigationRouter.swift
//  Ring
//
//  Created by kateryna on 2024-09-03.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI

protocol NavigationRouter {

    associatedtype V: View

    var transition: NavigationTranisitionStyle { get }

    /// Creates and returns a view of assosiated type
    ///
    @ViewBuilder
    func view() -> V
}

enum NavigationTranisitionStyle {
    case push
    case presentModally
    case presentFullscreen
}

enum MainRouter: NavigationRouter {

    case welcome(injectionbag: InjectionBag)
    case createAccount(injectionbag: InjectionBag)

    public var transition: NavigationTranisitionStyle {
        switch self {
            case .welcome:
                return .push
            case .createAccount:
                return .push
        }
    }

    @ViewBuilder
    public func view() -> some View {
        switch self {
            case .welcome(injectionbag: let injectionbag):
                WelcomeView(injectionBag: injectionbag)
            case .createAccount(injectionbag: let injectionbag):
                CreateAccountView(injectionBag: injectionbag)
        }
    }
}

enum WalkthrowRouter: NavigationRouter {

    case welcome(injectionbag: InjectionBag)
    case createAccount(injectionbag: InjectionBag)

    public var transition: NavigationTranisitionStyle {
        switch self {
            case .welcome:
                return .push
            case .createAccount:
                return .push
        }
    }

    @ViewBuilder
    public func view() -> some View {
        switch self {
            case .welcome(injectionbag: let injectionbag):
                WelcomeView(injectionBag: injectionbag)
            case .createAccount(injectionbag: let injectionbag):
               CreateAccountView(injectionBag: injectionbag)
        }
    }
}

class CoordinatorSwiftUI<Router: NavigationRouter>: ObservableObject {

    public let navigationController: UINavigationController
    public let startingRoute: Router?

    public init(navigationController: UINavigationController = .init(), startingRoute: Router? = nil) {
        self.navigationController = navigationController
        self.startingRoute = startingRoute
    }

    public func start() {
        guard let route = startingRoute else { return }
        show(route)
    }

    public func show(_ route: Router, animated: Bool = true) {
        let view = route.view()
        let viewWithCoordinator = view.environmentObject(self)
        let viewController = UIHostingController(rootView: viewWithCoordinator)
        switch route.transition {
            case .push:
                navigationController.pushViewController(viewController, animated: animated)
            case .presentModally:
                viewController.modalPresentationStyle = .formSheet
                navigationController.present(viewController, animated: animated)
            case .presentFullscreen:
                viewController.modalPresentationStyle = .fullScreen
                navigationController.present(viewController, animated: animated)
        }
    }

    public func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    public func popToRoot(animated: Bool = true) {
        navigationController.popToRootViewController(animated: animated)
    }

    open func dismiss(animated: Bool = true) {
        navigationController.dismiss(animated: true) { [weak self] in
            /// because there is a leak in UIHostingControllers that prevents from deallocation
            self?.navigationController.viewControllers = []
        }
    }
}
