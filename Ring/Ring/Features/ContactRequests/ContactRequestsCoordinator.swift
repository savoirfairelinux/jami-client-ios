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

import Foundation
import RxSwift

/// This Coordinator drives the Contact Requests navigation
class ContactRequestsCoordinator: Coordinator, StateableResponsive {

    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()

    private let navigationViewController = BaseViewController(with: TabBarItemType.contactRequest)
    private let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let contactService: ContactsService

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.contactService = injectionBag.contactsService
        self.navigationViewController.viewModel = ContactRequestTabBarItemViewModel(with: self.injectionBag)
        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? ConversationsState else { return }
            switch state {
            case .conversationDetail (let conversationViewModel):
                self.showConversation(withConversationViewModel: conversationViewModel)
            }
        }).disposed(by: self.disposeBag)
    }

    func start () {
        let contactRequestsViewController = ContactRequestsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: contactRequestsViewController, withStyle: .show, withAnimation: true, withStateable: contactRequestsViewController.viewModel)
    }

    private func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        let conversationViewController = ConversationViewController.instantiate(with: self.injectionBag)
        conversationViewController.viewModel = conversationViewModel
        self.present(viewController: conversationViewController, withStyle: .show, withAnimation: true)
    }
}
