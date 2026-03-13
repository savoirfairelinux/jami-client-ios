/*
 * Copyright (C) 2020-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import RxSwift
import RxCocoa
import CoreVideo
import AVFoundation

protocol PlayerDelegate: AnyObject {
    func extractedVideoFrame(with height: CGFloat)
}

// MARK: - Player State

enum PlayerState: Equatable {
    case idle
    case extractingFirstFrame
    case ready
    case playing
    case seeking(wasPlaying: Bool)
    case finished
}

class PlayerViewModel {

    // MARK: - Public Rx interface

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

    // MARK: - Private state

    private let disposeBag = DisposeBag()
    private var playBackDisposeBag = DisposeBag()

    private let videoService: VideoService
    private let filePath: String
    private var playerId = ""
    private var progressTimer: Timer?

    private var state: PlayerState = .idle
    private var currentTime: Int64 = 0
    private var endDetectionCount: Int = 0
    private let endThreshold: Float = 0.95

    // MARK: - Init

    init(injectionBag: InjectionBag, path: String) {
        self.videoService = injectionBag.videoService
        filePath = path
    }

    // MARK: - State Machine

    private func transition(to newState: PlayerState) {
        state = newState
        switch newState {
        case .idle:
            invalidateTimer()
            pause.accept(true)

        case .extractingFirstFrame:
            // Unpause daemon to produce video frames.
            // Keep `pause` relay true so UI shows paused state during extraction.
            videoService.pausePlayer(playerId: playerId, pause: false)

        case .ready:
            invalidateTimer()
            pause.accept(true)
            videoService.pausePlayer(playerId: playerId, pause: true)

        case .playing:
            endDetectionCount = 0
            currentTime = 0
            pause.accept(false)
            videoService.pausePlayer(playerId: playerId, pause: false)
            startTimer()

        case .seeking:
            invalidateTimer()
            if !pause.value {
                pause.accept(true)
                videoService.pausePlayer(playerId: playerId, pause: true)
            }

        case .finished:
            invalidateTimer()
            pause.accept(true)
            videoService.pausePlayer(playerId: playerId, pause: true)
            playerPosition.onNext(0)
            if let frame = firstFrame {
                playBackFrame.onNext(frame)
            }
        }
    }

    // MARK: - Public API

    func createPlayer() {
        playerReady.accept(false)
        let fname = "file://" + filePath

        // Re-entry: player already exists, just re-emit first frame
        if !playerId.isEmpty {
            if let frame = firstFrame {
                playBackFrame.onNext(frame)
            }
            playerReady.accept(true)
            return
        }

        transition(to: .idle)
        playerId = videoService.createPlayer(path: fname)
        playerPosition.onNext(0)

        playBackDisposeBag = DisposeBag()
        let playerFrames = incomingFrame
            .filter { [weak self] render in
                render.sinkId == self?.playerId
            }
            .share()

        // first-frame setup (fires once)
        playerFrames
            .take(1)
            .subscribe(onNext: { [weak self] renderer in
                guard let self = self else { return }
                self.firstFrame = renderer.sampleBuffer
                self.playerPosition.onNext(0)
                self.pausePlayback()
                self.setMuted(true)
                self.seekToTime(time: 0)
                self.transition(to: .ready)
                self.playerReady.accept(true)
                self.playBackFrame.onNext(self.firstFrame)
                if let sampleBuffer = renderer.sampleBuffer,
                   let image = UIImage.createFrom(sampleBuffer: sampleBuffer) {
                    DispatchQueue.main.async {
                        self.delegate?.extractedVideoFrame(with: image.size.height)
                    }
                }
            })
            .disposed(by: playBackDisposeBag)

        // continuous frame relay (all frames including first)
        playerFrames
            .subscribe(onNext: { [weak self] renderer in
                self?.playBackFrame.onNext(renderer.sampleBuffer)
            })
            .disposed(by: playBackDisposeBag)

        videoService.playerInfo
            .asObservable()
            .filter { [weak self] player in
                self?.playerId.contains(player.playerId) ?? false
            }
            .take(1)
            .subscribe(onNext: { [weak self] player in
                guard let self = self else { return }
                guard let duration = Float(player.duration),
                      duration > 0 else {
                    DispatchQueue.main.async {
                        self.videoService.closePlayer(playerId: self.playerId)
                    }
                    return
                }
                self.playerDuration.accept(duration)
                self.hasVideo.accept(player.hasVideo)
                if !player.hasVideo {
                    // Audio-only: no first-frame extraction needed
                    self.audioMuted.accept(false)
                    self.playerReady.accept(true)
                    self.transition(to: .ready)
                    return
                }
                // Video: mute audio and unpause to extract first frame
                self.setMuted(true)
                self.transition(to: .extractingFirstFrame)
            })
            .disposed(by: playBackDisposeBag)
    }

    func togglePause() {
        switch state {
        case .ready:
            transition(to: .playing)
        case .finished:
            seekToTime(time: 0)
            transition(to: .playing)
        case .playing:
            transition(to: .ready)
        case .idle, .extractingFirstFrame, .seeking:
            break
        }
    }

    func muteAudio() {
        audioMuted.accept(!audioMuted.value)
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted.value)
    }

    func userStartSeeking() {
        let wasPlaying = (state == .playing)
        transition(to: .seeking(wasPlaying: wasPlaying))
    }

    func userStopSeeking() {
        let time = Int(playerDuration.value * seekTimeVariable.value)
        videoService.seekToTime(time: time, playerId: playerId)
        endDetectionCount = 0
        currentTime = Int64(time)
        if case .seeking(let wasPlaying) = state, wasPlaying {
            transition(to: .playing)
        } else {
            transition(to: .ready)
        }
    }

    func seekToTime(time: Int) {
        videoService.seekToTime(time: time, playerId: playerId)
    }

    func closePlayer() {
        transition(to: .idle)
        videoService.closePlayer(playerId: playerId)
    }

    private func pausePlayback() {
        videoService.pausePlayer(playerId: playerId, pause: true)
    }

    private func setMuted(_ muted: Bool) {
        audioMuted.accept(muted)
        videoService.mutePlayerAudio(playerId: playerId, mute: muted)
    }

    private func invalidateTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func startTimer() {
        invalidateTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.timerFired()
            }
        }
    }

    lazy var incomingFrame: Observable<VideoFrameInfo> = {
        return videoService.videoInputManager.frameSubject.asObservable()
    }()

    // MARK: - Progress & End Detection

    private func timerFired() {
        guard state == .playing else { return }

        let time = videoService.getPlayerPosition(playerId: playerId)
        if time < 0 { return }
        guard playerDuration.value > 0 else { return }

        let progress = Float(time) / playerDuration.value
        playerPosition.onNext(progress)

        let previousProgress = Float(currentTime) / playerDuration.value

        if time < currentTime && previousProgress > endThreshold {
            endDetectionCount += 1
        } else if progress >= 0.999 {
            endDetectionCount += 1
        } else {
            endDetectionCount = 0
        }

        if endDetectionCount >= 2 {
            currentTime = time
            transition(to: .finished)
            endDetectionCount = 0
            return
        }

        currentTime = time
    }

    deinit {
        closePlayer()
    }
}
