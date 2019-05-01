/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import RxSwift

/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: Coordinator, StateableResponsive, ConversationNavigation {
    var presentingVC = [String: Bool]()

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?

    private let navigationViewController = BaseViewController(with: TabBarItemType.chat)
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let callService: CallsService
    let accountService: AccountsService
    let conversationService: ConversationsService

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.callService = injectionBag.callService
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.addLockFlags()

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? ConversationState else { return }
            switch state {
            case .createNewAccount:
                self.createNewAccount()
            case .showDialpad(let inCall):
                self.showDialpad(inCall: inCall)
            case .showGeneralSettings:
                self.showGeneralSettings()
            default:
                break
            }
        }).disposed(by: self.disposeBag)

        self.callService.newCall.asObservable()
            .map({ call in
            return call
        }).observeOn(MainScheduler.instance)
            .subscribe(onNext: { (call) in
                self.incomingCall(call: call)
             //self.showCallAlert(call: call)
        }).disposed(by: self.disposeBag)
        self.navigationViewController.viewModel = ChatTabBarItemViewModel(with: self.injectionBag)
        self.callbackPlaceCall()
        NotificationCenter.default.addObserver(self, selector: #selector(self.incomingCall(_:)), name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue), object: nil)

        self.accountService.currentAccountChanged
            .subscribe(onNext: {[unowned self] _ in
                self.navigationViewController.viewModel =
                    ChatTabBarItemViewModel(with: self.injectionBag)
            }).disposed(by: self.disposeBag)
    }

    @objc func incomingCall(_ notification: NSNotification) {
        guard let callid = notification.userInfo?[NotificationUserInfoKeys.callID.rawValue] as? String,
            let call = self.callService.call(callID: callid) else {
                return
        }
        self.answerIncomingCall(call: call)
    }

    func createNewAccount() {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.addAccount)
        }
    }

    func showDialpad(inCall: Bool) {
        let dialpadViewController = DialpadViewController.instantiate(with: self.injectionBag)
        dialpadViewController.viewModel.inCallDialpad = inCall
        if !inCall {
            self.present(viewController: dialpadViewController,
                         withStyle: .present,
                         withAnimation: true,
                         withStateable: dialpadViewController.viewModel)
            return
        }
        if let controller = self.navigationViewController.visibleViewController as? CallViewController {
            controller.present(dialpadViewController, animated: true, completion: nil)
        }
    }

    func showGeneralSettings() {
        let settingsViewController = GeneralSettingsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: settingsViewController, withStyle: .present, withAnimation: true, disposeBag: self.disposeBag)
    }

    func puchConversation(participantId: String) {
        let conversationViewModel = ConversationViewModel(with: self.injectionBag)
        guard let account = accountService.currentAccount else {
            return
        }
        guard let conversation = self.conversationService.findConversation(withRingId: participantId, withAccountId: account.id) else {
            return
        }
        conversationViewModel.conversation = Variable<ConversationModel>(conversation)
        self.pushConversation(withConversationViewModel: conversationViewModel)
    }

    func start () {
        let smartListViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
    }

    func addLockFlags() {
        presentingVC[VCType.contact.rawValue] = false
        presentingVC[VCType.conversation.rawValue] = false
    }

     func answerIncomingCall(call: CallModel) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        callViewController.viewModel.answerCall()
            .subscribe(onCompleted: { [weak self] in
                self?.present(viewController: callViewController,
                             withStyle: .present,
                             withAnimation: false,
                             withStateable: callViewController.viewModel)
            }).disposed(by: self.disposeBag)
    }

    func incomingCall(call: CallModel) {
        guard var topController = UIApplication.shared
            .keyWindow?.rootViewController else {
                return
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        if topController.isKind(of: (CallViewController).self) {
            return
        }
        guard let account = self.accountService
            .getAccount(fromAccountId: call.accountId) else {return}
        if call.callId.isEmpty {
            return
        }
        if UIApplication.shared.applicationState != .active {
            if AccountModelHelper
                .init(withAccount: account).isAccountSip() ||
                !self.accountService.getCurrentProxyState(accountID: account.id) {
                return
            }
            var data = [String: String]()
            data [NotificationUserInfoKeys.name.rawValue] = call.displayName
            data [NotificationUserInfoKeys.callID.rawValue] = call.callId
            let helper = LocalNotificationsHelper()
            helper.presentCallNotification(data: data, callService: self.callService)
            return
        }
        let callViewController = CallViewController
            .instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        topController.present(callViewController, animated: true, completion: nil)
    }

    func showCallForConversation(call: CallModel) {
        let controlles = self.navigationViewController.viewControllers
        for controller in controlles where controller.isKind(of: (CallViewController).self) {
            if let callcontroller = controller as? CallViewController, callcontroller.viewModel.call?.callId == call.callId  {
                self.navigationViewController
                    .present(callcontroller,
                             animated: true,
                             completion: nil)
                return
            }
        }
        self.incomingCall(call: call)
    }

    private func showCallAlert(call: CallModel) {
        guard let account = self.accountService
            .getAccount(fromAccountId: call.accountId) else {return}
        if call.callId.isEmpty {
            return
        }
        if UIApplication.shared.applicationState != .active {
            if AccountModelHelper
                .init(withAccount: account).isAccountSip() ||
                !self.accountService.getCurrentProxyState(accountID: account.id) {
                return
            }
            var data = [String: String]()
            data [NotificationUserInfoKeys.name.rawValue] = call.displayName
            data [NotificationUserInfoKeys.callID.rawValue] = call.callId
            let helper = LocalNotificationsHelper()
            helper.presentCallNotification(data: data, callService: self.callService)
            return
        }
        var accountName = !account.registeredName.isEmpty ?
            account.registeredName : account.type == AccountType.sip ?
                account.username : account.jamiId
        if let accountProfie = self.accountService.getAccountProfile(accountId: account.id), let name = accountProfie.alias,
            !name.isEmpty {
            accountName = name
        }
        let message = accountName.isEmpty ? nil : "To: " + accountName
        let alertStyle = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad) ? UIAlertControllerStyle.alert : UIAlertControllerStyle.actionSheet
        let alert = UIAlertController(title: L10n.Alerts.incomingCallAllertTitle + "\(call.displayName)", message: message, preferredStyle: alertStyle)
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
        self.present(viewController: alert, withStyle: .present, withAnimation: true, disposeBag: self.disposeBag)
        self.callService.currentCall
            .takeUntil(alert.rx.controllerWasDismissed)
            .filter({ currentCall in
            return currentCall.callId == call.callId &&
                (currentCall.state == .over || currentCall.state == .failure)
        }).subscribe(onNext: { _ in
            DispatchQueue.main.async {
                alert.dismiss(animated: true, completion: nil)
            }
        }).disposed(by: self.disposeBag)
    }
}
