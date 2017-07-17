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

class WelcomeViewModel: Stateable {

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    let welcomeTitle    = Observable<String>.of(L10n.Welcome.title.smartString)
    let welcomeText     = Observable<String>.of(L10n.Welcome.text.smartString)
    let createAccount   = Observable<String>.of(L10n.Welcome.createAccount.smartString)
    let linkDevice      = Observable<String>.of(L10n.Welcome.linkDevice.smartString)

    init () {
    }

    func proceedWithAccountCreation() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .createAccount))
    }

    func proceedWithLinkDevice() {
        self.stateSubject.onNext(WalkthroughState.welcomeDone(withType: .linkDevice))
    }
}
