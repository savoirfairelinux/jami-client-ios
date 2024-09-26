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
import os

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable type_body_length
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
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let callService: CallsService
    let accountService: AccountsService
    let conversationService: ConversationsService
    let callsProvider: CallsProviderService
    let nameService: NameService
    let requestsService: RequestsService

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.callService = injectionBag.callService
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.conversationService = injectionBag.conversationsService
        self.callsProvider = injectionBag.callsProvider
        self.requestsService = injectionBag.requestsService
        self.addLockFlags()

        self.stateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ConversationState else { return }
                switch state {
                case .createNewAccount:
                    self.createNewAccount()
                case .showDialpad(let inCall):
                    self.showDialpad(inCall: inCall)
                case .openAboutJami:
                    self.openAboutJami()
                case .navigateToCall(let call):
                    self.navigateToCall(call: call)
                case .showContactPicker(let callID, let contactCallBack, let conversationCallBack):
                    self.showContactPicker(callId: callID, contactSelectedCB: contactCallBack, conversationSelectedCB: conversationCallBack)
                case .accountRemoved:
                    self.popToSmartList()
                case .needToOnboard:
                    self.needToOnboard()
                case .accountModeChanged:
                    self.accountModeChanged()
                case .migrateAccount(let accountId):
                    self.migrateAccount(accountId: accountId)
                case .returnToSmartList:
                    self.popToSmartList()
                case .openConversation(let jamiId):
                    self.openConversation(jamiId: jamiId)
                case .openConversationForConversationId(let conversationId, let accountId, let shouldOpenSmarList):
                    self.openConversation(conversationId: conversationId, accountId: accountId, shouldOpenSmarList: shouldOpenSmarList)
                case .openConversationFromCall(let conversation):
                    self.openConversationFromCall(conversationModel: conversation)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        self.callService.newCall
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { (call) in
                self.showIncomingCall(call: call)
            })
            .disposed(by: self.disposeBag)
        self.callbackPlaceCall()
    }

    func needToOnboard() {
        if let parent = self.parentCoordinator as? AppCoordinator {
            self.navigationViewController.popViewController(animated: false)
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

    func showIncomingCall(call: CallModel) {
        guard let account = self.accountService
                .getAccount(fromAccountId: call.accountId),
              !call.callId.isEmpty else {
            return
        }
        if self.accountService.boothMode() {
            self.callService.refuse(callId: call.callId)
                .subscribe()
                .disposed(by: self.disposeBag)
            return
        }
        callsProvider.sharedResponseStream
            .filter({ [weak call] serviceEvent in
                guard serviceEvent.eventType == .callProviderAnswerCall ||
                        serviceEvent.eventType == .callProviderCancelCall else {
                    return false
                }
                guard let callUUID: String = serviceEvent
                        .getEventInput(ServiceEventInput.callUUID) else {
                    return false
                }
                return callUUID == call?.callUUID.uuidString
            })
            .take(1)
            .subscribe(onNext: { [weak self, weak call] serviceEvent in
                guard let self = self,
                      let call = call else { return }
                if serviceEvent.eventType == ServiceEventType.callProviderAnswerCall {
                    self.presentCallScreen(call: call)
                }
            })
            .disposed(by: self.disposeBag)
        callsProvider.handleIncomingCall(account: account, call: call)
        guard call.getDisplayName() == call.paricipantHash() else { return }
        self.nameService.usernameLookupStatus
            .filter({ [weak call] lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == call?.paricipantHash()
            })
            .asObservable()
            .take(1)
            .subscribe(onNext: { [weak call] lookupNameResponse in
                // if we have a registered name then we should update the value for it
                if let name = lookupNameResponse.name, !name.isEmpty, let call = call {
                    call.registeredName = name
                    self.callsProvider.updateRegisteredName(account: account, call: call)
                }
            })
            .disposed(by: self.disposeBag)
        self.nameService.lookupAddress(withAccount: account.id, nameserver: "", address: call.participantUri.filterOutHost())

    }

    func openConversation(jamiId: String) {
        guard let account = self.accountService.currentAccount else { return }
        let uri = JamiURI(schema: URIType.ring, infoHash: jamiId)
        if let conversation = self.getConversationViewModelForParticipant(jamiId: jamiId) {
            self.showConversation(withConversationViewModel: conversation)
            return
        }
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = conversation
        self.showConversation(withConversationViewModel: newConversation)
    }

    func presentCallScreen(call: CallModel) {
        if let topController = self.getTopController(),
           !topController.isKind(of: (CallViewController).self) {
            topController.dismiss(animated: false, completion: nil)
        }
        self.popToSmartList()
        if self.accountService.currentAccount?.id != call.accountId {
            self.accountService.currentAccount = self.accountService.getAccount(fromAccountId: call.accountId)
        }
        if let model = self.getConversationViewModelForParticipant(jamiId: call.paricipantHash()) {
            self.showConversation(withConversationViewModel: model)
        }
        let controller = CallViewController.instantiate(with: self.injectionBag)
        controller.viewModel.call = call
        self.present(viewController: controller,
                     withStyle: .appear,
                     withAnimation: false,
                     withStateable: controller.viewModel)
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

    func showContactPicker(callId: String, contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void)? = nil, conversationSelectedCB: ((_ conversationIds: [String]) -> Void)? = nil) {
        let contactPickerViewController = ContactPickerViewController.instantiate(with: self.injectionBag)
        contactPickerViewController.type = callId.isEmpty ? .forConversation : .forCall
        contactPickerViewController.viewModel.currentCallId = callId
        contactPickerViewController.viewModel.contactSelectedCB = contactSelectedCB
        contactPickerViewController.viewModel.conversationSelectedCB = conversationSelectedCB
        if let controller = self.navigationViewController.visibleViewController as? ContactPickerDelegate {
            controller.presentContactPicker(contactPickerVC: contactPickerViewController)
        }
    }

    func openAboutJami() {
        let aboutJamiController = AboutViewController.instantiate()
        self.present(viewController: aboutJamiController, withStyle: .show, withAnimation: true, disposeBag: self.disposeBag)
    }

    func popToSmartList() {
        let viewControllers = navigationViewController.viewControllers
        if viewControllers.contains(smartListViewController) {
            navigationViewController.popToViewController(smartListViewController, animated: false)
        }
    }

    func openConversationFromCall(conversationModel: ConversationModel) {
        guard let navigationController = self.rootViewController as? UINavigationController else { return }
        let controllers = navigationController.children
        for controller in controllers
        where controller.isKind(of: (ConversationViewController).self) {
            if let conversationController = controller as? ConversationViewController, conversationController.viewModel.conversation == conversationModel {
                navigationController.popToViewController(conversationController, animated: true)
                conversationController.becomeFirstResponder()
                return
            }
        }
        self.openConversation(conversationId: conversationModel.id, accountId: conversationModel.accountId, shouldOpenSmarList: true)
    }

    func openConversation(conversationId: String, accountId: String, shouldOpenSmarList: Bool) {
        if shouldOpenSmarList {
            popToSmartList()
        }
        if let model = getConversationViewModelForId(conversationId: conversationId) {
            self.showConversation(withConversationViewModel: model)
        }
        if !shouldOpenSmarList {
            let viewControllers = navigationViewController.viewControllers
            if let index = viewControllers.firstIndex(where: { $0 is SwarmCreationViewController }) {
                navigationViewController.viewControllers.remove(at: index)
            }
        }
    }

    func pushConversation(participantId: String) {
        self.popToSmartList()
        guard let account = accountService.currentAccount else {
            return
        }
        guard let uriString = JamiURI(schema: URIType.ring, infoHash: participantId).uriString else {
            return
        }
        if let model = getConversationViewModelForParticipant(jamiId: uriString) {
            self.showConversation(withConversationViewModel: model)
            return
        }
        guard let conversation = self.conversationService.getConversationForParticipant(jamiId: participantId, accontId: account.id) else {
            return
        }
        let conversationViewModel = ConversationViewModel(with: self.injectionBag)
        conversationViewModel.conversation = conversation
        self.showConversation(withConversationViewModel: conversationViewModel)
    }

    func start() {
        let boothMode = self.accountService.boothMode()
        if boothMode {
            let smartViewController = IncognitoSmartListViewController.instantiate(with: self.injectionBag)
            self.present(viewController: smartViewController, withStyle: .show, withAnimation: true, withStateable: smartViewController.viewModel)
            smartListViewController = smartViewController
            return
        }
        //        let smartViewController = SwarmCreationViewController.instantiate(with: self.injectionBag)
        let smartViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartViewController, withStyle: .show, withAnimation: true, withStateable: smartViewController.viewModel)
        smartListViewController = smartViewController
    }

    func setNavigationController(controller: UINavigationController) {
        navigationViewController = controller
    }

    func getConversationViewModelForParticipant(jamiId: String) -> ConversationViewModel? {
        let viewControllers = self.navigationViewController.children
        for controller in viewControllers {
            if let smartController = controller as? SmartlistViewController {
                for model in smartController.viewModel.conversationsModel.conversationViewModels where
                    model.conversation.isCoredialog() && model.conversation.getParticipants().first?.jamiId == jamiId {
                    return model
                }
            }
        }
        return nil
    }

    func getConversationViewModelForId(conversationId: String) -> ConversationViewModel? {
        let viewControllers = self.navigationViewController.children
        for controller in viewControllers {
            if let smartController = controller as? SmartlistViewController {
                for model in smartController.viewModel.conversationsModel.conversationViewModels where
                    model.conversation.id == conversationId {
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
// swiftlint:enable cyclomatic_complexity
// swiftlint:enable type_body_length
