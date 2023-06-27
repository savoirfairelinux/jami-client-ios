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
    @Published var conferenceActions: [ButtonInfoWrapper]
    @Published var avatar: UIImage?
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
        }
    }
    var disposeBag = DisposeBag()
    let id: String

    let videoService: VideoService
    let injectionBag: InjectionBag
    let profileInfo: ConferenceParticipantViewModel

    init(info: ConferenceParticipant, injectionBag: InjectionBag) {
        self.id = info.sinkId
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.gridDisplayLayer.videoGravity = .resizeAspectFill
        let hangupButton = ButtonInfoWrapper(info: ParticipantAction.hangup.defaultButtonInfo)
        let minimizeButton = ButtonInfoWrapper(info: ParticipantAction.minimize.defaultButtonInfo)
        let maximizeButton = ButtonInfoWrapper(info: ParticipantAction.maximize.defaultButtonInfo)
        let setModeratorButton = ButtonInfoWrapper(info: ParticipantAction.setModerator.defaultButtonInfo)
        let muteAudioButton = ButtonInfoWrapper(info: ParticipantAction.muteAudio.defaultButtonInfo)
        let raseHandButton = ButtonInfoWrapper(info: ParticipantAction.raseHand.defaultButtonInfo)
        conferenceActions = [hangupButton, minimizeButton, maximizeButton, setModeratorButton, muteAudioButton, raseHandButton]
        self.profileInfo = ConferenceParticipantViewModel(injectionBag: injectionBag, info: info)
        self.setAspectMode(mode: .resizeAspect)
        self.profileInfo.avatarObservable
            .compactMap { profileData -> (String, String)? in
                guard let name = profileData.1, !name.isEmpty else { return nil }
                return (profileData.0 ?? "", name)
            }
            .map { imageString, name in
                if let image = imageString.createImage() {
                    return (image, name)
                } else {
                    let avatar = UIImage.createContactAvatar(username: name, size: CGSize(width: 40, height: 40))
                    return (avatar, name)
                }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] avatar, name in
                self?.avatar = avatar
                self?.name = name
            })
            .disposed(by: disposeBag)
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

    var subscribed = false

    func subscribe() {
        self.videoService.addListener(withsinkId: self.id)
        if !subscribed {
            subscribed = true
            self.videoService.videoInputManager.frameSubject
                .filter({ result in
                    result.sinkId == self.id
                })
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] info in
                    guard let self = self else { return }

                    guard let image = info.sampleBuffer else { return }
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
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    func unsubscribe() {
        self.videoService.removeListener(withsinkId: self.id)
        if !self.videoService.hasListener(withsinkId: self.id) {
            subscribed = false
            self.disposeBag = DisposeBag()
        }
    }

    func setActions() {
        self.conferenceActions = [ButtonInfoWrapper]()
    }

}
