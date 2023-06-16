/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
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
import RxCocoa
import CoreVideo
import AVFoundation

protocol PlayerDelegate: AnyObject {
    func extractedVideoFrame(with height: CGFloat)
}

class PlayerViewModel {

    var hasVideo = BehaviorRelay<Bool>(value: true)
    var playerDuration = BehaviorRelay<Float>(value: 0)
    var playerPosition = PublishSubject<Float>()
    let seekTimeVariable = BehaviorRelay<Float>(value: 0)
    let playBackFrame = PublishSubject<CMSampleBuffer?>()

    let pause = BehaviorRelay<Bool>(value: true)
    let audioMuted = BehaviorRelay<Bool>(value: true)
    let playerReady = BehaviorRelay<Bool>(value: false)
    weak var delegate: PlayerDelegate?

    var firstFrame: CMSampleBuffer?

    private let disposeBag = DisposeBag()
    private var playBackDisposeBag = DisposeBag()

    private let videoService: VideoService
    private let filePath: String
    private var playerId = ""
    private var progressTimer: Timer?

    init(injectionBag: InjectionBag, path: String) {
        self.videoService = injectionBag.videoService
        filePath = path
    }

    func createPlayer() {
        self.playerReady.accept(false)
        let fname = "file://" + filePath
        if !self.playerId.isEmpty {
            if let frame = firstFrame {
                self.playBackFrame.onNext(frame)
            }
            self.playerReady.accept(true)
            return
        }
        invalidateTimer()
        self.playerId = self.videoService.createPlayer(path: fname)
        self.pause.accept(true)
        self.playerPosition.onNext(0)
        // subscribe for frame playback
        // get first frame, pause player and seek back to first frame
        self.playBackDisposeBag = DisposeBag()
        self.incomingFrame.filter {  [weak self] (render) -> Bool in
            render?.rendererId == self?.playerId
        }
        .take(1)
        .map({[weak self] (renderer) -> Observable<RendererTuple?>  in
            self?.firstFrame = renderer?.buffer
            self?.playerPosition.onNext(0)
            self?.toglePause()
            self?.muteAudio()
            self?.seekToTime(time: 0)
            self?.startTimer()
            self?.playerReady.accept(true)
            self?.playBackFrame.onNext(self?.firstFrame)
            if let sampleBuffer = renderer?.buffer,
               let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let imageHeight: CGFloat = CGFloat(CVPixelBufferGetHeight(imageBuffer))
                DispatchQueue.main.async {
                    self?.delegate?.extractedVideoFrame(with: imageHeight)
                }
            }
            return self?.incomingFrame.filter {  [weak self] (render) -> Bool in
                render?.rendererId == self?.playerId
            } ?? Observable.just(renderer)
        })
        .merge()
        .subscribe(onNext: {  [weak self] (renderer) in
            self?.playBackFrame.onNext(renderer?.buffer)
        })
        .disposed(by: self.playBackDisposeBag)

        // subscribe for fileInfo
        self.videoService.playerInfo
            .asObservable()
            .filter {  [weak self] (player) -> Bool in
                player.playerId == self?.playerId
            }
            .take(1)
            .subscribe(onNext: {  [weak self] player in
                guard let duration = Float(player.duration),
                      duration > 0 else {
                    DispatchQueue.main.async {
                        self?.videoService.closePlayer(playerId: self?.playerId ?? "")
                    }
                    return
                }
                self?.playerDuration.accept(duration)
                self?.hasVideo.accept(player.hasVideo)
                if !player.hasVideo {
                    self?.startTimer()
                    self?.audioMuted.accept(false)
                    self?.playerReady.accept(true)
                    return
                }
                // mute audio so it is not played when extracting first frame
                self?.audioMuted.accept(true)
                self?.videoService.mutePlayerAudio(playerId: player.playerId,
                                                   mute: self?.audioMuted.value ?? true)
                // unpause player to get first video frame
                self?.toglePause()
            })
            .disposed(by: self.playBackDisposeBag)
    }

    func userStartSeeking() {
        invalidateTimer()
        if pause.value {
            return
        }
        pause.accept(true)
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
    }

    func userStopSeeking() {
        let time = Int(self.playerDuration.value * seekTimeVariable.value)
        self.videoService.seekToTime(time: time, playerId: playerId)
        pause.accept(false)
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
        startTimer()
    }

    func invalidateTimer() {
        if self.progressTimer != nil {
            self.progressTimer?.invalidate()
        }
        self.progressTimer = nil
    }

    func startTimer() {
        DispatchQueue.main.async {
            self.progressTimer =
                Timer.scheduledTimer(timeInterval: 0.1,
                                     target: self,
                                     selector: #selector(self.updateTimer),
                                     userInfo: nil,
                                     repeats: true)
        }
    }

    func toglePause() {
        pause.accept(!pause.value)
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
    }

    func muteAudio() {
        audioMuted.accept(!audioMuted.value)
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted.value)
    }

    func seekToTime(time: Int) {
        videoService.seekToTime(time: time, playerId: playerId)
    }

    lazy var incomingFrame: Observable<RendererTuple?> = {
        return videoService.incomingVideoFrame.asObservable()
    }()

    var currentTime: Int64 = 0

    @objc
    func updateTimer(timer: Timer) {
        let time = self.videoService.getPlayerPosition(playerId: self.playerId)
        if time < 0 {
            return
        }
        let progress = Float(time) / self.playerDuration.value
        self.playerPosition.onNext(progress)
        // if new time less than previous file is finished
        if time < currentTime {
            pause.accept(true)
            if let image = self.firstFrame {
                self.playBackFrame.onNext(image)
            }
        }
        currentTime = time
    }

    deinit {
        closePlayer()
    }

    func closePlayer() {
        self.invalidateTimer()
        videoService.closePlayer(playerId: playerId)
    }
}
