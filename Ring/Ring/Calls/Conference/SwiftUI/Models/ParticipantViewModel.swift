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
import RxRelay
import RxSwift
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
            let mode = notActiveParticipant ? AVLayerVideoGravity
                .resizeAspectFill : AVLayerVideoGravity.resizeAspect
            setAspectMode(mode: mode)
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

            if info.isModerator != isModerator {
                isModerator = info.isModerator
            }
        }
    }

    let disposeBag = DisposeBag()
    var videoDisposeBag = DisposeBag()
    var id: String

    let videoService: VideoService
    let injectionBag: InjectionBag
    let profileInfo: ParticipantProfileInfo

    init(
        info: ConferenceParticipant,
        injectionBag: InjectionBag,
        conferenceState: PublishSubject<State>,
        mode: AVLayerVideoGravity
    ) {
        id = info.sinkId
        self.injectionBag = injectionBag
        videoService = injectionBag.videoService
        self.conferenceState = conferenceState
        gridDisplayLayer.videoGravity = .resizeAspectFill
        conferenceActions = [ButtonInfoWrapper]()
        profileInfo = ParticipantProfileInfo(injectionBag: injectionBag, info: info)
        setAspectMode(mode: mode)
        profileInfo.avatar
            .observe(on: MainScheduler.instance)
            .startWith(profileInfo.avatar.value)
            .filter { $0 != nil }
            .subscribe(onNext: { [weak self] avatar in
                if let avatar = avatar {
                    self?.avatar = avatar
                }
            })
            .disposed(by: disposeBag)
        profileInfo.displayName
            .observe(on: MainScheduler.instance)
            .startWith(profileInfo.displayName.value)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] name in
                self?.name = name
            })
            .disposed(by: disposeBag)
        subscribe()
    }

    func radians(from degrees: Int) -> CGFloat {
        return CGFloat(degrees) * .pi / 180.0
    }

    var currentRadiants: CGFloat = 0

    func setAspectMode(mode: AVLayerVideoGravity) {
        mainDisplayLayer.videoGravity = mode
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
        videoService.addListener(withsinkId: id)
        if !subscribed {
            subscribed = true
            videoService.videoInputManager.frameSubject
                .filter { [weak self] result in
                    guard let self = self else { return false }
                    return result.sinkId == self.id
                }
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
                            if let container = self.mainDisplayLayer.superlayer?
                                .delegate as? UIView,
                               container.bounds != self.mainDisplayLayer.frame {
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
                .disposed(by: disposeBag)
        }
    }

    func unsubscribe() {
        videoService.removeListener(withsinkId: id)
        if !videoService.hasListener(withsinkId: id) {
            subscribed = false
            videoRunning.accept(false)
            videoDisposeBag = DisposeBag()
        }
    }

    func addItem(item: MenuItem) {
        guard let info = info else { return }
        switch item {
        case .minimize:
            let button = ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "arrow.down.right.and.arrow.up.left",
                action: ParticipantAction.minimize(info: info)
            )
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .maximize:
            let button = ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "arrow.up.left.and.arrow.down.right",
                action: ParticipantAction.maximize(info: info)
            )
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .setModerator:
            let button = isModerator ? ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "crown",
                action: ParticipantAction.setModerator(info: info)
            ) :
            ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "crown.fill",
                action: ParticipantAction.setModerator(info: info)
            )
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .muteAudio:
            var button = audioMuted ? ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "mic.slash",
                action: ParticipantAction.muteAudio(info: info)
            ) :
            ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "mic",
                action: ParticipantAction.muteAudio(info: info)
            )
            button.imageColor = audioMuted ? .red : .white
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .hangup:
            let button = ButtonInfo(
                background: .clear,
                stroke: .clear,
                name: "slash.circle",
                action: ParticipantAction.hangup(info: info)
            )
            conferenceActions.append(ButtonInfoWrapper(info: button))
        case .lowerHand:
            let button =
                ButtonInfo(
                    background: .clear,
                    stroke: .clear,
                    name: "hand.raised",
                    action: ParticipantAction.raseHand(info: info)
                )
            conferenceActions.append(ButtonInfoWrapper(info: button))
        }
    }

    func setActions(items: [MenuItem]) {
        conferenceActions = [ButtonInfoWrapper]()
        for item in items {
            addItem(item: item)
        }
    }

    func perform(action: State) {
        guard let action = action as? ParticipantAction else { return }
        action.performAction(actionsState: conferenceState)
    }
}
