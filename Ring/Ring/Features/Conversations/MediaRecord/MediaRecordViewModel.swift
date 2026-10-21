/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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
import SwiftyBeaver

enum RecordingState {
    case initial
    case recording
    case recorded
    case sent
    case cancelled
}

class MediaRecordViewModel: ObservableObject, Stateable, ViewModel {

    // MARK: - Stateable (coordinator navigation)

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: - Published UI state

    @Published var previewImage: UIImage?
    @Published var isRecording: Bool = false
    @Published var isReadyToSend: Bool = false
    @Published var recordDuration: String = ""
    @Published var playerDuration: Float = 0
    @Published private(set) var previewElapsed: TimeInterval = 0
    @Published var isPaused: Bool = true
    @Published var isAudioMuted: Bool = true
    let dismissHandler = DismissHandler()

    // MARK: - Configuration (set by coordinator before setup())

    var conversation: ConversationModel!

    // MARK: - Private

    private let videoService: VideoService
    private let fileTransferService: DataTransferService
    let injectionBag: InjectionBag

    private(set) var fileName = ""
    private(set) var player: PlayerViewModel?
    private var isSeeking = false
    private var previewProgress: Float = 0
    private var previewSliderUpdate: ((Float) -> Void)?

    @MainActor private lazy var orientationMonitor = DeviceOrientationMonitor()
    private var cameraStarted = false
    private var cameraDisposeBag = DisposeBag()
    private var playerDisposeBag = DisposeBag()
    private var recordingTimer: Timer?
    private var recordingSeconds: Int = 0

    // MARK: - Init

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.fileTransferService = injectionBag.dataTransferService
        self.injectionBag = injectionBag
    }

    // MARK: - Setup

    /// Must be called after setting `conversation`.
    func setup() {
        subscribeCameraFrames()
    }

    @MainActor
    func previewAppeared() {
        orientationMonitor.start { [weak self] input in
            self?.videoService.setCameraOrientation(input)
        }
        guard !cameraStarted else { return }
        cameraStarted = true
        videoService.startMediumCamera()
    }

    @MainActor
    func previewDisappeared() {
        orientationMonitor.stop()
    }

    // MARK: - Recording

    func triggerRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        player?.closePlayer()
        player = nil

        guard let url = fileTransferService.newRecordingURL(for: conversation) else { return }
        guard let name = videoService.startLocalRecorder(audioOnly: false, path: url.path) else { return }
        fileName = name
        transition(to: .recording)
    }

    func stopRecording() {
        let recordedFile = fileName
        videoService.stopLocalRecorder(path: recordedFile)
        transition(to: .recorded)
        // Allow the recording file to finish writing before creating the player.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self, self.fileName == recordedFile else { return }
            self.createPlayer()
        }
    }

    func retake() {
        discardRecording()
        playerDisposeBag = DisposeBag()
        playerDuration = 0
        updatePreviewPosition(0)
        isPaused = true
        isAudioMuted = true
        cameraDisposeBag = DisposeBag()
        subscribeCameraFrames()
        transition(to: .initial)
    }

    // MARK: - Send / Cancel

    func sendFile() {
        guard !fileName.isEmpty else { return }
        let name = URL(fileURLWithPath: fileName).lastPathComponent
        player?.closePlayer()
        player = nil
        fileTransferService.sendFile(conversation: conversation, filePath: fileName, displayName: name, localIdentifier: nil)
        videoService.videRecordingFinished()
        transition(to: .sent)
    }

    func cancel() {
        if isRecording { stopRecording() }
        discardRecording()
        videoService.videRecordingFinished()
        transition(to: .cancelled)
    }

    private func discardRecording() {
        player?.closePlayer()
        player = nil
        if !fileName.isEmpty {
            try? FileManager.default.removeItem(atPath: fileName)
        }
        fileName = ""
    }

    // MARK: - Camera

    func switchCamera() {
        Task { await videoService.switchCamera() }
    }

    // MARK: - Playback controls

    func togglePause() { player?.togglePause() }
    func muteAudio() { player?.muteAudio() }

    func userStartSeeking() {
        isSeeking = true
        player?.userStartSeeking()
        player?.seekTimeVariable.accept(previewProgress)
    }

    func seek(to value: Float) {
        updatePreviewPosition(value)
        player?.seekTimeVariable.accept(value)
    }

    func userStopSeeking() {
        isSeeking = false
        player?.seekTimeVariable.accept(previewProgress)
        player?.userStopSeeking()
    }

    func registerPreviewSlider(_ update: @escaping (Float) -> Void) {
        previewSliderUpdate = update
        update(previewProgress)
    }

    var previewDuration: TimeInterval {
        playerDuration > 0 ? TimeInterval(playerDuration / 1_000_000) : TimeInterval(recordingSeconds)
    }

    private func updatePreviewPosition(_ progress: Float) {
        previewProgress = progress
        previewSliderUpdate?(progress)
        let elapsed = (previewDuration * TimeInterval(progress)).rounded(.down)
        if elapsed != previewElapsed {
            previewElapsed = elapsed
        }
    }

    private func subscribeCameraFrames() {
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { [weak self] frameInfo in
                guard let frameInfo = frameInfo,
                      let image = UIImage.createFrom(sampleBuffer: frameInfo.sampleBuffer, orientation: frameInfo.imageOrientation) else { return }
                DispatchQueue.main.async { self?.previewImage = image }
            })
            .disposed(by: cameraDisposeBag)
    }

    private func transition(to state: RecordingState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .initial:
                self.isReadyToSend = false
            case .recording:
                self.isRecording = true
                self.isReadyToSend = false
                self.startTimer()
            case .recorded:
                self.isRecording = false
                self.isReadyToSend = true
                self.stopTimer()
            case .sent, .cancelled:
                self.isRecording = false
                self.isReadyToSend = false
                self.dismissHandler.dismissView()
                self.stopTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        recordingSeconds = 0
        recordDuration = String.durationFormatted(seconds: 0)
        recordingTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingSeconds += 1
                self.recordDuration = String.durationFormatted(seconds: self.recordingSeconds)
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Player

    private func createPlayer() {
        // Stop camera frames and drop any previous player subscription before binding to the new player.
        cameraDisposeBag = DisposeBag()
        playerDisposeBag = DisposeBag()

        let newPlayer = PlayerViewModel(injectionBag: injectionBag, path: fileName)
        newPlayer.createPlayer()
        player = newPlayer

        // Pipe player frames into the shared frame subject for the background layer.
        newPlayer.playBackFrame.asObservable()
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self,
                      let buffer = buffer,
                      let image = UIImage.createFrom(sampleBuffer: buffer) else { return }
                DispatchQueue.main.async { self.previewImage = image }
            })
            .disposed(by: playerDisposeBag)

        newPlayer.pause.asObservable()
            .subscribe(onNext: { [weak self] paused in
                DispatchQueue.main.async { self?.isPaused = paused }
            })
            .disposed(by: playerDisposeBag)

        newPlayer.audioMuted.asObservable()
            .subscribe(onNext: { [weak self] muted in
                DispatchQueue.main.async { self?.isAudioMuted = muted }
            })
            .disposed(by: playerDisposeBag)

        newPlayer.playerDuration.asObservable()
            .subscribe(onNext: { [weak self] duration in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.playerDuration = duration
                    self.updatePreviewPosition(self.previewProgress)
                }
            })
            .disposed(by: playerDisposeBag)

        newPlayer.playerPosition.asObservable()
            .subscribe(onNext: { [weak self] position in
                DispatchQueue.main.async {
                    guard let self = self, !self.isSeeking else { return }
                    self.updatePreviewPosition(position)
                }
            })
            .disposed(by: playerDisposeBag)
    }
}
