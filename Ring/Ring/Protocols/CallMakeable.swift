/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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

enum PlaceCallState: State {
    case startCall(contactRingId: String, userName: String)
    case startAudioCall(contactRingId: String, userName: String)
}

protocol CallMakeable: class {

    var injectionBag: InjectionBag { get }
}

extension CallMakeable where Self: Coordinator, Self: StateableResponsive {

     func callbackPlaceCall() {
        self.stateSubject.subscribe(onNext: { [unowned self] (state) in
            guard let state = state as? PlaceCallState else { return }
            switch state {
            case .startCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name)
            case .startAudioCall(let contactRingId, let name):
                self.startOutgoingCall(contactRingId: contactRingId, userName: name, isAudioOnly: true)
            }
        }).disposed(by: self.disposeBag)

    }

    func startOutgoingCall(contactRingId: String, userName: String, isAudioOnly: Bool = false) {
        let callViewController = CallViewController.instantiate(with: self.injectionBag)
        callViewController.viewModel.placeCall(with: contactRingId, userName: userName, isAudioOnly: isAudioOnly)
        self.present(viewController: callViewController, withStyle: .present, withAnimation: false)
    }
}
