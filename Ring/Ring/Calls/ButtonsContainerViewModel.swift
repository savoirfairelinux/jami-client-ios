/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

enum CallOptions {
    case none
    case optionsWithoutSpeakerphone
    case optionsWithSpeakerphone
}

class ButtonsContainerViewModel {

    let callService: CallsService
    let audioService: AudioService
    let callID: String
    let disposeBag = DisposeBag()

    let avalaibleCallOptions = BehaviorSubject<CallOptions>(value: .none)
    lazy var observableCallOptions: Observable<CallOptions> = {
        return self.avalaibleCallOptions.asObservable()
    }()

    init(with callService: CallsService, audioService: AudioService, callID: String) {
        self.callService = callService
        self.audioService = audioService
        self.callID = callID
        checkCallOptions()
    }

    private func checkCallOptions() {
        let callIsActive: Observable<Bool> = {
            self.callService.currentCall.filter({ call in
                return call.state == .current && call.callId == self.callID
            }).map({_ in
                return true
            })
        }()
        callIsActive
            .subscribe(onNext: { active in
            if !active {
                return
            }
            if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad {
                self.avalaibleCallOptions.onNext(.optionsWithoutSpeakerphone)
                return
            }
            self.connectToSpeaker()
        }).disposed(by: self.disposeBag)
    }

    private func connectToSpeaker() {
        let speakerIsAvailable: Observable<Bool> = {
            //TODO map to service
            return self.audioService.enableSwitchAudio.map({ (hide)  in
                !hide
            })
        }()
        speakerIsAvailable.subscribe(onNext: { available in
            if available {
                self.avalaibleCallOptions.onNext(.optionsWithSpeakerphone)
                return
            }

            self.avalaibleCallOptions.onNext(.optionsWithoutSpeakerphone)
        }).disposed(by: self.disposeBag)
    }
}
