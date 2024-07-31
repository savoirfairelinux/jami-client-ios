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
import RxCocoa

class LinkDeviceViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let accountService: AccountsService
    private let contactService: ContactsService
    private let accountCreationState = BehaviorRelay<AccountCreationState>(value: .unknown)
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()

    lazy var linkButtonEnabledState: Observable<Bool> = {
        return self.pin.asObservable().map({ pin in
            return !pin.isEmpty
        })
    }()

    let pin = BehaviorRelay<String>(value: "")
    let password = BehaviorRelay<String>(value: "")
    let disposeBag = DisposeBag()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.contactService = injectionBag.contactsService
    }

    func enablePushNotifications(enable: Bool) {
        if !enable {
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
    }
}
