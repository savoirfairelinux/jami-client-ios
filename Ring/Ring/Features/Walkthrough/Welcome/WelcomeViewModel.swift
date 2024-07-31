/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Thibault Wittemberg <thibault.wittemberg@savoirfairelinux.com>
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

import Foundation
import RxSwift
import SwiftUI

class WelcomeViewModel: Stateable, ViewModel, ObservableObject {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let accountService: AccountsService
    private let nameService: NameService
    let injectionBag: InjectionBag

    let disposeBag = DisposeBag()


    // MARK: - Rx Singles for L10n
//    let welcomeText = Observable<String>.of(L10n.Welcome.title)
//    let createAccount = Observable<String>.of(L10n.CreateAccount.createAccountFormTitle)
//    let linkDevice = Observable<String>.of(L10n.Welcome.linkDevice)

    var notCancelable = true

    @Published var creationState: AccountCreationState = .initial

    let nameRegistrationTimeout: CGFloat = 30

    required init (with injectionBag: InjectionBag) {
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
        self.injectionBag = injectionBag
    }

    func proceedWithAccountCreation() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .createAccount))
    }

    func proceedWithLinkDevice() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .linkDevice))
    }

    func cancelWalkthrough() {
        self.stateSubject.onNext(WalkthroughState.walkthroughCanceled)
    }

    func linkToAccountManager() {
        self.stateSubject
            .onNext(WalkthroughState
                        .welcomeDone(withType: .linkToAccountManager))
    }

    func createSipAccount() {
        self.stateSubject
            .onNext(WalkthroughState
                        .welcomeDone(withType: .createSipAccount))
    }

    func openAboutJami() {
        self.stateSubject.onNext(WalkthroughState.aboutJami)
    }

    func finish() {
        self.stateSubject.onNext(WalkthroughState.accountCreated)
    }
}

// MARK: - Create account
extension WelcomeViewModel {
    func createAccount(name: String) {
        self.creationState = .started

        self.accountService
            .addJamiAccount(username: name, password: "", enable: true)
            .subscribe(onNext: { [weak self] account in
                self?.handleAccountCreationSuccess(account, username: name)
            }, onError: { [weak self] error in
                self?.handleAccountCreationError(error)
            })
            .disposed(by: disposeBag)
    }

    private func handleAccountCreationSuccess(_ account: AccountModel, username: String) {
        self.enablePushNotifications()
        if !username.isEmpty {
            self.registerAccountName(for: account, username: username)
        } else {
            self.accountCreated()
        }
    }

    private func handleAccountCreationError(_ error: Error) {
        if let error = error as? AccountCreationError {
            self.setState(state: .error(error: error))
        } else {
            self.setState(state: .error(error: .unknown))
        }
    }

    private func registerAccountName(for account: AccountModel, username: String) {
        let registerName = nameService
            .registerNameObservable(withAccount: account.id,
                                    password: "",
                                    name: username)
            .subscribe(onNext: { [weak self] registered in
                self?.handleNameRegistrationResult(registered)
            }, onError: { [weak self] _ in
                self?.setState(state: .nameNotRegistered)
            })
        registerName.disposed(by: disposeBag)

        DispatchQueue.main.asyncAfter(deadline: .now() + nameRegistrationTimeout) { [weak self] in
            registerName.dispose()
            self?.handleNameRegistrationTimeout()
        }
    }

    private func setState(state: AccountCreationState) {
        if self.creationState == state { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.creationState = state
        }
    }

    private func handleNameRegistrationResult(_ registered: Bool) {
        if registered {
            accountCreated()
        } else {
            self.setState(state: .nameNotRegistered)
        }
    }

    private func handleNameRegistrationTimeout() {
        if !creationState.isCompleted {
            self.setState(state: .timeOut)
        }
    }

    private func accountCreated() {
        self.setState(state: .success)
        DispatchQueue.main.async {
            self.stateSubject
                .onNext(WalkthroughState.accountCreated)
        }
    }

    func enablePushNotifications() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: NotificationName.enablePushNotifications.rawValue), object: nil)
    }
}
