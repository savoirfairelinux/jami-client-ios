/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import Foundation
import RxSwift
import RxCocoa
import os
import SwiftUI

// swiftlint:disable cyclomatic_complexity
/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: RootCoordinator, StateableResponsive, ConversationNavigation {
    var presentingVC = [String: Bool]()

    var rootViewController: UIViewController {
        return self.navigationController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?
    var smartListViewController = UIViewController()

    var navigationController = UINavigationController()
    let injectionBag: InjectionBag
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let callService: CallService
    let accountService: AccountsService
    let conversationService: ConversationsService
    let nameService: NameService
    let requestsService: RequestsService
    let conversationsSource: ConversationDataSource
    private weak var activeCallsController: UIViewController?

    required init(navigationController: UINavigationController, injectionBag: InjectionBag) {
        // we get navigationController from app coordinator, as it main view for the application
        self.navigationController = navigationController
        self.injectionBag = injectionBag

        self.callService = injectionBag.callService
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.conversationService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.conversationsSource = ConversationDataSource(with: injectionBag)
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
                case .showContactPicker(let callID, let contactCallBack, let conversationCallBack):
                    self.showContactPicker(callId: callID, contactSelectedCB: contactCallBack, conversationSelectedCB: conversationCallBack)
                case .conversationRemoved:
                    self.popToSmartList()
                case .needToOnboard:
                    self.needToOnboard()
                case .migrateAccount(let accountId, let completion):
                    self.migrateAccount(accountId: accountId, completion: completion)
                case .openNewConversation(let jamiId):
                    self.openNewConversation(jamiId: jamiId)
                case .openConversationForConversationId(let conversationId,
                                                        let accountId,
                                                        let shouldOpenSmarList,
                                                        let withAnimation):
                    self.openConversation(conversationId: conversationId,
                                          accountId: accountId,
                                          shouldOpenSmarList: shouldOpenSmarList,
                                          withAnimation: withAnimation)
                case .openConversationFromCall(let conversation):
                    self.openConversationFromCall(conversationModel: conversation)
                case .presentSwarmInfo(let swarmInfo):
                    self.presentSwarmInfo(swarmInfo: swarmInfo)
                case .editConversationProfile(let conversation):
                    self.presentConversationProfileEditor(conversation: conversation)
                case .startCall(let contactRingId, let name):
                    self.startOutgoingCall(contactRingId: contactRingId, userName: name)
                case .startAudioCall(let contactRingId, let name):
                    self.startOutgoingCall(contactRingId: contactRingId, userName: name, isAudioOnly: true)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        // Incoming-call presentation is owned by CallScreenPresenter.
        self.callbackPlaceCall()
        self.subscribeToActiveCalls()
        self.navigationController.navigationBar.tintColor = UIColor.jami
    }

    func start() {
        let view = SmartListView(injectionBag: self.injectionBag, source: self.conversationsSource)
        let viewController = createHostingVC(view)
        viewController.navigationItem.backButtonDisplayMode = .minimal
        self.smartListViewController = viewController
        self.present(viewController: viewController, withStyle: .replaceNavigationStack, withAnimation: false, withStateable: view.stateEmitter)
    }

    func subscribeToActiveCalls() {
        self.injectionBag.callService.activeCalls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] accountCalls in
                guard let self = self else { return }
                let hasActiveCalls = accountCalls.values.contains { accountCalls in
                    !accountCalls.incomingNotAcceptedNotIgnoredCalls().isEmpty
                }

                guard hasActiveCalls else {
                    self.dismissActiveCalls()
                    return
                }

                guard self.activeCallsController == nil else { return }

                guard let account = self.accountService.currentAccount, accountCalls.keys.contains(account.id) else {
                    // TODO: show alert for call for another account
                    return
                }

                // Skip showing call alert if the conversation for incoming call is already open
                if accountCalls.count == 1 {
                    if accountCalls.first?.value.incomingNotAcceptedNotIgnoredCalls().count == 1,
                       let conversationId = accountCalls.first?.value.incomingNotAcceptedNotIgnoredCalls().first?.conversationId,
                       let navigationController = self.rootViewController as? UINavigationController,
                       let conversationModel = self.getConversationViewModelForId(conversationId: conversationId),
                       let conversationController = navigationController.topViewController as? ConversationViewController,
                       conversationController.viewModel == conversationModel {
                        return
                    }
                }

                let activeCallsViewModel = ActiveCallsViewModel(
                    injectionBag: self.injectionBag, conversationsSource: self.conversationsSource
                )
                guard !activeCallsViewModel.callsByAccount.isEmpty else { return }

                activeCallsViewModel.onNoRenderableCalls = { [weak self] in
                    self?.dismissActiveCalls()
                }
                let activeCallsView = ActiveCallsView(viewModel: activeCallsViewModel)
                let viewController = self.createHostingVC(activeCallsView)
                viewController.view.backgroundColor = .clear
                self.activeCallsController = viewController

                self.presentFromTopController(viewController: viewController,
                                              style: .overFullScreen,
                                              animation: false,
                                              stateable: activeCallsViewModel)
            })
            .disposed(by: self.disposeBag)
    }

    private func dismissActiveCalls() {
        guard let controller = activeCallsController else { return }
        activeCallsController = nil
        controller.dismiss(animated: false)
    }

    func addLockFlags() {
        presentingVC[VCType.contact.rawValue] = false
        presentingVC[VCType.conversation.rawValue] = false
    }
}
// swiftlint:enable cyclomatic_complexity
// swiftlint:enable type_body_length

// MARK: - State
extension ConversationsCoordinator {

    func presentSwarmInfo(swarmInfo: SwarmInfoProtocol) {
        let swiftUIVM = SwarmInfoVM(with: self.injectionBag, swarmInfo: swarmInfo)
        let view = SwarmInfoView(viewModel: swiftUIVM) { [weak self] expanded in
            self?.navigationController.navigationBar.tintColor = expanded ? .white : .jami
        }
        let viewController = createHostingVC(view)
        let transparentBar = UINavigationBarAppearance()
        transparentBar.configureWithTransparentBackground()
        viewController.navigationItem.standardAppearance = transparentBar
        viewController.navigationItem.compactAppearance = transparentBar
        viewController.navigationItem.scrollEdgeAppearance = transparentBar
        self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: view.stateEmitter)
    }

    func presentConversationProfileEditor(conversation: ConversationModel) {
        let viewModel = ConversationProfileEditorVM(conversation: conversation, injectionBag: injectionBag)
        let view = ConversationProfileEditorView(model: viewModel)
        let viewController = createDismissableVC(view, dismissible: viewModel.dismissHandler)
        self.present(viewController: viewController,
                     withStyle: .present,
                     withAnimation: true,
                     disposeBag: disposeBag)
    }

    func popToSmartList() {
        let viewControllers = navigationController.viewControllers
        if viewControllers.contains(smartListViewController) {
            navigationController.popToViewController(smartListViewController, animated: false)
        }
    }

    func needToOnboard() {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.needToOnboard(animated: false, isFirstAccount: true))
        }
    }

    func migrateAccount(accountId: String, completion: ((Bool) -> Void)?) {
        let view = AccountMigrationView(accountId: accountId,
                                        accountService: injectionBag.accountService,
                                        profileService: injectionBag.profileService,
                                        onCompletion: completion)
        let viewController = createHostingVC(view)
        self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: view.stateEmitter)
    }

    func createNewAccount() {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.addAccount)
        }
    }

    func showDialpad(inCall: Bool) {
        let viewModel = DialpadViewModel(with: self.injectionBag)
        viewModel.inCallDialpad = inCall
        let dialpadViewController = createHostingVC(DialpadView(viewModel: viewModel))

        if !inCall {
            self.present(viewController: dialpadViewController,
                         withStyle: .present,
                         withAnimation: true,
                         withStateable: viewModel)
            return
        }
        // The in-call dialpad is a sheet owned by the call screen itself.
    }

    func showContactPicker(callId: String, contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void)? = nil, conversationSelectedCB: ((_ conversationIds: [String]) -> Void)? = nil) {
        guard let conversationVC = self.navigationController.visibleViewController else { return }

        let viewModel = ContactPickerViewModel(with: self.injectionBag)
        viewModel.type = callId.isEmpty ? .forConversation : .forCall
        viewModel.currentCallId = callId
        viewModel.contactSelectedCB = contactSelectedCB
        viewModel.conversationSelectedCB = conversationSelectedCB
        viewModel.bind()

        let pickerView = ContactPickerView(
            viewModel: viewModel,
            onDismissed: { [weak conversationVC] in
                (conversationVC as? ContactPickerDismissHandler)?.contactPickerDidDismiss()
            }
        )
        let pickerVC = createHostingVC(pickerView)
        pickerVC.modalPresentationStyle = .pageSheet
        conversationVC.present(pickerVC, animated: true)
    }

    func openAboutJami() {
        let aboutJamiController = AboutViewController.instantiate()
        self.present(viewController: aboutJamiController, withStyle: .show, withAnimation: true, disposeBag: self.disposeBag)
    }
}

// MARK: - Open conversation
extension ConversationsCoordinator {
    func openConversationFromNotificationFor(participantId: String, accountId: String) {
        self.popToSmartList()
        guard let uriString = JamiURI(schema: URIType.ring, infoHash: participantId).uriString else {
            return
        }
        if let model = getConversationViewModelForParticipant(jamiId: uriString) {
            reloadAndShowConversation(model)
        }
    }

    func openConversationFromNotification(conversationId: String, accountId: String) {
        self.popToSmartList()
        if let model = getConversationViewModelForId(conversationId: conversationId) {
            reloadAndShowConversation(model)
        }
    }

    private func reloadAndShowConversation(_ model: ConversationViewModel) {
        /*
         Messages will be reloaded. Remove existing messages
         to ensure the message order is correct.
         */
        model.cleanMessages()
        self.showConversation(withConversationViewModel: model, withAnimation: false)
    }

    func openNewConversation(jamiId: String) {
        guard let account = self.accountService.currentAccount else { return }
        let uri = JamiURI(schema: URIType.ring, infoHash: jamiId)
        if let conversation = self.getConversationViewModelForParticipant(jamiId: jamiId) {
            self.showConversation(withConversationViewModel: conversation)
            return
        }
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             type: .oneToOne)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = conversation
        self.showConversation(withConversationViewModel: newConversation)
    }

    func openConversation(conversationId: String, accountId: String, shouldOpenSmarList: Bool, withAnimation: Bool) {
        if shouldOpenSmarList {
            popToSmartList()
        }
        if let model = getConversationViewModelForId(conversationId: conversationId) {
            self.showConversation(withConversationViewModel: model, withAnimation: withAnimation)
        }
        if !shouldOpenSmarList {
            let viewControllers = navigationController.viewControllers
            if let index = viewControllers.firstIndex(where: { $0 is SwarmCreationViewController }) {
                navigationController.viewControllers.remove(at: index)
            }
        }
    }

    func openConversationFromCall(route: CallConversationRoute) {
        guard let model = conversationViewModel(for: route) else {
            self.popToSmartList()
            return
        }
        if popToExistingConversation(model.conversation) { return }
        self.popToSmartList()
        self.showConversation(withConversationViewModel: model, withAnimation: true)
    }

    private func conversationViewModel(for route: CallConversationRoute) -> ConversationViewModel? {
        let models = conversationsSource.conversationViewModels
            .filter { $0.conversation.accountId == route.accountId }
        if let conversationId = route.conversationId, !conversationId.isEmpty {
            return models.first { $0.conversation.id == conversationId }
        }
        let peerHash = self.peerHash(route.peerUri)
        return models.first { model in
            guard model.conversation.isCoredialog(),
                  let participant = model.conversation.getParticipants().first else {
                return false
            }
            return self.peerHash(participant.jamiId) == peerHash
        }
    }

    private func peerHash(_ uri: String) -> String {
        return JamiURI(from: uri).hash ?? uri.filterOutHost()
    }

    private func popToExistingConversation(_ conversationModel: ConversationModel) -> Bool {
        guard let navigationController = self.rootViewController as? UINavigationController else {
            return false
        }
        let controllers = navigationController.children
        for controller in controllers
        where controller.isKind(of: (ConversationViewController).self) {
            if let conversationController = controller as? ConversationViewController, conversationController.viewModel.conversation == conversationModel {
                navigationController.popToViewController(conversationController, animated: true)
                conversationController.becomeFirstResponder()
                return true
            }
        }
        return false
    }

    func openConversationFromCall(conversationModel: ConversationModel) {
        guard self.rootViewController is UINavigationController else { return }
        if popToExistingConversation(conversationModel) { return }
        self.openConversation(conversationId: conversationModel.id, accountId: conversationModel.accountId, shouldOpenSmarList: true, withAnimation: true)
    }

    func getConversationViewModelForParticipant(jamiId: String) -> ConversationViewModel? {
        return self.conversationsSource.conversationViewModels.first(where: { model in
            model.conversation.isCoredialog() && model.conversation.getParticipants().first?.jamiId == jamiId
        })
    }

    func getConversationViewModelForId(conversationId: String) -> ConversationViewModel? {
        return self.conversationsSource.conversationViewModels.first(where: { model in
            model.conversation.id == conversationId
        })
    }
}

// MARK: - Call
extension ConversationsCoordinator {
    // Call presentation lives in CallScreenPresenter; this coordinator only
    // navigates conversations and forwards outgoing-call intents.
    func startOutgoingCall(contactRingId: String, userName: String, isAudioOnly: Bool = false) {
        guard let account = self.injectionBag.accountService.currentAccount else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleOutgoingCall(contactRingId: contactRingId,
                                     userName: userName,
                                     account: account,
                                     isAudioOnly: isAudioOnly)
        }
    }

    private func handleOutgoingCall(contactRingId: String, userName: String, account: AccountModel, isAudioOnly: Bool) {
        dismissAllModals { [weak self] in
            guard let self = self else { return }

            self.popToSmartList()
            self.navigateToConversationIfNeeded(for: contactRingId, account: account)
            self.callService.startOutgoingCall(uri: contactRingId,
                                               account: account,
                                               isAudioOnly: isAudioOnly)
        }
    }

    private func navigateToConversationIfNeeded(for contactRingId: String, account: AccountModel) {
        if let conversation = findConversationForOutgoingCall(contactRingId: contactRingId, account: account) {
            showConversation(withConversationViewModel: conversation, withAnimation: false)
        }
    }

    private func findConversationForOutgoingCall(contactRingId: String, account: AccountModel) -> ConversationViewModel? {
        if let call = ActiveCall(contactRingId),
           let conversation = getConversationViewModelForId(conversationId: call.conversationId) {
            return conversation
        }

        if let conversation = getConversationViewModelForParticipant(jamiId: contactRingId) {
            return conversation
        }

        let swarmId = contactRingId.replacingOccurrences(of: "swarm:", with: "")
        if let conversation = getConversationViewModelForId(conversationId: swarmId) {
            return conversation
        }

        return nil
    }
}
