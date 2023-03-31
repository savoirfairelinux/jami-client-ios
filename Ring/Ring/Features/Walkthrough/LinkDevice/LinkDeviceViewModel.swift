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
    let enableNotificationsTitle = L10n.CreateAccount.enableNotifications
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
    let notificationSwitch = BehaviorRelay<Bool>(value: true)
    let disposeBag = DisposeBag()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.contactService = injectionBag.contactsService
    }

    func linkDevice () {
        self.accountCreationState.accept(.started)
        self.accountService
            .linkToJamiAccount(withPin: self.pin.value,
                               password: self.password.value,
                               enable: self.notificationSwitch.value)
            .subscribe(onNext: { [weak self] (account) in
                guard let self = self else { return }
                self.accountCreationState.accept(.success)
                Observable<Int>.timer(Durations.alertFlashDuration.toTimeInterval(),
                                      period: nil,
                                      scheduler: MainScheduler.instance)
                    .subscribe(onNext: { [weak self] (_) in
                        guard let self = self else { return }
                        self.accountService.currentAccount = account
                        UserDefaults.standard
                            .set(account.id, forKey: self.accountService.selectedAccountID)
                        self.enablePushNotifications(enable: self.notificationSwitch.value)
                        self.stateSubject.onNext(WalkthroughState.deviceLinked)
                    })
                    .disposed(by: self.disposeBag)
            }, onError: { [weak self] (error) in
                if let error = error as? AccountCreationError {
                    self?.accountCreationState.accept(.error(error: error))
                } else {
                    self?.accountCreationState.accept(.error(error: AccountCreationError.unknown))
                }
            })
            .disposed(by: self.disposeBag)
    }
    func enablePushNotifications(enable: Bool) {
        if !enable {
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
    }
}
