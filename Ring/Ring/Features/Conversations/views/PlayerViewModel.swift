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
import RxRelay

enum PlayerState: Equatable {
    case opening
    case paused
    case playing
    case seeking(wasPlaying: Bool)
    case finished
    case failed
}

final class PlayerViewModel {

    // MARK: - Public Rx interface

    let hasVideo: Bool
    let playerDuration: BehaviorRelay<Float>
    let playerPosition = PublishSubject<Float>()
    let isPaused = BehaviorRelay<Bool>(value: true)
    let audioMuted: BehaviorRelay<Bool>
    let playbackFailed = BehaviorRelay<Bool>(value: false)
    let frameSource = BehaviorRelay<FrameDistributor?>(value: nil)

    private(set) var state: PlayerState = .opening

    // MARK: - Private state

    private let videoService: VideoService
    private let path: String
    private var playerId: String?
    private var openDisposeBag = DisposeBag()
    private var progressTimer: Timer?
    private var didStart = false
    private var isClosed = false
    private var playWhenOpened = true
    private var daemonPaused = true
    private var currentTime: Int64 = 0
    private var endDetectionCount = 0

    // MARK: - Init

    init(path: String, preview: MediaPreview, videoService: VideoService) {
        self.path = path
        self.videoService = videoService
        hasVideo = preview.hasVideo
        playerDuration = BehaviorRelay(value: Float(preview.durationMicroseconds))
        audioMuted = BehaviorRelay(value: preview.hasVideo)
    }

    deinit {
        close()
    }

    // MARK: - Public API

    private func start() {
        guard !didStart, !isClosed else { return }
        didStart = true
        isPaused.accept(!playWhenOpened)
        let path = self.path
        let opened = videoService.fileOpened
            .filter { $0.path == path }
            .take(1)
            .asSingle()
            .observe(on: MainScheduler.instance)
        Single.zip(opened, videoService.openPlayer(path: "file://" + path))
            .subscribe(onSuccess: { [weak self] file, playerId in
                self?.didOpen(playerId: playerId, file: file)
            }, onFailure: { [weak self] _ in
                self?.fail()
            })
            .disposed(by: openDisposeBag)
    }

    func prepare() {
        guard !didStart else { return }
        playWhenOpened = false
        start()
    }

    func togglePause() {
        switch state {
        case .opening where !didStart:
            start()
        case .opening:
            playWhenOpened.toggle()
            isPaused.accept(!playWhenOpened)
        case .paused:
            transition(to: .playing)
        case .finished:
            seek(to: 0)
            transition(to: .playing)
        case .playing:
            transition(to: .paused)
        case .seeking, .failed:
            break
        }
    }

    func pauseIfPlaying() {
        switch state {
        case .playing:
            transition(to: .paused)
        case .opening where didStart && playWhenOpened:
            togglePause()
        default:
            break
        }
    }

    func toggleMute() {
        audioMuted.accept(!audioMuted.value)
        guard let playerId = playerId else { return }
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted.value)
    }

    func beginSeek() {
        switch state {
        case .playing, .paused, .finished:
            transition(to: .seeking(wasPlaying: state == .playing))
        default:
            break
        }
    }

    func endSeek(at progress: Float) {
        guard case .seeking(let wasPlaying) = state else { return }
        let clamped = min(max(progress, 0), 1)
        seek(to: Int64(playerDuration.value * clamped))
        playerPosition.onNext(clamped)
        transition(to: wasPlaying ? .playing : .paused)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        invalidateTimer()
        openDisposeBag = DisposeBag()
        frameSource.accept(nil)
        if let playerId = playerId {
            videoService.closePlayer(playerId: playerId)
        }
        playerId = nil
        isPaused.accept(true)
    }

    // MARK: - State machine

    private func didOpen(playerId: String, file: OpenedMediaFile) {
        guard !isClosed else {
            videoService.closePlayer(playerId: playerId)
            return
        }
        self.playerId = playerId
        guard file.preview.isPlayable else {
            fail()
            return
        }
        playerDuration.accept(Float(file.preview.durationMicroseconds))
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted.value)
        frameSource.accept(videoService.playerFrames(playerId: playerId))
        transition(to: playWhenOpened ? .playing : .paused)
    }

    private func fail() {
        state = .failed
        invalidateTimer()
        playbackFailed.accept(true)
        isPaused.accept(true)
        if let playerId = playerId {
            videoService.closePlayer(playerId: playerId)
        }
        playerId = nil
        frameSource.accept(nil)
    }

    private func transition(to newState: PlayerState) {
        state = newState
        switch newState {
        case .opening, .failed:
            break
        case .playing:
            endDetectionCount = 0
            setDaemonPaused(false)
            isPaused.accept(false)
            startTimer()
        case .paused:
            invalidateTimer()
            setDaemonPaused(true)
            isPaused.accept(true)
        case .seeking(let wasPlaying):
            invalidateTimer()
            if wasPlaying {
                setDaemonPaused(true)
            }
        case .finished:
            invalidateTimer()
            setDaemonPaused(true)
            isPaused.accept(true)
            currentTime = 0
            playerPosition.onNext(0)
        }
    }

    private func setDaemonPaused(_ paused: Bool) {
        guard let playerId = playerId, paused != daemonPaused else { return }
        daemonPaused = paused
        videoService.pausePlayer(playerId: playerId, pause: paused)
    }

    private func seek(to time: Int64) {
        endDetectionCount = 0
        currentTime = time
        guard let playerId = playerId else { return }
        videoService.seekPlayer(playerId: playerId, to: time)
    }

    // MARK: - Progress & end detection

    private func startTimer() {
        invalidateTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
    }

    private func invalidateTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func timerFired() {
        guard state == .playing, let playerId = playerId else { return }
        let time = videoService.getPlayerPosition(playerId: playerId)
        guard time >= 0, playerDuration.value > 0 else { return }

        let progress = Float(time) / playerDuration.value
        playerPosition.onNext(progress)

        if time == 0 && currentTime > 0 {
            transition(to: .finished)
            return
        }

        endDetectionCount = progress >= 0.999 ? endDetectionCount + 1 : 0
        if endDetectionCount >= 2 {
            transition(to: .finished)
            return
        }
        currentTime = time
    }
}
