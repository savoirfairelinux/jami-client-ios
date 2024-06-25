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
    @Published var disabled = false
    var action: State
    var isSystem = true
    var imageColor = Color.white

    init(info: ButtonInfo) {
        background = info.background
        stroke = info.stroke
        name = info.name
        action = info.action
        isSystem = info.isSystem
        imageColor = info.imageColor
        disabled = info.disabled
    }

    func updateWith(info: ButtonInfo) {
        background = info.background
        stroke = info.stroke
        name = info.name
        action = info.action
        isSystem = info.isSystem
        imageColor = info.imageColor
        disabled = info.disabled
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
    var imageColor = Color.white
    var disabled = false
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
    case raiseHand

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
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "person.fill.badge.plus",
                action: self
            )
        case .switchCamera:
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "arrow.triangle.2.circlepath.camera",
                action: self
            )
        case .toggleSpeaker:
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "speaker.wave.2",
                action: self
            )
        case .openConversation:
            return ButtonInfo(background: .clear, stroke: .white, name: "message", action: self)
        case .showDialpad:
            return ButtonInfo(background: .clear, stroke: .white, name: "dialpad", action: self)
        case .raiseHand:
            return ButtonInfo(background: .clear, stroke: .white, name: "hand.raised", action: self)
        }
    }

    var alterButtonInfo: ButtonInfo {
        switch self {
        case .toggleAudio:
            return ButtonInfo(
                background: Color(UIColor.darkGray),
                stroke: Color(UIColor.darkGray),
                name: "mic.slash",
                action: self
            )
        case .toggleVideo:
            return ButtonInfo(
                background: Color(UIColor.darkGray),
                stroke: Color(UIColor.darkGray),
                name: "video.slash",
                action: self
            )
        case .pauseCall:
            return ButtonInfo(
                background: Color(UIColor.darkGray),
                stroke: Color(UIColor.darkGray),
                name: "play",
                action: self
            )
        case .hangUpCall:
            return ButtonInfo(background: .red, stroke: .red, name: "phone.down", action: self)
        case .addParticipant:
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "person.fill.badge.plus",
                action: self
            )
        case .switchCamera:
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "arrow.triangle.2.circlepath.camera",
                action: self
            )
        case .toggleSpeaker:
            return ButtonInfo(
                background: .clear,
                stroke: .white,
                name: "speaker.wave.3",
                action: self
            )
        case .openConversation:
            return ButtonInfo(background: .clear, stroke: .white, name: "message", action: self)
        case .showDialpad:
            return ButtonInfo(background: .clear, stroke: .white, name: "dialpad", action: self)
        case .raiseHand:
            return ButtonInfo(
                background: Color(UIColor.darkGray),
                stroke: Color(UIColor.darkGray),
                name: "hand.raised",
                action: self
            )
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
    var raiseHandButton: ButtonInfoWrapper?

    let disposeBag = DisposeBag()

    lazy var callPaused: Observable<Bool> = currentCall
        .filter { call in
            call.state == .hold ||
                call.state == .unhold ||
                call.state == .current
        }
        .map { call in
            if call.state == .hold ||
                (call.state == .current && call.peerHolding) {
                return true
            }
            return false
        }

    lazy var callConnecting: Observable<Bool> = currentCall
        .map { call in
            call.state == .ringing ||
                call.state == .connecting
        }

    lazy var videoButtonState: Observable<Bool> = self.currentCall
        .filter { call in
            call.state == .current || call.state == .unknown
        }
        .map { call in
            let audioOnly = call.isAudioOnly
            return call.videoMuted || audioOnly
        }

    lazy var micButtonState: Observable<Bool> = self.currentCall
        .filter { call in
            call.state == .current || call.state == .unknown
        }
        .map { call in
            call.audioMuted
        }

    lazy var speakerButtonState: Observable<Bool> = self.audioService.isOutputToSpeaker
        .asObservable()

    var firstLineButtons: [ButtonInfoWrapper]

    var secondLineButtons: [ButtonInfoWrapper]

    var buttons: [ButtonInfoWrapper]

    init(
        actionsState: PublishSubject<State>,
        currentCall: Observable<CallModel>,
        audioService: AudioService
    ) {
        self.actionsState = actionsState
        self.currentCall = currentCall
        self.audioService = audioService
        micButton = ButtonInfoWrapper(info: CallAction.toggleAudio.defaultButtonInfo)
        videoButton = ButtonInfoWrapper(info: CallAction.toggleVideo.defaultButtonInfo)
        stopCallButton = ButtonInfoWrapper(info: CallAction.hangUpCall.defaultButtonInfo)
        switchCameraButton = ButtonInfoWrapper(info: CallAction.switchCamera.defaultButtonInfo)
        speakerButton = ButtonInfoWrapper(info: CallAction.toggleSpeaker.defaultButtonInfo)
        addParticipantButton = ButtonInfoWrapper(info: CallAction.addParticipant.defaultButtonInfo)
        openConversationtButton = ButtonInfoWrapper(info: CallAction.openConversation
                                                        .defaultButtonInfo)
        pauseCallButton = ButtonInfoWrapper(info: CallAction.pauseCall.defaultButtonInfo)
        micButton.disabled = true
        videoButton.disabled = true
        switchCameraButton.disabled = true
        addParticipantButton.disabled = true
        pauseCallButton.disabled = true
        firstLineButtons = [
            speakerButton,
            micButton,
            stopCallButton,
            switchCameraButton,
            videoButton
        ]
        secondLineButtons = [pauseCallButton, addParticipantButton, openConversationtButton]
        buttons = [
            stopCallButton,
            speakerButton,
            micButton,
            switchCameraButton,
            videoButton,
            pauseCallButton,
            addParticipantButton,
            openConversationtButton
        ]
        micButtonState
            .observe(on: MainScheduler.instance)
            .map {
                $0 ? CallAction.toggleAudio.alterButtonInfo : CallAction.toggleAudio
                    .defaultButtonInfo
            }
            .subscribe(onNext: { [weak self] info in
                self?.micButton.updateWith(info: info)
            })
            .disposed(by: disposeBag)
        videoButtonState
            .observe(on: MainScheduler.instance)
            .map {
                $0 ? CallAction.toggleVideo.alterButtonInfo : CallAction.toggleVideo
                    .defaultButtonInfo
            }
            .subscribe(onNext: { [weak self] info in
                self?.videoButton.updateWith(info: info)
            })
            .disposed(by: disposeBag)
        speakerButtonState
            .observe(on: MainScheduler.instance)
            .map {
                $0 ? CallAction.toggleSpeaker.alterButtonInfo : CallAction.toggleSpeaker
                    .defaultButtonInfo
            }
            .subscribe(onNext: { [weak self] info in
                self?.speakerButton.updateWith(info: info)
            })
            .disposed(by: disposeBag)

        callPaused
            .observe(on: MainScheduler.instance)
            .map {
                $0 ? CallAction.pauseCall.alterButtonInfo : CallAction.pauseCall.defaultButtonInfo
            }
            .subscribe(onNext: { [weak self] info in
                self?.pauseCallButton.updateWith(info: info)
            })
            .disposed(by: disposeBag)

        callConnecting
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] connecting in
                self?.micButton.disabled = connecting
                self?.videoButton.disabled = connecting
                self?.switchCameraButton.disabled = connecting
                self?.addParticipantButton.disabled = connecting
                self?.pauseCallButton.disabled = connecting
            })
            .disposed(by: disposeBag)
    }

    func updateItemRaiseHand(add: Bool) {
        let added = raiseHandButton != nil
        if add == added {
            return
        }
        if add {
            raiseHandButton = ButtonInfoWrapper(info: CallAction.raiseHand.defaultButtonInfo)
            secondLineButtons = [
                pauseCallButton,
                addParticipantButton,
                openConversationtButton,
                raiseHandButton!
            ]
            buttons = [
                stopCallButton,
                speakerButton,
                micButton,
                switchCameraButton,
                videoButton,
                pauseCallButton,
                addParticipantButton,
                openConversationtButton,
                raiseHandButton!
            ]
        } else {
            secondLineButtons = [pauseCallButton, addParticipantButton, openConversationtButton]
            buttons = [
                stopCallButton,
                speakerButton,
                micButton,
                switchCameraButton,
                videoButton,
                pauseCallButton,
                addParticipantButton,
                openConversationtButton
            ]
            raiseHandButton = nil
        }
    }

    func perform(action: State) {
        guard let action = action as? CallAction else { return }
        action.performAction(actionsState: actionsState)
    }
}
