/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

import RxSwift
import UIKit

/// Represents Application global navigation state
///
/// - initialLoading: the app should display the loading interface as navigation root
/// - needToOnboard: user has to onboard because he has no account
/// - allSet: everything is set, the app should display its main interface
public enum AppState: State {
    case initialLoading
    case needToOnboard(animated: Bool, isFirstAccount: Bool)
    case addAccount
    case allSet
    case needAccountMigration(accountId: String)
}

public enum VCType: String {
    case conversation
    case contact
    case blockList
    case log
}

/// This Coordinator drives the global navigation of the app: it can present the main interface, the
/// walkthrough or a loading interface
final class AppCoordinator: Coordinator, StateableResponsive {
    var presentingVC = [String: Bool]()

    // MARK: Coordinator

    var rootViewController: UIViewController {
        return navigationController
    }

    var parentCoordinator: Coordinator?

    var childCoordinators = [Coordinator]()

    // MARK: -

    // MARK: StateableResponsive

    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    // MARK: -

    // MARK: Private members

    private let navigationController = UINavigationController()
    let injectionBag: InjectionBag

    /// Initializer
    ///
    /// - Parameter injectionBag: the injected injectionBag
    required init(with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        navigationController.setNavigationBarHidden(true, animated: false)

        stateSubject
            .subscribe(onNext: { [weak self] state in
                guard let self = self, let state = state as? AppState else { return }
                switch state {
                case .initialLoading:
                    self.showInitialLoading()
                case let .needToOnboard(animated, isFirstAccount):
                    self.showWalkthrough(animated: animated, isAccountFirst: isFirstAccount)
                case .allSet:
                    self.showMainInterface()
                case .addAccount:
                    self.showWalkthrough(animated: false, isAccountFirst: false)
                case let .needAccountMigration(accountId):
                    self.migrateAccount(accountId: accountId)
                }
            })
            .disposed(by: disposeBag)
    }

    /// Starts the coordinator
    func start() {
        // ~ By default, always present the initial loading at start
        stateSubject.onNext(AppState.initialLoading)
        // ~ Dispatch to the proper screen
        dispatchApplication()
    }

    func migrateAccount(accountId: String) {
        let migratonController = MigrateAccountViewController.instantiate(with: injectionBag)
        migratonController.viewModel.accountToMigrate = accountId
        present(viewController: migratonController, withStyle: .show,
                withAnimation: true,
                withStateable: migratonController.viewModel)
    }

    /// Handles the switch between the three supported screens.
    private func dispatchApplication() {
        if injectionBag.accountService.accounts.isEmpty {
            stateSubject.onNext(AppState.needToOnboard(animated: true, isFirstAccount: true))
        } else {
            stateSubject.onNext(AppState.allSet)
        }
    }

    /// Presents the initial loading interface as the root of the navigation
    func showInitialLoading() {
        let initialLoading = InitialLoadingViewController.instantiate()
        navigationController.setViewControllers([initialLoading], animated: true)
    }

    func showDatabaseError() {
        let alertController = UIAlertController(title: L10n.Alerts.dbFailedTitle,
                                                message: L10n.Alerts.dbFailedMessage,
                                                preferredStyle: .alert)
        present(
            viewController: alertController,
            withStyle: .present,
            withAnimation: false,
            disposeBag: disposeBag
        )
    }

    // MARK: - Private methods

    /// Presents the walkthrough as a popup with a fade effect
    private func showWalkthrough(animated: Bool, isAccountFirst: Bool) {
        let walkthroughCoordinator = WalkthroughCoordinator(with: injectionBag)
        walkthroughCoordinator.isAccountFirst = isAccountFirst
        walkthroughCoordinator.withAnimations = animated
        walkthroughCoordinator.start()

        addChildCoordinator(childCoordinator: walkthroughCoordinator)
        let walkthroughViewController = walkthroughCoordinator.rootViewController
        present(viewController: walkthroughViewController,
                withStyle: .appear,
                withAnimation: true,
                disposeBag: disposeBag)

        walkthroughViewController.rx.controllerWasDismissed
            .subscribe(onNext: { [weak self, weak walkthroughCoordinator] _ in
                walkthroughCoordinator?.stateSubject.dispose()
                self?.removeChildCoordinator(childCoordinator: walkthroughCoordinator)
                self?.dispatchApplication()
            })
            .disposed(by: disposeBag)
    }

    /// Presents the main interface
    private func showMainInterface() {
        if !childCoordinators.isEmpty,
           childCoordinators[0] as? ConversationsCoordinator != nil {
            return
        }
        let conversationsCoordinator = ConversationsCoordinator(with: injectionBag)
        conversationsCoordinator.parentCoordinator = self
        conversationsCoordinator.setNavigationController(controller: navigationController)
        conversationsCoordinator.start()
        addChildCoordinator(childCoordinator: conversationsCoordinator)
    }

    func openConversation(participantID: String) {
        if let conversationCoordinator = childCoordinators[0] as? ConversationsCoordinator {
            conversationCoordinator.pushConversation(participantId: participantID)
        }
    }

    func openConversation(conversationId: String, accountId: String) {
        if let conversationCoordinator = childCoordinators[0] as? ConversationsCoordinator {
            conversationCoordinator.openConversation(
                conversationId: conversationId,
                accountId: accountId,
                shouldOpenSmarList: true
            )
        }
    }

    func startCall(participant: String, name: String, isVideo: Bool) {
        DispatchQueue.main.async {
            for child in self.childCoordinators {
                if let childCoordinattor = child as? ConversationsCoordinator {
                    if isVideo {
                        childCoordinattor.stateSubject
                            .onNext(ConversationState
                                        .startCall(contactRingId: participant, userName: name))
                        return
                    }
                    childCoordinattor.stateSubject
                        .onNext(ConversationState
                                    .startAudioCall(contactRingId: participant, userName: name))
                    return
                }
            }
        }
    }
}
