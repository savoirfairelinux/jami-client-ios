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

class ParticipantViewModel: Identifiable, ObservableObject, Equatable {
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
    var mainDisplayLayer = AVSampleBufferDisplayLayer()
    var gridDisplayLayer = AVSampleBufferDisplayLayer()
    var videoInput: VideoInput?
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

    init(id: String) {
        self.id = id
    }

    convenience init(videoInput: VideoInput, mode: AVLayerVideoGravity) {
        self.init(id: videoInput.renderId)
        self.setVideoInput(videoInput: videoInput, mode: mode)
    }

    func updateSize(videoInput: VideoInput) {
        self.videoInput?.width = videoInput.width
        self.videoInput?.height = videoInput.height
    }

    func setVideoInput(videoInput: VideoInput?, mode: AVLayerVideoGravity) {
        self.videoInput = videoInput
        self.gridDisplayLayer.videoGravity = .resizeAspectFill
        self.setAspectMode(mode: mode)
        disposeBag = DisposeBag()
        if let videoInput = self.videoInput {
            videoInput.frame
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { image in
                    guard let image = image else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.mainDisplayLayer.enqueue(image)
                        self?.gridDisplayLayer.enqueue(image)
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    func setAspectMode(mode: AVLayerVideoGravity) {
        self.mainDisplayLayer.videoGravity = mode
    }

    static func == (lhs: ParticipantViewModel, rhs: ParticipantViewModel) -> Bool {
        return lhs.videoInput?.renderId == rhs.videoInput?.renderId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(videoInput?.renderId)
    }

}
