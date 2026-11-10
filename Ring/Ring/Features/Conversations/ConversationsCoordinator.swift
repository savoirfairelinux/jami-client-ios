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
class ConversationsCoordinator: Coordinator, StateableResponsive, ConversationNavigation {
    var presentingVC = [String: Bool]()

    var rootViewController: UIViewController {
        return self.splitNavigator.rootViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?

    let splitNavigator: ConversationSplitNavigator
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

    init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.splitNavigator = ConversationSplitNavigator(makePlaceholder: { UIHostingController(rootView: NoConversationSelectedView()) })

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
                case .conversationRemoved, .swarmCreationCancelled:
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
    }

    func start() {
        let view = SmartListView(injectionBag: self.injectionBag, source: self.conversationsSource)
        let viewController = createHostingVC(view)
        viewController.navigationItem.backButtonDisplayMode = .minimal
        self.splitNavigator.setListRoot(viewController)
        view.stateEmitter.state.take(until: viewController.rx.deallocated)
            .subscribe(onNext: { [weak self] state in
                self?.stateSubject.onNext(state)
            })
            .disposed(by: self.disposeBag)
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
                       let row = self.getRowForId(conversationId: conversationId),
                       let conversationController = self.shownConversationController,
                       conversationController.navigationController?.topViewController === conversationController,
                       conversationController.viewModel.conversation == row.conversation {
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

    private var shownConversationController: ConversationViewController? {
        return splitNavigator.shownDetail as? ConversationViewController
    }

    func showInDetail(_ viewController: UIViewController, animated: Bool) {
        splitNavigator.showInDetail(viewController, animated: animated)
    }

    func pushOntoDetail(_ viewController: UIViewController, animated: Bool) {
        splitNavigator.pushOntoDetail(viewController, animated: animated)
    }

    func revealConversationIfShown(_ conversation: ConversationModel) -> Bool {
        return popToExistingConversation(conversation)
    }
}
// swiftlint:enable cyclomatic_complexity

// MARK: - State
extension ConversationsCoordinator {

    func presentSwarmInfo(swarmInfo: SwarmInfoProtocol) {
        let swiftUIVM = SwarmInfoVM(with: self.injectionBag, swarmInfo: swarmInfo)
        weak var presented: UIViewController?
        let view = SwarmInfoView(viewModel: swiftUIVM) { expanded in
            presented?.navigationController?.navigationBar.tintColor = expanded ? .white : .jami
        }
        let viewController = createHostingVC(view)
        presented = viewController
        let transparentBar = UINavigationBarAppearance()
        transparentBar.configureWithTransparentBackground()
        viewController.navigationItem.standardAppearance = transparentBar
        viewController.navigationItem.compactAppearance = transparentBar
        viewController.navigationItem.scrollEdgeAppearance = transparentBar
        self.navigate(to: viewController, in: .detailStack, animated: true, stateable: view.stateEmitter)
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
        splitNavigator.popToList(animated: false)
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
                                        dismissesItself: false,
                                        onCompletion: { [weak self] migrated in
                                            self?.popToSmartList()
                                            completion?(migrated)
                                        })
        let viewController = createHostingVC(view)
        self.navigate(to: viewController, in: .detail, animated: true, stateable: view.stateEmitter)
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
        guard let conversationVC = self.splitNavigator.detailStack.visibleViewController else { return }

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
        self.navigate(to: aboutJamiController, in: .detail, animated: true)
    }
}

// MARK: - Open conversation
extension ConversationsCoordinator {
    func openConversationFromNotificationFor(participantId: String, accountId: String) {
        self.popToSmartList()
        guard let uriString = JamiURI(schema: URIType.ring, infoHash: participantId).uriString else {
            return
        }
        if let model = getRowForParticipant(jamiId: uriString) {
            self.showConversation(withRow: model, withAnimation: false)
        }
    }

    func openConversationFromNotification(conversationId: String, accountId: String) {
        self.popToSmartList()
        if let model = getRowForId(conversationId: conversationId) {
            self.showConversation(withRow: model, withAnimation: false)
        }
    }

    func openNewConversation(jamiId: String) {
        guard let account = self.accountService.currentAccount else { return }
        let uri = JamiURI(schema: URIType.ring, infoHash: jamiId)
        if let conversation = self.getRowForParticipant(jamiId: jamiId) {
            self.showConversation(withRow: conversation)
            return
        }
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             type: .oneToOne)
        let newConversation = ConversationRowVM(with: self.injectionBag)
        newConversation.conversation = conversation
        self.showConversation(withRow: newConversation)
    }

    func openConversation(conversationId: String, accountId: String, shouldOpenSmarList: Bool, withAnimation: Bool) {
        if shouldOpenSmarList {
            popToSmartList()
        }
        if let model = getRowForId(conversationId: conversationId) {
            self.showConversation(withRow: model, withAnimation: withAnimation)
        }
        if !shouldOpenSmarList {
            splitNavigator.removeFromList(where: ConversationsCoordinator.isSwarmCreation)
        }
    }

    func openConversationFromCall(route: CallConversationRoute) {
        guard let model = row(for: route) else {
            self.popToSmartList()
            return
        }
        if popToExistingConversation(model.conversation) { return }
        self.popToSmartList()
        self.showConversation(withRow: model, withAnimation: true)
    }

    private func row(for route: CallConversationRoute) -> ConversationRowVM? {
        let models = conversationsSource.rows
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

    private static func isSwarmCreation(_ controller: UIViewController) -> Bool {
        if let navigation = controller as? UINavigationController {
            return navigation.viewControllers.first is SwarmCreationViewController
        }
        return controller is SwarmCreationViewController
    }

    private func popToExistingConversation(_ conversationModel: ConversationModel) -> Bool {
        guard let conversationController = self.shownConversationController,
              conversationController.viewModel.conversation == conversationModel,
              self.splitNavigator.reveal(conversationController, animated: true) else {
            return false
        }
        conversationController.becomeFirstResponder()
        return true
    }

    func openConversationFromCall(conversationModel: ConversationModel) {
        if popToExistingConversation(conversationModel) { return }
        self.openConversation(conversationId: conversationModel.id, accountId: conversationModel.accountId, shouldOpenSmarList: true, withAnimation: true)
    }

    func getRowForParticipant(jamiId: String) -> ConversationRowVM? {
        return self.conversationsSource.rows.first(where: { model in
            model.conversation.isCoredialog() && model.conversation.getParticipants().first?.jamiId == jamiId
        })
    }

    func getRowForId(conversationId: String) -> ConversationRowVM? {
        return self.conversationsSource.rows.first(where: { model in
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
        if let conversation = findRowForOutgoingCall(contactRingId: contactRingId, account: account) {
            showConversation(withRow: conversation, withAnimation: false)
        }
    }

    private func findRowForOutgoingCall(contactRingId: String, account: AccountModel) -> ConversationRowVM? {
        if let call = ActiveCall(contactRingId),
           let conversation = getRowForId(conversationId: call.conversationId) {
            return conversation
        }

        if let conversation = getRowForParticipant(jamiId: contactRingId) {
            return conversation
        }

        let swarmId = contactRingId.replacingOccurrences(of: "swarm:", with: "")
        if let conversation = getRowForId(conversationId: swarmId) {
            return conversation
        }

        return nil
    }
}
