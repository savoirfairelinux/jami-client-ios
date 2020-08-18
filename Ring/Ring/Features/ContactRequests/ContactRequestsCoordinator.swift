/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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
class ContactRequestsCoordinator: Coordinator, StateableResponsive, ConversationNavigation {

    var presentingVC = [String: Bool]()
    var rootViewController: UIViewController {
        return self.navigationViewController
    }

    var childCoordinators = [Coordinator]()
    var parentCoordinator: Coordinator?

    private let navigationViewController = BaseViewController(with: TabBarItemType.contactRequest)
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()

    let stateSubject = PublishSubject<State>()
    let contactService: ContactsService

    required init (with injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
        self.contactService = injectionBag.contactsService
        self.navigationViewController.viewModel =
            ContactRequestTabBarItem(with: self.injectionBag)
        self.addLockFlags()
        self.callbackPlaceCall()
        self.injectionBag.accountService
            .currentAccountChanged
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[unowned self] _ in
                self.navigationViewController.viewModel =
                    ContactRequestTabBarItem(with: self.injectionBag)
            })
            .disposed(by: self.disposeBag)
    }
    func addLockFlags() {
        presentingVC[VCType.contact.rawValue] = false
        presentingVC[VCType.conversation.rawValue] = false
    }
    func start () {
        let contactRequestsViewController = ContactRequestsViewController.instantiate(with: self.injectionBag)
        self.present(viewController: contactRequestsViewController, withStyle: .show, withAnimation: true, withStateable: contactRequestsViewController.viewModel)
    }
}
