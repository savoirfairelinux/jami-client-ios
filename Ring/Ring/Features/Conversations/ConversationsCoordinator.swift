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
import RxCocoa

/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: Coordinator, StateableResponsive, ConversationNavigation {
    var presentingVC = [String: Bool]()

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    var smartListViewController = UIViewController()

    private var navigationViewController = UINavigationController()
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
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ConversationState else { return }
                switch state {
                case .createNewAccount:
                    self.createNewAccount()
                case .showDialpad(let inCall):
                    self.showDialpad(inCall: inCall)
                case .showGeneralSettings:
                    self.showGeneralSettings()
                case .navigateToCall(let call):
                    self.navigateToCall(call: call)
                case .showContactPicker(let callID, let callBack):
                    self.showContactPicker(callId: callID, contactSelectedCB: callBack)
                case .replaceCurrentWithConversationFor(let participantUri):
                    self.replaceCurrentWithConversationFor(participantUri: participantUri)
                case .showAccountSettings:
                    self.showAccountSettings()
                case .accountRemoved:
                    self.popToSmartList()
                case .needToOnboard:
                    self.needToOnboard()
                case .accountModeChanged:
                    self.accountModeChanged()
                case .migrateAccount(let accountId):
                    self.migrateAccount(accountId: accountId)
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
        self.callbackPlaceCall()
    }

    func needToOnboard() {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.needToOnboard(animated: false, isFirstAccount: true))
        }
    }
    func accountModeChanged() {
        self.start()
    }

    func migrateAccount(accountId: String) {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.needAccountMigration(accountId: accountId))
        }
    }

    func showAccountSettings() {
        let meCoordinator = MeCoordinator(with: self.injectionBag)
        meCoordinator.parentCoordinator = self
        meCoordinator.setNavigationController(controller: self.navigationViewController)
        self.addChildCoordinator(childCoordinator: meCoordinator)
        meCoordinator.start()
        self.smartListViewController.rx.viewWillAppear
            .take(1)
            .subscribe(onNext: { [weak self, weak meCoordinator] (_) in
                self?.removeChildCoordinator(childCoordinator: meCoordinator)
        })
        .disposed(by: self.disposeBag)
    }

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
            .reportIncomingCall(account: account, call: call, completion: nil)
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
                topController.dismiss(animated: false, completion: nil)
                self.popToSmartList()
                if account.id != call.accountId {
                    self.accountService.currentAccount = self.accountService.getAccount(fromAccountId: call.accountId)
                }
                self.popToSmartList()
                if let model = self.getConversationViewModel(participantUri: call.paricipantHash()) { self.showConversation(withConversationViewModel: model)
                }
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

    func showContactPicker(callId: String, contactSelectedCB: @escaping ((_ contact: [ConferencableItem]) -> Void)) {
        let contactPickerViewController = ContactPickerViewController.instantiate(with: self.injectionBag)
        contactPickerViewController.type = callId.isEmpty ? .forConversation : .forCall
        contactPickerViewController.viewModel.currentCallId = callId
        contactPickerViewController.viewModel.contactSelectedCB = contactSelectedCB
        if let controller = self.navigationViewController.visibleViewController as? ContactPickerDelegate {
            controller.presentContactPicker(contactPickerVC: contactPickerViewController)
        }
    }

    func showGeneralSettings() {
        let settingsViewController = GeneralSettingsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: settingsViewController, withStyle: .show, withAnimation: true, disposeBag: self.disposeBag)
    }

    func replaceCurrentWithConversationFor(participantUri: String) {
        guard let model = getConversationViewModel(participantUri: participantUri) else { return }
        self.popToSmartList()
        self.showConversation(withConversationViewModel: model)
    }

    func popToSmartList() {
        navigationViewController.popToViewController(smartListViewController, animated: false)
    }

    func pushConversation(participantId: String) {
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
        conversationViewModel.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        self.pushConversation(withConversationViewModel: conversationViewModel)
    }

    func start() {
        let boothMode = self.accountService.boothMode()
        if boothMode {
            let smartViewController = IncognitoSmartListViewController.instantiate(with: self.injectionBag)
            self.present(viewController: smartViewController, withStyle: .show, withAnimation: true, withStateable: smartViewController.viewModel)
            smartListViewController = smartViewController
            return
        }
        let smartViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        let contactRequestsViewController = ContactRequestsViewController.instantiate(with: self.injectionBag)
        contactRequestsViewController.viewModel.state.takeUntil(contactRequestsViewController.rx.deallocated)
                    .subscribe(onNext: { [weak self] (state) in
                        self?.stateSubject.onNext(state)
                    })
                    .disposed(by: self.disposeBag)
        smartViewController.addContactRequestVC(controller: contactRequestsViewController)
        self.present(viewController: smartViewController, withStyle: .show, withAnimation: true, withStateable: smartViewController.viewModel)
        smartListViewController = smartViewController
    }

    func setNavigationController(controller: UINavigationController) {
        navigationViewController = controller
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
}
