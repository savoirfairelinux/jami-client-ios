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


/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: Coordinator, StateableResponsive, ConversationNavigation {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()

    private let navigationViewController = BaseViewController(with: TabBarItemType.chat)
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let callService: CallsService

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.callService = injectionBag.callService

        self.callService.newCall.asObservable()
            .map({ call in
            return call
        }).subscribe(onNext: { (call) in
             self.showCallAlert(call: call)
        }).disposed(by: self.disposeBag)
        self.navigationViewController.viewModel = ChatTabBarItemViewModel(with: self.injectionBag)
        self.callbackPlaceCall()
        NotificationCenter.default.addObserver(self, selector: #selector(self.incomingCall(_:)), name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue), object: nil)
    }

    @objc func incomingCall(_ notification: NSNotification) {
        guard let callid = notification.userInfo?[NotificationUserInfoKeys.callID.rawValue] as? String,
            let call = self.callService.call(callID: callid) else {
                return
        }
        self.answerIncomingCall(call: call)
    }

    func start () {
        let smartListViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
    }

     func answerIncomingCall(call: CallModel) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        callViewController.viewModel.answerCall()
            .subscribe(onCompleted: { [weak self] in
                self?.present(viewController: callViewController, withStyle: .present, withAnimation: false)
            }).disposed(by: self.disposeBag)
    }

    private func showCallAlert(call: CallModel) {
        if UIApplication.shared.applicationState != .active && !call.callId.isEmpty {
            var data = [String: String]()
            data [NotificationUserInfoKeys.name.rawValue] = call.participantRingId
            data [NotificationUserInfoKeys.callID.rawValue] = call.callId
            let helper = LocalNotificationsHelper()
            helper.presentCallNotification(data: data, callService: self.callService)
        } else {
            let alertStyle = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad) ? UIAlertControllerStyle.alert : UIAlertControllerStyle.actionSheet
            let alert = UIAlertController(title: L10n.Alerts.incomingCallAllertTitle + "\(call.displayName)", message: nil, preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: L10n.Alerts.incomingCallButtonAccept, style: UIAlertActionStyle.default, handler: { (_) in
                self.answerIncomingCall(call: call)
                alert.dismiss(animated: true, completion: nil)}))
            alert.addAction(UIAlertAction(title: L10n.Alerts.incomingCallButtonIgnore, style: UIAlertActionStyle.default, handler: { (_) in
                self.injectionBag.callService.refuse(callId: call.callId)
                    .subscribe({_ in
                        print("Call ignored")
                    }).disposed(by: self.disposeBag)
                alert.dismiss(animated: true, completion: nil)
            }))
            self.present(viewController: alert, withStyle: .present, withAnimation: true)

            self.callService.currentCall.takeUntil(alert.rx.controllerWasDismissed).filter({ currentCall in
                return currentCall.callId == call.callId &&
                    (currentCall.state == .over || currentCall.state == .failure)
            }).subscribe(onNext: { _ in
                alert.dismiss(animated: true, completion: nil)
            }).disposed(by: self.disposeBag)
        }
    }
}
