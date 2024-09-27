/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import RxSwift
import RxRelay

enum ConversationState: State {
    case startCall(contactRingId: String, userName: String)
    case startAudioCall(contactRingId: String, userName: String)
    case conversationDetail(conversationViewModel: ConversationViewModel)
    case closeComposingMessage
    case contactDetail(conversationViewModel: ConversationModel)
    case qrCode
    case createSwarm
    case createNewAccount
    case showDialpad(inCall: Bool)
    case recordFile(conversation: ConversationModel, audioOnly: Bool)
    case navigateToCall(call: CallModel)
    case showContactPicker(callID: String, contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void)?, conversationSelectedCB: ((_ conversaionIds: [String]?) -> Void)?)
    case openConversationFromCall(conversation: ConversationModel)
    case needAccountMigration(accountId: String)
    case accountModeChanged
    case openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate)
    case openIncomingInvitationView(displayName: String, request: RequestModel, parentView: UIViewController, invitationHandeledCB: ((_ conversationId: String) -> Void))
    case conversationRemoved
    case needToOnboard
    case migrateAccount(accountId: String)
    case presentSwarmInfo(swarmInfo: SwarmInfoProtocol)
    case openNewConversation(jamiId: String)
    case openConversationForConversationId(conversationId: String,
                                           accountId: String,
                                           shouldOpenSmarList: Bool,
                                           withAnimation: Bool)
    case reopenCall(viewController: CallViewController)
    case openAboutJami
    case compose(model: ConversationsViewModel)
    case showAccountSettings(account: AccountModel)
}

protocol ConversationNavigation: AnyObject {

    var injectionBag: InjectionBag { get }

    func addLockFlags()
}

extension ConversationNavigation where Self: Coordinator, Self: StateableResponsive {

    // swiftlint:disable cyclomatic_complexity
    func callbackPlaceCall() {
        self.stateSubject
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ConversationState else { return }
                switch state {
                case .startCall(let contactRingId, let name):
                    self.startOutgoingCall(contactRingId: contactRingId, userName: name)
                case .startAudioCall(let contactRingId, let name):
                    self.startOutgoingCall(contactRingId: contactRingId, userName: name, isAudioOnly: true)
                case .conversationDetail(let conversationViewModel):
                    self.showConversation(withConversationViewModel: conversationViewModel)
                case .contactDetail(let conversationModel):
                    self.presentContactInfo(conversation: conversationModel)
                case .qrCode:
                    self.openQRCode()
                case .createSwarm:
                    self.createSwarm()
                case .recordFile(let conversation, let audioOnly):
                    self.openRecordFile(conversation: conversation, audioOnly: audioOnly)
                case .navigateToCall(let call):
                    self.navigateToCall(call: call)
                case .needAccountMigration(let accountId):
                    self.migrateAccount(accountId: accountId)
                case .openFullScreenPreview(let parentView, let viewModel, let image, let initialFrame, let delegate):
                    self.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate)
                case .presentSwarmInfo(let swarmInfo):
                    self.presentSwarmInfo(swarmInfo: swarmInfo)
                case .reopenCall(let viewController):
                    self.reopenCall(viewController: viewController)
                case .showAccountSettings(let account):
                    self.showAccountSettings(account: account)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
    }

    func migrateAccount(accountId: String) {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.needAccountMigration(accountId: accountId))
        }
    }

    func openRecordFile(conversation: ConversationModel, audioOnly: Bool) {
        let recordFileViewController = SendFileViewController.instantiate(with: self.injectionBag)
        recordFileViewController.viewModel.conversation = conversation
        recordFileViewController.viewModel.audioOnly = audioOnly
        self.present(viewController: recordFileViewController,
                     withStyle: .overCurrentContext,
                     withAnimation: !audioOnly,
                     withStateable: recordFileViewController.viewModel)
    }

    func openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate) {
        if viewModel == nil && image == nil { return }
        let previewController = PreviewViewController.instantiate(with: self.injectionBag)
        previewController.delegate = delegate
        if let viewModel = viewModel {
            previewController.viewModel.playerViewModel = viewModel
            previewController.type = .player
        } else if let image = image {
            previewController.viewModel.image = image
            previewController.type = .image
        }
        parentView.addChildController(previewController, initialFrame: initialFrame)
        previewController.playerView?.sizeMode = .fullScreen
    }

    func openQRCode () {
        let scanViewController = ScanViewController.instantiate(with: self.injectionBag)
        self.present(viewController: scanViewController,
                     withStyle: .present,
                     withAnimation: true,
                     withStateable: scanViewController.viewModel)
    }

    func createSwarm() {
        let swarmCreationViewController = SwarmCreationViewController.instantiate(with: self.injectionBag)
        self.present(viewController: swarmCreationViewController,
                     withStyle: .show,
                     withAnimation: true,
                     withStateable: swarmCreationViewController.viewModel)
    }

    func presentSwarmInfo(swarmInfo: SwarmInfoProtocol) {
        let swiftUIVM = SwarmInfoVM(with: self.injectionBag, swarmInfo: swarmInfo)
        let view = SwarmInfoView(viewmodel: swiftUIVM)
        let viewController = createHostingVC(view)
        self.present(viewController: viewController, withStyle: .show, withAnimation: true, withStateable: view.viewmodel)
    }

    func presentContactInfo(conversation: ConversationModel) {
        if let flag = self.presentingVC[VCType.contact.rawValue], flag {
            return
        }
        self.presentingVC[VCType.contact.rawValue] = true
        let contactViewController = ContactViewController.instantiate(with: self.injectionBag)
        contactViewController.viewModel.conversation = conversation
        self.present(viewController: contactViewController,
                     withStyle: .show,
                     withAnimation: true,
                     withStateable: contactViewController.viewModel,
                     lockWhilePresenting: VCType.contact.rawValue)
    }

    func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel, withAnimation: Bool = true) {
        if let flag = self.presentingVC[VCType.conversation.rawValue], flag {
            return
        }
        //TODO: move to hosting controller with full implementation in swiftUI
        self.presentingVC[VCType.conversation.rawValue] = true
        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        conversationViewController.viewModel = conversationViewModel
        self.present(viewController: conversationViewController,
                     withStyle: .push,
                     withAnimation: withAnimation,
                     withStateable: conversationViewController.viewModel,
                     lockWhilePresenting: VCType.conversation.rawValue)
    }

    func showAccountSettings(account: AccountModel) {
        let accountCoordinator = SettingsCoordinator(injectionBag: self.injectionBag)
        accountCoordinator.account = account
        accountCoordinator.parentCoordinator = self
        accountCoordinator.start()

        self.addChildCoordinator(childCoordinator: accountCoordinator)
        let settingsController = accountCoordinator.rootViewController
        self.present(viewController: settingsController,
                     withStyle: .fadeInOverFullScreen,
                     withAnimation: true,
                     disposeBag: self.disposeBag)
        settingsController.rx.controllerWasDismissed
            .subscribe(onNext: { [weak self, weak accountCoordinator] (_) in
                self?.removeChildCoordinator(childCoordinator: accountCoordinator)
            })
            .disposed(by: self.disposeBag)
    }

    func reopenCall(viewController: CallViewController) {
        guard let call = viewController.viewModel.call else { return }
        if self.tryPresentCallFromStack(call: call) {
            return
        }
        if !dismissTopCallViewControllerIfNeeded() {
            return
        }
        self.present(viewController: viewController,
                     withStyle: .fadeInOverFullScreen,
                     withAnimation: false,
                     withStateable: viewController.viewModel)
    }

    func tryPresentCallFromStack(call: CallModel) -> Bool {
        guard let navController = self.rootViewController as? UINavigationController else { return false
        }
        let controllers = navController.children
        for controller in controllers
        where controller.isKind(of: (CallViewController).self) {
            if let callController = controller as? CallViewController, callController.viewModel.call?.callId == call.callId {
                navController.popToViewController(callController, animated: true)
                return true
            }
        }
        return false
    }

    func dismissTopCallViewControllerIfNeeded() -> Bool {
        guard let topController = getTopController(),
              !topController.isKind(of: CallViewController.self) else {
            return false
        }
        topController.dismiss(animated: false, completion: nil)
        return true
    }

    func navigateToCall(call: CallModel) {
        if self.tryPresentCallFromStack(call: call) {
            return
        }
        if !dismissTopCallViewControllerIfNeeded() {
            return
        }
        let callViewController = CallViewController
            .instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        self.present(viewController: callViewController,
                     withStyle: .fadeInOverFullScreen,
                     withAnimation: false,
                     withStateable: callViewController.viewModel)
    }

    func getTopController() -> UIViewController? {
        guard var topController = UIApplication.shared
                .keyWindow?.rootViewController else {
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }

    func startOutgoingCall(contactRingId: String, userName: String, isAudioOnly: Bool = false) {
        guard let topController = getTopController(),
              !topController.isKind(of: (CallViewController).self),
              let account = self.injectionBag.accountService.currentAccount else {
            return
        }
        DispatchQueue.main.async {
            topController.dismiss(animated: false, completion: nil)
            let callViewController = CallViewController.instantiate(with: self.injectionBag)
            self.present(viewController: callViewController,
                         withStyle: .fadeInOverFullScreen,
                         withAnimation: false,
                         withStateable: callViewController.viewModel)
            callViewController.viewModel.placeCall(with: contactRingId, userName: userName, account: account, isAudioOnly: isAudioOnly)
        }
    }
}
