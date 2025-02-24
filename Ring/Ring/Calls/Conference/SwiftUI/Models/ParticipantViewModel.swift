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
import RxRelay
import SwiftUI

class ParticipantViewModel: Identifiable, ObservableObject, Equatable, Hashable {
    // published
    var notActiveParticipant: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
        didSet {
            let mode = notActiveParticipant ? AVLayerVideoGravity.resizeAspectFill : AVLayerVideoGravity.resizeAspect
            self.setAspectMode(mode: mode)
        }
    }
    var audioMuted: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    var handRased: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    var voiceActive: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    var name = "" {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    var isVideoMuted: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    var isModerator: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    @Published var conferenceActions: [ButtonInfoWrapper]
    @Published var avatar = UIImage()
    var mainDisplayLayer = AVSampleBufferDisplayLayer()
    var gridDisplayLayer = AVSampleBufferDisplayLayer()
    var info: ConferenceParticipant? {
        didSet {
            guard let info = info else {
                return
            }
            if !info.isActive != notActiveParticipant {
                notActiveParticipant = !info.isActive
            }
            if info.voiceActivity != voiceActive {
                voiceActive = info.voiceActivity
            }

            if info.isHandRaised != handRased {
                handRased = info.isHandRaised
            }

            if info.isAudioMuted != audioMuted {
                audioMuted = info.isAudioMuted
            }

            if info.isVideoMuted != isVideoMuted {
                isVideoMuted = info.isVideoMuted
            }

            if info.isModerator != self.isModerator {
                self.isModerator = info.isModerator
            }
        }
    }
    let disposeBag = DisposeBag()
    var videoDisposeBag = DisposeBag()
    var id: String

    let videoService: VideoService
    let injectionBag: InjectionBag
    let profileInfo: ParticipantProfileInfo

    init(info: ConferenceParticipant, injectionBag: InjectionBag, conferenceState: PublishSubject<State>, mode: AVLayerVideoGravity) {
        self.id = info.sinkId
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.conferenceState = conferenceState
        self.gridDisplayLayer.videoGravity = .resizeAspectFill
        conferenceActions = [ButtonInfoWrapper]()
        self.profileInfo = ParticipantProfileInfo(injectionBag: injectionBag, info: info)
        self.setAspectMode(mode: mode)
        self.profileInfo.avatar
            .observe(on: MainScheduler.instance)
            .startWith(self.profileInfo.avatar.value)
            .filter { $0 != nil }
            .subscribe(onNext: { [weak self] avatar in
                if let avatar = avatar {
                    self?.avatar = avatar
                }
            })
            .disposed(by: disposeBag)
        self.profileInfo.displayName
            .observe(on: MainScheduler.instance)
            .startWith(self.profileInfo.displayName.value)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] name in
                self?.name = name
            })
            .disposed(by: disposeBag)
        self.subscribe()
    }

    func radians(from degrees: Int) -> CGFloat {
        return CGFloat(degrees) * .pi / 180.0
    }

    var currentRadiants: CGFloat = 0

    func setAspectMode(mode: AVLayerVideoGravity) {
        self.mainDisplayLayer.videoGravity = mode
    }

    static func == (lhs: ParticipantViewModel, rhs: ParticipantViewModel) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    deinit {
        self.unsubscribe()
    }

    private let conferenceState: PublishSubject<State>

    var subscribed = false

    var videoRunning = BehaviorRelay<Bool>(value: false)

    func subscribe() {
        self.videoService.addListener(withsinkId: self.id)
        if !subscribed {
            subscribed = true
            self.videoService.videoInputManager.frameSubject
                .filter({ [weak self]  result in
                    guard let self = self else { return false }
                    return result.sinkId == self.id
                })
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] info in
                    guard let self = self else { return }

                    guard let image = info.sampleBuffer else {
                        self.videoRunning.accept(false)
                        return
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let radiansValue = self.radians(from: info.rotation)
                        if self.currentRadiants != radiansValue {
                            self.currentRadiants = radiansValue
                            var transform = CGAffineTransform.identity
                            transform = transform.rotated(by: radiansValue)
                            self.gridDisplayLayer.setAffineTransform(transform)
                            self.mainDisplayLayer.setAffineTransform(transform)
                            if let container = self.mainDisplayLayer.superlayer?.delegate as? UIView, container.bounds != self.mainDisplayLayer.frame {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                self.mainDisplayLayer.frame = container.bounds
                                CATransaction.commit()
                            }
                        }
                        self.mainDisplayLayer.enqueue(image)
                        self.gridDisplayLayer.enqueue(image)
                        self.videoRunning.accept(true)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    func unsubscribe() {
        self.videoService.removeListener(withsinkId: self.id)
        if !self.videoService.hasListener(withsinkId: self.id) {
            subscribed = false
            self.videoRunning.accept(false)
            self.videoDisposeBag = DisposeBag()
        }
    }

    func addItem(item: MenuItem) {
        guard let info = self.info else { return }
        switch item {
        case .minimize:
            let button = ButtonInfo(background: .clear, stroke: .clear, name: "arrow.down.right.and.arrow.up.left", accessibilityLabelValue: L10n.Accessibility.Conference.minimize, action: ParticipantAction.minimize(info: info))
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .maximize:
            let button = ButtonInfo(background: .clear, stroke: .clear, name: "arrow.up.left.and.arrow.down.right", accessibilityLabelValue: L10n.Accessibility.Conference.maximize, action: ParticipantAction.maximize(info: info))
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .setModerator:
            let button = self.isModerator ? ButtonInfo(background: .clear, stroke: .clear, name: "crown", accessibilityLabelValue: L10n.Accessibility.Conference.unsetModerator, action: ParticipantAction.setModerator(info: info)) :
            ButtonInfo(background: .clear, stroke: .clear, name: "crown.fill", accessibilityLabelValue: L10n.Accessibility.Conference.setModerator, action: ParticipantAction.setModerator(info: info))
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .muteAudio:
            var button = self.audioMuted ? ButtonInfo(background: .clear, stroke: .clear, name: "mic.slash", accessibilityLabelValue: L10n.Accessibility.Conference.unmuteAudio, action: ParticipantAction.muteAudio(info: info)) :
            ButtonInfo(background: .clear, stroke: .clear, name: "mic", accessibilityLabelValue: L10n.Accessibility.Conference.muteAudio, action: ParticipantAction.muteAudio(info: info))
            button.imageColor = self.audioMuted ? .red : .white
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .hangup:
            let button = ButtonInfo(background: .clear, stroke: .clear, name: "slash.circle", accessibilityLabelValue: L10n.Accessibility.Conference.hangup, action: ParticipantAction.hangup(info: info))
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .lowerHand:
            let button =
            ButtonInfo(background: .clear, stroke: .clear, name: "hand.raised", accessibilityLabelValue: L10n.Accessibility.Conference.lowerHand, action: ParticipantAction.raseHand(info: info))
            conferenceActions.append(ButtonInfoWrapper(info: button))
        }
    }

    func setActions(items: [MenuItem]) {
        self.conferenceActions = [ButtonInfoWrapper]()
        for item in items {
            self.addItem(item: item)
        }
    }

    func perform(action: State) {
        guard let action = action as? ParticipantAction else { return }
        action.performAction(actionsState: conferenceState)
    }
}
