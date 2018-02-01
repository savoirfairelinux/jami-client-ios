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

/// Represents Conversations navigation state
///
/// - conversationDetail: user want to see a conversation detail
enum ConversationsState: State {
    case conversationDetail(conversationViewModel: ConversationViewModel)
    case startCall(contactRingId: String, userName: String)
    case startAudioCall(contactRingId: String, userName: String)
}

/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: Coordinator, StateableResponsive {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()

    private let navigationViewController = BaseViewController(with: TabBarItemType.chat)
    private let injectionBag: InjectionBag
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

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? ConversationsState else { return }
            switch state {
            case .conversationDetail (let conversationViewModel):
                self.showConversation(withConversationViewModel: conversationViewModel)
            case .startCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name)
            case .startAudioCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name, isAudioOnly: true)
            }
        }).disposed(by: self.disposeBag)
        self.navigationViewController.viewModel = ChatTabBarItemViewModel(with: self.injectionBag)

    }

    func start () {
        let smartListViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
    }

    private func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        conversationViewController.viewModel = conversationViewModel
        self.present(viewController: conversationViewController, withStyle: .show, withAnimation: true, withStateable: conversationViewController.viewModel)
    }

    private func startOutgoingCall(contactRingId: String, userName: String, isAudioOnly: Bool = false) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.placeCall(with: contactRingId, userName: userName, isAudioOnly: isAudioOnly)
        self.present(viewController: callViewController, withStyle: .present, withAnimation: false)
    }

    private func answerIncomingCall(call: CallModel) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        callViewController.viewModel.answerCall()
            .subscribe(onCompleted: { [weak self] in
                self?.present(viewController: callViewController, withStyle: .present, withAnimation: false)
            }).disposed(by: self.disposeBag)
    }

    private func showCallAlert(call: CallModel) {
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
    }
}
