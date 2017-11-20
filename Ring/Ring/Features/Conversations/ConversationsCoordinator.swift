/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

/// Represents Conversations navigation state
///
/// - conversationDetail: user want to see a conversation detail
enum ConversationsState: State {
    case conversationDetail(conversationViewModel: ConversationViewModel)
}

/// This Coordinator drives the conversation navigation (Smartlist / Conversation detail)
class ConversationsCoordinator: Coordinator, StateableResponsive {

    // MARK: Coordinator
    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()
    // MARK: -

    // MARK: StateableResponsive
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    // MARK: -

    private let navigationViewController = BaseViewController(with: TabBarItemType.chat)
    private let injectionBag: InjectionBag

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag

        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? ConversationsState else { return }
            switch state {
            case .conversationDetail (let conversationViewModel):
                self.showConversation(withConversationViewModel: conversationViewModel)
            }
        }).disposed(by: self.disposeBag)

        self.navigationViewController.viewModel = ChatTabBarItemViewModel(with: self.injectionBag)
    }

    func start () {
        let smartListViewController = SmartlistViewController.instantiate(with: self.injectionBag)
        self.present(viewController: smartListViewController, withStyle: .show, withAnimation: true, withStateable: smartListViewController.viewModel)
    }

    private func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        conversationViewController.viewModel = conversationViewModel
        self.present(viewController: conversationViewController, withStyle: .show, withAnimation: true)
    }
}
