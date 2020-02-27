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

class WelcomeViewModel: Stateable, ViewModel {

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: - Rx Singles for L10n
    let welcomeText     = Observable<String>.of(L10n.Welcome.title)
    let createAccount   = Observable<String>.of(L10n.Welcome.createAccount)
    let linkDevice      = Observable<String>.of(L10n.Welcome.linkDevice)

    static var count = 0

    var notCancelable = true

    var isAnimatable = true

    required init (with injectionBag: InjectionBag) {
    }

    func proceedWithAccountCreation() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .createAccount))
    }

    func proceedWithLinkDevice() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .linkDevice))
    }

    func cancelWalkthrough() {
        self.stateSubject.onNext(WalkthroughState.profileCreated)
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
}
