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
    case conversationDetail(row: ConversationRowVM)
    case contactDetail(conversationViewModel: ConversationModel)
    case qrCode
    case createSwarm(onCreated: ((_ conversationId: String) -> Void)?)
    case createNewAccount
    case showDialpad(inCall: Bool)
    case recordFile(conversation: ConversationModel, replyingTo: String?, onSend: (OutgoingMessage.Content) -> Void)
    case showContactPicker(callID: String, contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void)?, conversationSelectedCB: ((_ conversaionIds: [String]?) -> Void)?)
    case openConversationFromCall(conversation: ConversationModel)
    case needAccountMigration(accountId: String)
    case accountModeChanged
    case openIncomingInvitationView(displayName: String, request: RequestModel, parentView: UIViewController, invitationHandeledCB: ((_ conversationId: String) -> Void))
    case conversationRemoved
    case needToOnboard
    case migrateAccount(accountId: String, completion: ((Bool) -> Void)?)
    case presentSwarmInfo(swarmInfo: SwarmInfoProtocol)
    case editConversationProfile(conversation: ConversationModel)
    case openNewConversation(jamiId: String)
    case openConversationForConversationId(conversationId: String,
                                           accountId: String,
                                           shouldOpenSmarList: Bool,
                                           withAnimation: Bool)
    case openAboutJami
    case showAccountSettings(account: AccountModel)
    case openCollabDocument(accountId: String,
                            conversationId: String,
                            documentId: String,
                            name: String?)
}

enum ConversationDestination {
    case detail
    case detailStack
}

protocol ConversationNavigation: AnyObject {

    var injectionBag: InjectionBag { get }

    func addLockFlags()

    func showInDetail(_ viewController: UIViewController, animated: Bool)

    func pushOntoDetail(_ viewController: UIViewController, animated: Bool)

    func revealConversationIfShown(_ conversation: ConversationModel) -> Bool
}

extension ConversationNavigation where Self: Coordinator, Self: StateableResponsive {

    func navigate(to viewController: UIViewController,
                  in destination: ConversationDestination,
                  animated: Bool,
                  stateable: Stateable? = nil,
                  lockWhilePresenting lockKey: String? = nil) {
        switch destination {
        case .detail:
            self.showInDetail(viewController, animated: animated)
        case .detailStack:
            self.pushOntoDetail(viewController, animated: animated)
        }
        if let lockKey = lockKey {
            viewController.rx.viewDidLoad
                .subscribe(onNext: { [weak self] _ in
                    self?.presentingVC[lockKey] = false
                }, onError: { [weak self] _ in
                    self?.presentingVC[lockKey] = false
                }, onCompleted: { [weak self] in
                    self?.presentingVC[lockKey] = false
                }, onDisposed: { [weak self] in
                    self?.presentingVC[lockKey] = false
                })
                .disposed(by: self.disposeBag)
        }
        if let stateable = stateable {
            stateable.state.take(until: viewController.rx.deallocated)
                .subscribe(onNext: { [weak self] state in
                    self?.stateSubject.onNext(state)
                })
                .disposed(by: self.disposeBag)
        }
    }

    func callbackPlaceCall() {
        self.stateSubject
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ConversationState else { return }
                switch state {
                case .conversationDetail(let row):
                    self.showConversation(withRow: row)
                case .contactDetail(let conversationModel):
                    self.presentContactInfo(conversation: conversationModel)
                case .qrCode:
                    self.openQRCode()
                case .createSwarm(let onCreated):
                    self.createSwarm(onCreated: onCreated)
                case .recordFile(let conversation, let replyingTo, let onSend):
                    self.openRecordFile(conversation: conversation, replyingTo: replyingTo, onSend: onSend)
                case .needAccountMigration(let accountId):
                    self.migrateAccount(accountId: accountId)
                case .showAccountSettings(let account):
                    self.showAccountSettings(account: account)
                case .openCollabDocument(let accountId, let conversationId, let documentId, let name):
                    self.openCollabDocument(accountId: accountId,
                                            conversationId: conversationId,
                                            documentId: documentId,
                                            name: name)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
    }

    func migrateAccount(accountId: String, completion: ((Bool) -> Void)? = nil) {
        if let parent = self.parentCoordinator as? AppCoordinator {
            parent.stateSubject.onNext(AppState.needAccountMigration(accountId: accountId))
        }
    }

    func openRecordFile(conversation: ConversationModel, replyingTo: String?, onSend: @escaping (OutgoingMessage.Content) -> Void) {
        let viewModel = MediaRecordViewModel(with: self.injectionBag)
        viewModel.conversation = conversation
        viewModel.replyingTo = replyingTo
        viewModel.onSend = onSend
        viewModel.setup()
        let hostingController = createDismissableVC(MediaRecordView(viewModel: viewModel),
                                                    dismissible: viewModel.dismissHandler)
        self.present(viewController: hostingController,
                     withStyle: .overCurrentContext,
                     withAnimation: true,
                     withStateable: viewModel)
    }

    func openQRCode () {
        let scanViewController = ScanViewController.instantiate(with: self.injectionBag)
        self.present(viewController: scanViewController,
                     withStyle: .present,
                     withAnimation: true,
                     withStateable: scanViewController.viewModel)
    }

    func createSwarm(onCreated: ((_ conversationId: String) -> Void)? = nil) {
        let swarmCreationViewController = SwarmCreationViewController.instantiate(with: self.injectionBag)
        swarmCreationViewController.onSwarmCreated = onCreated
        self.navigate(to: swarmCreationViewController,
                      in: .detail,
                      animated: true,
                      stateable: swarmCreationViewController.viewModel)
    }

    func presentContactInfo(conversation: ConversationModel) {
        if let flag = self.presentingVC[VCType.contact.rawValue], flag {
            return
        }
        self.presentingVC[VCType.contact.rawValue] = true
        let contactViewController = ContactViewController.instantiate(with: self.injectionBag)
        contactViewController.viewModel.conversation = conversation
        self.navigate(to: contactViewController,
                      in: .detailStack,
                      animated: true,
                      stateable: contactViewController.viewModel,
                      lockWhilePresenting: VCType.contact.rawValue)
    }

    func showConversation (withRow row: ConversationRowVM, withAnimation: Bool = true) {
        if let flag = self.presentingVC[VCType.conversation.rawValue], flag {
            return
        }
        if self.revealConversationIfShown(row.conversation) { return }
        self.presentingVC[VCType.conversation.rawValue] = true
        let conversationViewModel = ConversationViewModel(with: self.injectionBag, row: row)
        let conversationHostingVC = ConversationViewController(viewModel: conversationViewModel)
        self.navigate(to: conversationHostingVC,
                      in: .detail,
                      animated: withAnimation,
                      stateable: conversationViewModel,
                      lockWhilePresenting: VCType.conversation.rawValue)
    }

    /**
     A document is opened over the conversation it belongs to, not pushed onto
     it: the editor takes the whole screen and the keyboard, and coming back
     has to land on the conversation exactly as it was left.
     */
    func openCollabDocument(accountId: String,
                            conversationId: String,
                            documentId: String,
                            name: String?) {
        let viewModel = CollabEditorViewModel(with: self.injectionBag,
                                              accountId: accountId,
                                              conversationId: conversationId,
                                              documentId: documentId,
                                              name: name)
        let editor = CollabEditorViewController(viewModel: viewModel)
        let navigation = UINavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .fullScreen
        self.present(viewController: navigation,
                     withStyle: .present,
                     withAnimation: true,
                     disposeBag: self.disposeBag)
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

    // In-call presentation is owned by CallScreenPresenter.

    func dismissAllModals(completion: @escaping () -> Void) {
        guard var currentController = UIApplication.shared.windows.first?.rootViewController else {
            completion()
            return
        }

        while let presentedController = currentController.presentedViewController {
            currentController = presentedController
        }

        if currentController != UIApplication.shared.windows.first?.rootViewController {
            currentController.dismiss(animated: false) {
                self.dismissAllModals(completion: completion)
            }
        } else {
            completion()
        }
    }
}
