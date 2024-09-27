/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

class ComposeNewMessageCoordinator: Coordinator, StateableResponsive, ConversationNavigation {
    var rootViewController: UIViewController {
        return self.navigationController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?

    var navigationController = UINavigationController()
    let injectionBag: InjectionBag
    var disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    var conversationsSource: ConversationDataSource!

    required init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.stateSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self,
                      let state = state as? ConversationState else { return }
                switch state {
                case .closeComposingMessage:
                    self.finish()
                case .openConversationForConversationId(let conversationId,
                                                        let accountId,
                                                        let shouldOpenSmarList,
                                                        let withAnimation):
                    self.openConversation(conversationId: conversationId,
                                          accountId: accountId,
                                          shouldOpenSmarList: shouldOpenSmarList,
                                          withAnimation: withAnimation)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)
        self.callbackPlaceCall()
    }

    func start() {
        let view = NewMessageView(injectionBag: self.injectionBag, source: self.conversationsSource)
        let viewController = createHostingVC(view)
        self.present(viewController: viewController,
                     withStyle: .show,
                     withAnimation: true,
                     withStateable: view.stateEmitter)
    }

    func finish(withAnimation: Bool = true) {
        self.navigationController.setViewControllers([], animated: false)
        self.rootViewController.dismiss(animated: withAnimation)
    }

    func openConversation(conversationId: String, accountId: String, shouldOpenSmarList: Bool, withAnimation: Bool) {
        if let parent = self.parentCoordinator as? ConversationsCoordinator {
            let state = ConversationState
                .openConversationForConversationId(conversationId: conversationId,
                                                   accountId: accountId,
                                                   shouldOpenSmarList: shouldOpenSmarList,
                                                   withAnimation: withAnimation)
            parent.stateSubject.onNext(state)
        }
        self.finish(withAnimation: false)
    }

    // MARK: - ConversationNavigation
    var presentingVC = [String: Bool]()

    func addLockFlags() {}
}
