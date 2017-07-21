/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

/// Represents Call navigation state
///
/// - calling: present screen for current call
enum CallingState: State {
    case calling(call: CallModel)
}

/// This Coordinator show the call screen
class CallCoordinator: Coordinator, StateableResponsive {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()

    private let navigationViewController = UINavigationController()
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        let showCallScene = self.injectionBag.callsService.currentCall.filter({ call in
            return call.state == .incoming && call.callType == .incoming
                || call.state == .connecting && call.callType == .outgoing
        }).map({ call in
            return call
        })

        showCallScene.subscribe(onNext: { call in
            //Instanciate Call view controller
            self.stateSubject.onNext(CallingState.calling(call: call))
        }).disposed(by: self.disposeBag)

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? CallingState else { return }
            switch state {
            case .calling (let call):
                self.displayCallScreen(with: call)
                break
            }
        }).disposed(by: self.disposeBag)

    }

    func displayCallScreen (with callModel: CallModel) {
        let callController = CallViewController.instantiate(with: self.injectionBag)
        callController.viewModel.call = callModel
        self.present(viewController: callController, withStyle: .present, withAnimation: false, withStateable: callController.viewModel)
        let hideCallScene = self.injectionBag.callsService.currentCall.filter({ call in
            return call.state == .over
        }).map({ _ in
            return
        })
        hideCallScene.subscribe(onNext: { _ in
            self.rootViewController.presentedViewController?.dismiss(animated: false, completion: nil)
            self.rootViewController.dismiss(animated: false, completion: nil)
        }).disposed(by: self.disposeBag)
    }

    func start() {
    }
}
