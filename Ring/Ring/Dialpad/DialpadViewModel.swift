/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

import Combine
import AudioToolbox
import RxSwift

class DialpadViewModel: ObservableObject, ViewModel, Stateable {
    /// Small asterisk used as the on-screen label for the "*" key, since
    /// the regular "*" doesn't render well at large sizes.
    static let displayStar = "﹡"

    private let stateSubject = PublishSubject<State>()
    var state: Observable<State> { stateSubject.asObservable() }

    private let callService: CallService

    /// The number being composed, shown in the display label.
    @Published var phoneNumber: String = ""

    /// When `true` the dialpad is shown during a call and sends DTMF tones,
    /// otherwise it composes a number and can start a new call.
    var inCallDialpad = false

    /// The place-call button is only relevant when starting a new call.
    var showsCallButton: Bool { !inCallDialpad }

    required init(with injectionBag: InjectionBag) {
        self.callService = injectionBag.callService
    }

    func numberPressed(_ number: String) {
        phoneNumber += number
        if inCallDialpad {
            callService.playDTMF(code: toDTMF(number))
        } else {
            AudioServicesPlaySystemSound(1057)
        }
    }

    func deleteLast() {
        if !phoneNumber.isEmpty {
            phoneNumber.removeLast()
        }
    }

    func startCall() {
        guard !inCallDialpad else { return }
        let name = toDTMF(phoneNumber)
        stateSubject.onNext(ConversationState.startAudioCall(contactRingId: name, userName: name))
    }

    private func toDTMF(_ value: String) -> String {
        value.replacingOccurrences(of: Self.displayStar, with: "*")
    }
}
