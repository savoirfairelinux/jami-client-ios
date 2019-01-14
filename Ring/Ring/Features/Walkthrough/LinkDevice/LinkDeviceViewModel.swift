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

class LinkDeviceViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let accountService: AccountsService
    private let accountCreationState = Variable<AccountCreationState>(.unknown)
    let enableNotificationsTitle = L10n.CreateAccount.enableNotifications
    lazy var createState: Observable<AccountCreationState> = {
        return self.accountCreationState.asObservable()
    }()

    lazy var linkButtonEnabledState: Observable<Bool>  = {
        return self.pin.asObservable().map({ pin in
            return !pin.isEmpty
        })
    }()

    let pin = Variable<String>("")
    let password = Variable<String>("")
    let notificationSwitch = Variable<Bool>(true)
    let disposeBag = DisposeBag()

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService

        let accountCreated = createState.filter { newState in
             return newState == .success
        }

        //Account creation state observer
        self.accountService
            .sharedResponseStream
            .takeUntil(accountCreated)
            .subscribe(onNext: { [unowned self] event in
                if event.getEventInput(ServiceEventInput.registrationState) == Registered {
                    self.accountCreationState.value = .success
                    Observable<Int>.timer(Durations.alertFlashDuration.value, period: nil, scheduler: MainScheduler.instance).subscribe(onNext: { [unowned self] (_) in
                        self.enablePushNotifications(enable: self.notificationSwitch.value)
                        self.stateSubject.onNext(WalkthroughState.deviceLinked)
                    }).disposed(by: self.disposeBag)
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorGeneric {
                    self.accountCreationState.value = .error(error: AccountCreationError.linkError)
                } else if event.getEventInput(ServiceEventInput.registrationState) == ErrorNetwork {
                    self.accountCreationState.value = .error(error: AccountCreationError.network)
                }
            }, onError: { [unowned self] _ in
                self.accountCreationState.value = .error(error: AccountCreationError.unknown)
            }).disposed(by: disposeBag)
    }

    func linkDevice () {
        self.accountCreationState.value = .started
        self.accountService.linkToRingAccount(withPin: self.pin.value,
                                              password: self.password.value,
                                              enable: self.notificationSwitch.value)
    }
    func enablePushNotifications(enable: Bool) {
        if !enable {
            return
        }
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
    }
}
