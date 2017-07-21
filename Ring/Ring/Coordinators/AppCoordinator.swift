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
import UIKit
import RxSwift
import SwiftyBeaver

/// Represents Application global navigation state
///
/// - needToOnboard: user has to onboard because he has no account
/// - incoming call
/// - outgoing call
enum AppState: State {
    case needToOnboard
    case incomingCall(withModel: CallModel)
    case outgoingCall(withModel: CallModel)
}

/// This Coordinator drives the global navigation of the app (presents the UITabBarController + popups the Walkthrough)
class AppCoordinator: Coordinator, StateableResponsive {

    var rootViewController: UIViewController {
        return self.tabBarViewController
    }

    var childCoordinators = [Coordinator]()

    private let tabBarViewController = UITabBarController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    fileprivate let log = SwiftyBeaver.self

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        //subscribe for incoming call
        self.injectionBag.callsService.currentCall.filter({ call in
            return call.state == .incoming && call.callType == .incoming
        }).map({ call in
            return call
        }).subscribe(onNext: { call in
            self.stateSubject.onNext(AppState.incomingCall(withModel: call))
        }).disposed(by: self.disposeBag)
        //subscribe for outgoing call
        self.injectionBag.callsService.currentCall.filter({ call in
            return call.state == .connecting && call.callType == .outgoing
        }).map({ call in
            return call
        }).subscribe(onNext: { call in
            self.stateSubject.onNext(AppState.outgoingCall(withModel: call))
        }).disposed(by: self.disposeBag)

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? AppState else { return }
            switch state {
            case .needToOnboard:
                self.showWalkthrough()
                break
            case .incomingCall (let call):
                self.showIncomingCallAlert(withCallModel: call)
                break
            case .outgoingCall (let call):
                self.presentCallScreen(withCallModel: call)
                break
            }
        }).disposed(by: self.disposeBag)

    }

    func start () {

        let conversationsCoordinator = ConversationsCoordinator(with: self.injectionBag)
        let contactRequestsCoordinator = ContactRequestsCoordinator(with: self.injectionBag)
        let meCoordinator = MeCoordinator(with: self.injectionBag)

        self.tabBarViewController.viewControllers = [conversationsCoordinator.rootViewController,
                                                     contactRequestsCoordinator.rootViewController,
                                                     meCoordinator.rootViewController]

        self.addChildCoordinator(childCoordinator: conversationsCoordinator)
        self.addChildCoordinator(childCoordinator: contactRequestsCoordinator)
        self.addChildCoordinator(childCoordinator: meCoordinator)

        self.rootViewController.rx.viewDidAppear.take(1).subscribe(onNext: { [unowned self, unowned conversationsCoordinator, unowned contactRequestsCoordinator, unowned meCoordinator] (_) in
            conversationsCoordinator.start()
            contactRequestsCoordinator.start()
            meCoordinator.start()

            // show walkthrough if needed
            if self.injectionBag.accountService.accounts.isEmpty {
                self.stateSubject.onNext(AppState.needToOnboard)
            }
        }).disposed(by: self.disposeBag)
    }

    private func showWalkthrough () {
        let walkthroughCoordinator = WalkthroughCoordinator(with: self.injectionBag)
        self.addChildCoordinator(childCoordinator: walkthroughCoordinator)
        let walkthroughViewController = walkthroughCoordinator.rootViewController
        self.present(viewController: walkthroughViewController, withStyle: .popup, withAnimation: true)
        walkthroughCoordinator.start()

        walkthroughViewController.rx.viewDidDisappear.subscribe(onNext: { [weak self, weak walkthroughCoordinator] (_) in
            walkthroughCoordinator?.stateSubject.dispose()
            self?.removeChildCoordinator(childCoordinator: walkthroughCoordinator)
        }).disposed(by: self.disposeBag)
    }

    private func presentCallScreen(withCallModel call: CallModel) {
        let callCoordinator = CallCoordinator(with: self.injectionBag)
        self.addChildCoordinator(childCoordinator: callCoordinator)
        let callViewController = callCoordinator.rootViewController
        self.present(viewController: callViewController, withStyle: .present, withAnimation: false)
        callCoordinator.displayCallScreen(with: call)
    }

    private func showIncomingCallAlert(withCallModel call: CallModel) {
        let alert = UIAlertController(title: L10n.Alerts.incomingCallAllertTitle + "\(call.displayName)", message:nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        alert.addAction(UIAlertAction(title: L10n.Alerts.incomingCallButtonAccept, style: UIAlertActionStyle.default, handler: { (_) in
            self.presentCallScreen(withCallModel: call)
            self.injectionBag.callsService.accept(call: call).subscribe(onCompleted: {
                self.log.info("Call answered")
            }, onError: { error in
                self.log.error("Failed to answer the call")
            }).disposed(by: self.disposeBag)
            alert.dismiss(animated: true, completion: nil)}))
        alert.addAction(UIAlertAction(title: L10n.Alerts.incomingCallButtonIgnore, style: UIAlertActionStyle.default, handler: { (_) in
            self.injectionBag.callsService.refuse(call: call).subscribe(onCompleted: {
                self.log.info("Call ignored")
            }, onError: { error in
                self.log.error("Failed to ignore the call")
            }).disposed(by: self.disposeBag)
            alert.dismiss(animated: true, completion: nil)}))
        self.present(viewController: alert, withStyle: .present, withAnimation: true)
    }
}
