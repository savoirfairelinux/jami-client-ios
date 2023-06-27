/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

import Foundation
import RxSwift
import SwiftUI

class ButtonInfoWrapper: ObservableObject {
    @Published var background: Color
    @Published var name: String
    @Published var stroke: Color
    var action: State
    var isSystem = true
    var crossed = false
    var imageColor = Color.white

    init(info: ButtonInfo) {
        self.background = info.background
        self.stroke = info.stroke
        self.name = info.name
        self.action = info.action
        self.isSystem = info.isSystem
        self.crossed = info.crossed
        self.imageColor = info.imageColor
    }

    func updateWith(info: ButtonInfo) {
        self.background = info.background
        self.stroke = info.stroke
        self.name = info.name
        self.action = info.action
        self.isSystem = info.isSystem
        self.crossed = info.crossed
        self.imageColor = info.imageColor
    }
}

enum ParticipantAction: State {
    case hangup(info: ConferenceParticipant)
    case minimize(info: ConferenceParticipant)
    case maximize(info: ConferenceParticipant)
    case setModerator(info: ConferenceParticipant)
    case muteAudio(info: ConferenceParticipant)
    case raseHand(info: ConferenceParticipant)

    func performAction(actionsState: PublishSubject<State>) {
        actionsState.onNext(self)
    }
}

struct ButtonInfo {
    var background: Color
    let stroke: Color
    let name: String
    let action: State
    var isSystem = true
    var crossed = false
    var imageColor = Color.white
}

enum CallAction: State {
    case toggleAudio
    case toggleVideo
    case pauseCall
    case hangUpCall
    case addParticipant
    case switchCamera
    case toggleSpeaker
    case openConversation
    case showDialpad

    func performAction(actionsState: PublishSubject<State>) {
        actionsState.onNext(self)
    }

    var defaultButtonInfo: ButtonInfo {
        switch self {
        case .toggleAudio:
            return ButtonInfo(background: .clear, stroke: .white, name: "mic", action: self)
        case .toggleVideo:
            return ButtonInfo(background: .clear, stroke: .white, name: "video", action: self)
        case .pauseCall:
            return ButtonInfo(background: .clear, stroke: .white, name: "pause.fill", action: self)
        case .hangUpCall:
            return ButtonInfo(background: .red, stroke: .red, name: "phone.down", action: self)
        case .addParticipant:
            return ButtonInfo(background: .clear, stroke: .white, name: "person.fill.badge.plus", action: self)
        case .switchCamera:
            return ButtonInfo(background: .clear, stroke: .white, name: "arrow.triangle.2.circlepath.camera", action: self)
        case .toggleSpeaker:
            return ButtonInfo(background: .clear, stroke: .white, name: "speaker.wave.2", action: self)
        case .openConversation:
            return ButtonInfo(background: .clear, stroke: .white, name: "message", action: self)
        case .showDialpad:
            return ButtonInfo(background: .clear, stroke: .white, name: "dialpad", action: self)
        }
    }

    var alterButtonInfo: ButtonInfo {
        switch self {
        case .toggleAudio:
            return ButtonInfo(background: Color(UIColor.darkGray), stroke: Color(UIColor.darkGray), name: "mic.slash", action: self)
        case .toggleVideo:
            return ButtonInfo(background: Color(UIColor.darkGray), stroke: Color(UIColor.darkGray), name: "video.slash", action: self)
        case .pauseCall:
            return ButtonInfo(background: Color(UIColor.darkGray), stroke: Color(UIColor.darkGray), name: "play", action: self)
        case .hangUpCall:
            return ButtonInfo(background: .red, stroke: .red, name: "phone.down", action: self)
        case .addParticipant:
            return ButtonInfo(background: .clear, stroke: .white, name: "person.fill.badge.plus", action: self)
        case .switchCamera:
            return ButtonInfo(background: .clear, stroke: .white, name: "arrow.triangle.2.circlepath.camera", action: self)
        case .toggleSpeaker:
            return ButtonInfo(background: .clear, stroke: .white, name: "speaker.wave.3", action: self)
        case .openConversation:
            return ButtonInfo(background: .clear, stroke: .white, name: "message", action: self)
        case .showDialpad:
            return ButtonInfo(background: .clear, stroke: .white, name: "dialpad", action: self)
        }
    }
}

class ActionsViewModel {
    private let actionsState: PublishSubject<State>
    private let currentCall: Observable<CallModel>
    private let audioService: AudioService

    let micButton: ButtonInfoWrapper
    let videoButton: ButtonInfoWrapper
    let stopCallButton: ButtonInfoWrapper
    let switchCameraButton: ButtonInfoWrapper
    let speakerButton: ButtonInfoWrapper
    let addParticipantButton: ButtonInfoWrapper
    let openConversationtButton: ButtonInfoWrapper
    let pauseCallButton: ButtonInfoWrapper
    var dialpadButton: ButtonInfoWrapper?

    let disposeBag = DisposeBag()

    lazy var callPaused: Observable<Bool> = {
        return currentCall
            .filter({ call in
                (call.state == .hold ||
                    call.state == .unhold ||
                    call.state == .current)
            })
            .map({call in
                if  call.state == .hold ||
                        (call.state == .current && call.peerHolding) {
                    return true
                }
                return false
            })
    }()

    lazy var videoButtonState: Observable<Bool> = {
        return self.currentCall
            .filter({ call in
                call.state == .current
            })
            .map({call in
                let audioOnly = call.isAudioOnly
                return call.videoMuted || audioOnly
            })
    }()

    lazy var micButtonState: Observable<Bool> = {
        return self.currentCall
            .filter({ call in
                call.state == .current
            })
            .map({call in
                return call.audioMuted
            })
    }()

    lazy var speakerButtonState: Observable<Bool> = {
        return self.audioService.isOutputToSpeaker.asObservable()
    }()

    var firstLineButtons: [ButtonInfoWrapper]

    var secondLineButtons: [ButtonInfoWrapper]

    var buttons: [ButtonInfoWrapper]

    init(actionsState: PublishSubject<State>, currentCall: Observable<CallModel>, audioService: AudioService) {
        self.actionsState = actionsState
        self.currentCall = currentCall
        self.audioService = audioService
        self.micButton = ButtonInfoWrapper(info: CallAction.toggleAudio.defaultButtonInfo)
        self.videoButton = ButtonInfoWrapper(info: CallAction.toggleVideo.defaultButtonInfo)
        self.stopCallButton = ButtonInfoWrapper(info: CallAction.hangUpCall.defaultButtonInfo)
        self.switchCameraButton = ButtonInfoWrapper(info: CallAction.switchCamera.defaultButtonInfo)
        self.speakerButton = ButtonInfoWrapper(info: CallAction.toggleSpeaker.defaultButtonInfo)
        self.addParticipantButton = ButtonInfoWrapper(info: CallAction.addParticipant.defaultButtonInfo)
        self.openConversationtButton = ButtonInfoWrapper(info: CallAction.openConversation.defaultButtonInfo)
        self.pauseCallButton = ButtonInfoWrapper(info: CallAction.pauseCall.defaultButtonInfo)
        self.firstLineButtons = [speakerButton, micButton, stopCallButton, switchCameraButton, videoButton]
        self.secondLineButtons = [pauseCallButton, addParticipantButton, openConversationtButton]
        self.buttons = [stopCallButton, speakerButton, micButton, switchCameraButton, videoButton, pauseCallButton, addParticipantButton, openConversationtButton]
        self.micButtonState
            .observe(on: MainScheduler.instance)
            .map { $0 ? CallAction.toggleAudio.alterButtonInfo : CallAction.toggleAudio.defaultButtonInfo }
            .subscribe(onNext: { [weak self] info in
                self?.micButton.updateWith(info: info)
            })
            .disposed(by: self.disposeBag)
        self.videoButtonState
            .observe(on: MainScheduler.instance)
            .map { $0 ? CallAction.toggleVideo.alterButtonInfo : CallAction.toggleVideo.defaultButtonInfo }
            .subscribe(onNext: { [weak self] info in
                self?.videoButton.updateWith(info: info)
            })
            .disposed(by: self.disposeBag)
        self.speakerButtonState
            .observe(on: MainScheduler.instance)
            .map { $0 ? CallAction.toggleSpeaker.alterButtonInfo : CallAction.toggleSpeaker.defaultButtonInfo }
            .subscribe(onNext: { [weak self] info in
                self?.speakerButton.updateWith(info: info)
            })
            .disposed(by: self.disposeBag)

        self.callPaused
            .observe(on: MainScheduler.instance)
            .map { $0 ? CallAction.pauseCall.alterButtonInfo : CallAction.pauseCall.defaultButtonInfo }
            .subscribe(onNext: { [weak self] info in
                self?.pauseCallButton.updateWith(info: info)
            })
            .disposed(by: self.disposeBag)
    }

    func perform(action: State) {
        guard let action = action as? CallAction else { return }
        action.performAction(actionsState: actionsState)
    }

}
