/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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
import UIKit

class DialpadViewModel: ViewModel, Stateable {
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    private let callService: CallsService

    let observableNumber = BehaviorSubject<String>(value: "")

    var inCallDialpad = false

    var playDefaultSound = BehaviorSubject<Bool>(value: false)

    var phoneNumber: String = "" {
        willSet {
            observableNumber.onNext(newValue)
        }
    }

    required init(with injectionBag: InjectionBag) {
        callService = injectionBag.callService
    }

    func numberPressed(number: String) {
        phoneNumber += number
        if inCallDialpad {
            let formatedNumber = number.replacingOccurrences(of: String("﹡"), with: "*")
            callService.playDTMF(code: formatedNumber)
        } else {
            playDefaultSound.onNext(true)
        }
    }

    func startCall() {
        if inCallDialpad {
            return
        }
        let name = phoneNumber.replacingOccurrences(of: String("﹡"), with: "*")
        stateSubject.onNext(ConversationState
                                .startAudioCall(contactRingId: name, userName: name))
    }
}
