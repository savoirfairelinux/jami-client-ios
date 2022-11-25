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
    case contactDetail(conversationViewModel: ConversationModel)
    case qrCode
    case createNewAccount
    case showDialpad(inCall: Bool)
    case showGeneralSettings
    case recordFile(conversation: ConversationModel, audioOnly: Bool)
    case navigateToCall(call: CallModel)
    case showContactPicker(callID: String, contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void))
    case fromCallToConversation(conversation: ConversationViewModel)
    case needAccountMigration(accountId: String)
    case accountModeChanged
    case openFullScreenPreview(parentView: UIViewController, viewModel: PlayerViewModel?, image: UIImage?, initialFrame: CGRect, delegate: PreviewViewControllerDelegate)
    case openIncomingInvitationView(displayName: String, request: RequestModel, parentView: UIViewController, invitationHandeledCB: ((_ conversationId: String) -> Void))
    case openOutgoingInvitationView(displayName: String, alias: String, avatar: Data?, contactJamiId: String, accountId: String, parentView: UIViewController, invitationHandeledCB: ((_ conversationId: String) -> Void))
    case replaceCurrentWithConversationFor(participantUri: String)
    case showAccountSettings
    case accountRemoved
    case needToOnboard
    case returnToSmartList
    case migrateAccount(accountId: String)
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
                case .recordFile(let conversation, let audioOnly):
                    self.openRecordFile(conversation: conversation, audioOnly: audioOnly)
                case .fromCallToConversation(let conversation):
                    self.fromCallToConversation(withConversationViewModel: conversation)
                case .navigateToCall(let call):
                    self.navigateToCall(call: call)
                case .needAccountMigration(let accountId):
                    self.migrateAccount(accountId: accountId)
                case .openFullScreenPreview(let parentView, let viewModel, let image, let initialFrame, let delegate):
                    self.openFullScreenPreview(parentView: parentView, viewModel: viewModel, image: image, initialFrame: initialFrame, delegate: delegate)
                case .openIncomingInvitationView(let displayName, let request, let parentView, let invitationHandeledCB):
                    self.openIncomingInvitationView(displayName: displayName, request: request, parentView: parentView, invitationHandeledCB: invitationHandeledCB)
                case .openOutgoingInvitationView(let displayName, let alias, let avatar, let contactJamiId, let accountId, let parentView, let invitationHandeledCB):
                    self.openOutgoingInvitationView(displayName: displayName, alias: alias, avatar: avatar, contactJamiId: contactJamiId, accountId: accountId, parentView: parentView, invitationHandeledCB: invitationHandeledCB)
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
                     withStyle: .popup,
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

    func openIncomingInvitationView(displayName: String, request: RequestModel, parentView: UIViewController, invitationHandeledCB: @escaping ((_ conversationId: String) -> Void)) {
        let invitationVC = InvitationViewController.instantiate(with: self.injectionBag)
        invitationVC.viewModel.setInfoForRequest(request: request, displayName: displayName, invitationHandeledCB: invitationHandeledCB)
        parentView.addChildController(invitationVC, initialFrame: parentView.view.bounds)
    }

    func openOutgoingInvitationView(displayName: String, alias: String, avatar: Data?, contactJamiId: String, accountId: String, parentView: UIViewController, invitationHandeledCB: @escaping ((_ conversationId: String) -> Void)) {
        let invitationVC = InvitationViewController.instantiate(with: self.injectionBag)
        invitationVC.viewModel.setInfoForSearchResult(contactJamiId: contactJamiId, accountId: accountId, displayName: displayName, alias: alias, avatar: avatar, invitationHandeledCB: invitationHandeledCB)
        parentView.addChildController(invitationVC, initialFrame: parentView.view.bounds)
    }

    func openQRCode () {
        let scanViewController = ScanViewController.instantiate(with: self.injectionBag)
        self.present(viewController: scanViewController,
                     withStyle: .present,
                     withAnimation: true,
                     withStateable: scanViewController.viewModel)
    }

    func presentContactInfo(conversation: ConversationModel) {
        if let flag = self.presentingVC[VCType.contact.rawValue], flag {
            return
        }
        self.presentingVC[VCType.contact.rawValue] = true
        let isSwarmConversation = conversation.type != .nonSwarm

        if isSwarmConversation {
            let swarmInfoViewController = SwarmInfoViewController.instantiate(with: self.injectionBag)
            swarmInfoViewController.viewModel.conversation = BehaviorRelay(value: conversation)
            self.present(viewController: swarmInfoViewController,
                         withStyle: .show,
                         withAnimation: true,
                         withStateable: swarmInfoViewController.viewModel,
                         lockWhilePresenting: VCType.contact.rawValue)
        } else {
            let contactViewController = ContactViewController.instantiate(with: self.injectionBag)
            contactViewController.viewModel.conversation = conversation
            self.present(viewController: contactViewController,
                         withStyle: .show,
                         withAnimation: true,
                         withStateable: contactViewController.viewModel,
                         lockWhilePresenting: VCType.contact.rawValue)
        }
    }

    func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        if let flag = self.presentingVC[VCType.conversation.rawValue], flag {
            return
        }
        self.presentingVC[VCType.conversation.rawValue] = true
        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        conversationViewController.viewModel = conversationViewModel
        self.present(viewController: conversationViewController,
                     withStyle: .show,
                     withAnimation: true,
                     withStateable: conversationViewController.viewModel,
                     lockWhilePresenting: VCType.conversation.rawValue)
    }

    func fromCallToConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        guard let navigationController = self.rootViewController as? UINavigationController else { return }
        let controllers = navigationController.children
        for controller in controllers
        where controller.isKind(of: (ConversationViewController).self) {
            if let conversationController = controller as? ConversationViewController, conversationController.viewModel.conversation.value == conversationViewModel.conversation.value {
                navigationController.popToViewController(conversationController, animated: true)
                conversationController.becomeFirstResponder()
                return
            }
        }
        self.showConversation(withConversationViewModel: conversationViewModel)
    }

    func pushConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.showConversation(withConversationViewModel: conversationViewModel)
        //        if let flag = self.presentingVC[VCType.conversation.rawValue], flag {
        //            return
        //        }
        //        self.presentingVC[VCType.conversation.rawValue] = true
        //        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        //        conversationViewController.viewModel = conversationViewModel
        //        self.present(viewController: conversationViewController,
        //                     withStyle: .push,
        //                     withAnimation: false,
        //                     withStateable: conversationViewController.viewModel,
        //                     lockWhilePresenting: VCType.conversation.rawValue)
    }

    func navigateToCall (call: CallModel) {
        guard let navController = self.rootViewController as? UINavigationController else { return }
        let controllers = navController.children
        for controller in controllers
        where controller.isKind(of: (CallViewController).self) {
            if let callcontroller = controller as? CallViewController, callcontroller.viewModel.call?.callId == call.callId {
                navController.popToViewController(callcontroller, animated: true)
                return
            }
        }
        guard let topController = getTopController(),
              !topController.isKind(of: (CallViewController).self) else {
            return
        }
        topController.dismiss(animated: false, completion: nil)
        let callViewController = CallViewController
            .instantiate(with: self.injectionBag)
        callViewController.viewModel.call = call
        self.present(viewController: callViewController,
                     withStyle: .appear,
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
              !topController.isKind(of: (CallViewController).self) else {
            return
        }
        DispatchQueue.main.async {
            topController.dismiss(animated: false, completion: nil)
            let callViewController = CallViewController.instantiate(with: self.injectionBag)
            callViewController.viewModel.placeCall(with: contactRingId, userName: userName, isAudioOnly: isAudioOnly)
            self.present(viewController: callViewController,
                         withStyle: .appear,
                         withAnimation: false,
                         withStateable: callViewController.viewModel)
        }
    }
}
