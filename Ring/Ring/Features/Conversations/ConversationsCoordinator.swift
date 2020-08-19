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
    let callsProvider: CallsProviderDelegate

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.callService = injectionBag.callService
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.callsProvider = injectionBag.callsProvider
        self.addLockFlags()

        self.stateSubject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] (state) in
                guard let state = state as? ConversationState else { return }
                switch state {
                case .createNewAccount:
                    self.createNewAccount()
                case .showDialpad(let inCall):
                    self.showDialpad(inCall: inCall)
                case .showGeneralSettings:
                    self.showGeneralSettings()
                case .navigateToCall(let call):
                    self.presentCallController(call: call)
                case .showContactPicker(let callID):
                    self.showConferenseableList(callId: callID)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        self.callService.newCall
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { (call) in
                self.showIncomingCall(call: call)
            })
            .disposed(by: self.disposeBag)
        self.navigationViewController.viewModel = ChatTabBarItemViewModel(with: self.injectionBag)
        self.callbackPlaceCall()
        //for iOS version less than 10 support open call from notification
        NotificationCenter.default.addObserver(self, selector: #selector(self.answerIncomingCall(_:)), name: NSNotification.Name(NotificationName.answerCallFromNotifications.rawValue), object: nil)

        self.accountService.currentAccountChanged
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[unowned self] _ in
                self.navigationViewController.viewModel =
                    ChatTabBarItemViewModel(with: self.injectionBag)
            })
            .disposed(by: self.disposeBag)
    }

    // swiftlint:disable cyclomatic_complexity
    func showIncomingCall(call: CallModel) {
        guard let account = self.accountService
            .getAccount(fromAccountId: call.accountId),
            !call.callId.isEmpty else { return }
        if self.accountService.boothMode() {
            self.callService.refuse(callId: call.callId)
                .subscribe()
                .disposed(by: self.disposeBag)
            return
        }
        guard let topController = getTopController(),
            !topController.isKind(of: (CallViewController).self) else {
                return
        }
        let callViewController = CallViewController
            .instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call

        var tempBag = DisposeBag()
        call.callUUID = UUID()
        callsProvider
            .reportIncomingCall(account: account, call: call) { _ in
                // if starting CallKit failed fallback to jami call screen
                if UIApplication.shared.applicationState != .active {
                    if AccountModelHelper
                        .init(withAccount: account).isAccountSip() ||
                        !self.accountService.getCurrentProxyState(accountID: account.id) {
                        return
                    }
                    self.triggerCallNotifications(call: call)
                    return
                }
                if account.id != call.accountId {
                    self.accountService.currentAccount = self.accountService.getAccount(fromAccountId: call.accountId)
                }
                topController.dismiss(animated: false, completion: nil)
                guard let parent = self.parentCoordinator as? AppCoordinator else { return }
                parent.openConversation(participantID: call.participantUri)
                self.present(viewController: callViewController,
                             withStyle: .appear,
                             withAnimation: false,
                             withStateable: callViewController.viewModel)
            }
        callsProvider.sharedResponseStream
            .filter({ serviceEvent in
                if serviceEvent.eventType != ServiceEventType.callProviderAnswerCall {
                    return false
                }
                guard let callUUID: String = serviceEvent
                    .getEventInput(ServiceEventInput.callUUID) else { return false }
                return callUUID == call.callUUID.uuidString
            })
            .subscribe(onNext: { _ in
                self.navigationViewController.popToRootViewController(animated: false)
                if account.id != call.accountId {
                    self.accountService.currentAccount = self.accountService.getAccount(fromAccountId: call.accountId)
                }
                topController.dismiss(animated: false, completion: nil)
                guard let parent = self.parentCoordinator as? AppCoordinator else { return }
                parent.openConversation(participantID: call.participantUri)
                self.present(viewController: callViewController,
                             withStyle: .appear,
                             withAnimation: false,
                             withStateable: callViewController.viewModel)
                tempBag = DisposeBag()
            })
            .disposed(by: tempBag)
        callViewController.viewModel.dismisVC
            .share()
            .subscribe(onNext: { hide in
                if hide {
                    tempBag = DisposeBag()
                }
            })
            .disposed(by: tempBag)
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

    func showConferenseableList(callId: String) {
        let contactPickerViewController = ContactPickerViewController.instantiate(with: self.injectionBag)
        contactPickerViewController.viewModel.currentCallId = callId
        if let controller = self.navigationViewController.visibleViewController as? CallViewController {
            controller.presentContactPicker(contactPickerVC: contactPickerViewController)
        }
    }

    func showGeneralSettings() {
        let settingsViewController = GeneralSettingsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: settingsViewController, withStyle: .present, withAnimation: true, disposeBag: self.disposeBag)
    }

    func puchConversation(participantId: String) {
        guard let account = accountService.currentAccount else {
            return
        }
        guard let uriString = JamiURI(schema: URIType.ring, infoHach: participantId).uriString else {
            return
        }
        if let model = getConversationViewModel(participantUri: uriString) {
            self.pushConversation(withConversationViewModel: model)
            return
        }
        guard let conversation = self.conversationService.findConversation(withUri: uriString, withAccountId: account.id) else {
            return
        }
        let conversationViewModel = ConversationViewModel(with: self.injectionBag)
        conversationViewModel.conversation = Variable<ConversationModel>(conversation)
        self.pushConversation(withConversationViewModel: conversationViewModel)
    }

    func start() {
        self.navigationViewController.viewControllers.removeAll()
        let boothMode = self.accountService.boothMode()
        if boothMode {
            let smartListViewController = IncognitoSmartListViewController.instantiate(with: self.injectionBag)
            self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
            return
        }
        let smartListViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
    }

    func getConversationViewModel(participantUri: String) -> ConversationViewModel? {
        let viewControllers = self.navigationViewController.children
        for controller in viewControllers {
            if let smartController = controller as? SmartlistViewController {
                for model in smartController.viewModel.conversationViewModels where model.conversation.value.participantUri == participantUri {
                    return model
                }
            }
        }
        return nil
    }

    func addLockFlags() {
        presentingVC[VCType.contact.rawValue] = false
        presentingVC[VCType.conversation.rawValue] = false
    }

    //open call controller when button navigate to call pressed

    func triggerCallNotifications(call: CallModel) {
        var data = [String: String]()
        data [NotificationUserInfoKeys.name.rawValue] = call.displayName
        data [NotificationUserInfoKeys.callID.rawValue] = call.callId
        data [NotificationUserInfoKeys.accountID.rawValue] = call.accountId
        let helper = LocalNotificationsHelper()
        helper.presentCallNotification(data: data, callService: self.callService)
    }

// MARK: - iOS 9.3 - 10

    @objc
    func answerIncomingCall(_ notification: NSNotification) {
        guard let callid = notification.userInfo?[NotificationUserInfoKeys.callID.rawValue] as? String,
            let call = self.callService.call(callID: callid) else {
                return
        }
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        callViewController.viewModel.answerCall()
            .subscribe(onCompleted: { [weak self] in
                self?.present(viewController: callViewController,
                              withStyle: .present,
                              withAnimation: false,
                              withStateable: callViewController.viewModel)
            })
            .disposed(by: self.disposeBag)
    }
}
