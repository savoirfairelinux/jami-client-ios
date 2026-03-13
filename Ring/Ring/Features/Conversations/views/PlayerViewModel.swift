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

import SwiftUI
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
    case ready                      // paused, showing first/last frame
    case playing
    case seeking(wasPlaying: Bool)  // remembers whether to resume after seek
    case finished                   // playback ended, showing first frame
}

final class PlayerViewModel: ObservableObject {

    // MARK: - Published UI state (consumed by PlayerView)

    @Published var isPaused: Bool = true
    @Published var isMuted: Bool = true
    @Published var duration: Float = 0
    @Published var hasVideo: Bool = true
    @Published var controlsVisible: Bool = true

    /// Progress is updated ~10x/sec by the timer. Not @Published to avoid
    /// triggering full SwiftUI body re-evaluation on every tick.
    /// The UISlider is updated directly via `sliderUpdate` closure.
    var progress: Float = 0
    var sliderUpdate: ((Float) -> Void)?
    var isSeeking: Bool = false

    // MARK: - Display layer (owned here, used by VideoLayerView)

    let displayLayer: AVSampleBufferDisplayLayer = {
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        layer.isOpaque = true
        return layer
    }()

    // MARK: - Public Rx interface (used by SendFileViewModel)

    var hasVideoRelay = BehaviorRelay<Bool>(value: true)
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
    let filePath: String
    private var playerId = ""
    private var progressTimer: Timer?

    private var state: PlayerState = .idle
    private var currentTime: Int64 = 0
    private var endDetectionCount: Int = 0
    private let endThreshold: Float = 0.95

    /// The most recent buffer, kept so we can re-enqueue after layout or error recovery.
    private var lastBuffer: CMSampleBuffer?

    /// Auto-hide work item for full-screen controls.
    private var autoHideTask: DispatchWorkItem?

    // MARK: - Init

    init(injectionBag: InjectionBag, path: String) {
        self.videoService = injectionBag.videoService
        filePath = path
        subscribeRxToPublished()
    }

    // MARK: - Rx → @Published bridge

    /// Mirror the Rx relays into @Published properties so PlayerView (SwiftUI)
    /// observes changes without a separate coordinator class.
    /// Uses asyncInstance to ensure assignments never happen synchronously
    /// during a SwiftUI view update pass (avoids "Publishing changes from
    /// within view updates" warning).
    private func subscribeRxToPublished() {
        pause.asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in self?.isPaused = value })
            .disposed(by: disposeBag)

        audioMuted.asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in self?.isMuted = value })
            .disposed(by: disposeBag)

        playerDuration.asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in self?.duration = value })
            .disposed(by: disposeBag)

        hasVideoRelay.asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in self?.hasVideo = value })
            .disposed(by: disposeBag)

        playerPosition
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] position in
                guard let self = self, !self.isSeeking else { return }
                self.progress = position
                self.sliderUpdate?(position)
            })
            .disposed(by: disposeBag)

        playBackFrame
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self, let buffer = buffer else { return }
                self.enqueueBuffer(buffer)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Display layer helpers

    func enqueueBuffer(_ buffer: CMSampleBuffer) {
        let shortPath = (filePath as NSString).lastPathComponent
        lastBuffer = buffer
        if displayLayer.status == .failed {
            print("[Player] [\(shortPath)] displayLayer was failed, flushing before enqueue")
            displayLayer.flush()
        }
        print("[Player] [\(shortPath)] enqueueBuffer status=\(displayLayer.status.rawValue) superlayer=\(displayLayer.superlayer != nil)")
        displayLayer.enqueue(buffer)
    }

    func redisplayLastBuffer() {
        let shortPath = (filePath as NSString).lastPathComponent
        guard let buffer = lastBuffer else {
            print("[Player] [\(shortPath)] redisplayLastBuffer: no lastBuffer")
            return
        }
        print("[Player] [\(shortPath)] redisplayLastBuffer: re-enqueuing")
        displayLayer.flush()
        displayLayer.enqueue(buffer)
    }

    // MARK: - Auto-hide controls

    func scheduleAutoHide() {
        autoHideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.controlsVisible = false
            }
        }
        autoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
    }

    func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
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
        let shortPath = (filePath as NSString).lastPathComponent
        playerReady.accept(false)
        let fname = "file://" + filePath

        // Re-entry: player already exists, just re-emit first frame
        if !playerId.isEmpty {
            print("[Player] [\(shortPath)] re-entry: playerId=\(playerId) firstFrame=\(firstFrame != nil) state=\(state)")
            if let frame = firstFrame {
                playBackFrame.onNext(frame)
            }
            playerReady.accept(true)
            return
        }

        print("[Player] [\(shortPath)] first init")
        transition(to: .idle)
        playBackDisposeBag = DisposeBag()

        // Subscribe to playerInfo BEFORE creating the player so we don't miss
        // the fileOpened callback if the daemon fires it on a background thread
        // before we set up subscriptions.
        videoService.playerInfo
            .asObservable()
            .filter { [weak self] player in
                let match = self?.playerId.contains(player.playerId) ?? false
                if !match {
                    print("[Player] [\(shortPath)] playerInfo filter miss: myId='\(self?.playerId ?? "nil")' eventId='\(player.playerId)'")
                }
                return match
            }
            .take(1)
            .subscribe(onNext: { [weak self] player in
                guard let self = self else { return }
                print("[Player] [\(shortPath)] playerInfo received: hasVideo=\(player.hasVideo) duration=\(player.duration) thread=\(Thread.isMainThread ? "main" : "bg")")
                guard let duration = Float(player.duration),
                      duration > 0 else {
                    print("[Player] [\(shortPath)] invalid duration, closing")
                    DispatchQueue.main.async {
                        self.videoService.closePlayer(playerId: self.playerId)
                    }
                    return
                }
                self.playerDuration.accept(duration)
                self.hasVideoRelay.accept(player.hasVideo)
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

        playerId = videoService.createPlayer(path: fname)
        print("[Player] [\(shortPath)] created playerId=\(playerId)")
        playerPosition.onNext(0)

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
                print("[Player] [\(shortPath)] first frame arrived thread=\(Thread.isMainThread ? "main" : "bg")")
                self.firstFrame = renderer.sampleBuffer
                self.playerPosition.onNext(0)
                self.videoService.pausePlayer(playerId: self.playerId, pause: true)
                self.setMuted(true)
                self.videoService.seekToTime(time: 0, playerId: self.playerId)
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
    }

    func togglePause() {
        switch state {
        case .ready:
            transition(to: .playing)
        case .finished:
            videoService.seekToTime(time: 0, playerId: playerId)
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

    func closePlayer() {
        transition(to: .idle)
        videoService.closePlayer(playerId: playerId)
    }

    // MARK: - Private helpers

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

        // Detect playback end: backwards jump near end, or reached 99.9%
        if time < currentTime && previousProgress > endThreshold {
            endDetectionCount += 1
        } else if progress >= 0.999 {
            endDetectionCount += 1
        } else {
            endDetectionCount = 0
        }

        // Require 2 consecutive ticks to confirm end (filters glitches)
        if endDetectionCount >= 2 {
            currentTime = time
            transition(to: .finished)
            endDetectionCount = 0
            return
        }

        currentTime = time
    }

    // MARK: - Deinit

    deinit {
        closePlayer()
    }
}
