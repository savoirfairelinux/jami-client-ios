/*
 * Copyright (C) 2019-2025 Savoir-faire Linux Inc.
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
}

class SendFileViewModel: ObservableObject, Stateable, ViewModel {

    // MARK: - Stateable (coordinator navigation)

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    // MARK: - Published UI state

    @Published var previewImage: UIImage?
    @Published var isRecording: Bool = false
    @Published var isReadyToSend: Bool = false
    @Published var showPlayerControls: Bool = false
    @Published var recordDuration: String = ""
    @Published var playerPosition: Float = 0
    @Published var playerDuration: Float = 0
    @Published var isPaused: Bool = true
    @Published var isAudioMuted: Bool = true
    @Published var hideInfo: Bool = false
    @Published private(set) var isDismissed: Bool = false

    // MARK: - Configuration (set by coordinator before setup())

    var audioOnly: Bool = false
    var conversation: ConversationModel!

    // MARK: - Private

    private let videoService: VideoService
    private let accountService: AccountsService
    private let fileTransferService: DataTransferService
    let injectionBag: InjectionBag

    private(set) var fileName = ""
    @Published private(set) var fileDisplayName: String = ""
    private(set) var player: PlayerViewModel?

    private var playBackDisposeBag = DisposeBag()
    private var playerDisposeBag = DisposeBag()
    private var recordingTimer: Timer?
    private var recordingSeconds: Int = 0

    // Raw frame stream consumed by the background layer
    let playBackFrame = PublishSubject<UIImage?>()

    // MARK: - Init

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.fileTransferService = injectionBag.dataTransferService
        self.injectionBag = injectionBag
    }

    // MARK: - Setup

    /// Must be called after setting `conversation` and `audioOnly`.
    func setup() {
        if !audioOnly {
            videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            videoService.startMediumCamera()
        }
        subscribeCameraFrames()
    }

    func setCameraOrientation(orientation: UIDeviceOrientation) {
        videoService.setCameraOrientation(orientation: orientation)
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
        playBackDisposeBag = DisposeBag()
        subscribeCameraFrames()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let nameForRecordingFile = dateFormatter.string(from: Date()) + "_" + String(UInt64.random(in: 0...9999))
        guard let url = fileTransferService.getFilePathForRecordings(forFile: nameForRecordingFile,
                                                                     accountID: conversation.accountId,
                                                                     conversationID: conversation.id,
                                                                     isSwarm: conversation.isSwarm()) else { return }
        guard let name = videoService.startLocalRecorder(audioOnly: audioOnly, path: url.path) else { return }
        fileName = name
        fileDisplayName = URL(fileURLWithPath: name).lastPathComponent
        transition(to: .recording)
    }

    func stopRecording() {
        videoService.stopLocalRecorder(path: fileName)
        transition(to: .recorded)
        // Allow the recording file to finish writing before creating the player.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.createPlayer()
        }
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
        player?.closePlayer()
        player = nil
        videoService.videRecordingFinished()
        if !fileName.isEmpty {
            try? FileManager.default.removeItem(atPath: fileName)
        }
        transition(to: .sent)
    }

    // MARK: - Camera

    func switchCamera() {
        videoService.switchCamera()
    }

    // MARK: - Playback controls

    func togglePause() { player?.togglePause() }
    func muteAudio() { player?.muteAudio() }
    func userStartSeeking() { player?.userStartSeeking() }
    func userStopSeeking() { player?.userStopSeeking() }
    func seek(to value: Float) { player?.seekTimeVariable.accept(value) }

    // MARK: - Private helpers

    private func subscribeCameraFrames() {
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { [weak self] frame in
                self?.playBackFrame.onNext(frame)
                DispatchQueue.main.async { self?.previewImage = frame }
            })
            .disposed(by: playBackDisposeBag)
    }

    private func transition(to state: RecordingState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .initial:
                self.isRecording = false
                self.isReadyToSend = false
                self.hideInfo = !self.audioOnly
                self.stopTimer()
                self.recordDuration = ""
            case .recording:
                self.isRecording = true
                self.isReadyToSend = false
                self.hideInfo = true
                self.showPlayerControls = false
                self.startTimer()
            case .recorded:
                self.isRecording = false
                self.isReadyToSend = true
                self.hideInfo = true
                self.stopTimer()
                self.recordDuration = ""
            case .sent:
                self.isRecording = false
                self.isReadyToSend = false
                self.isDismissed = true
                self.stopTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        recordingSeconds = 0
        recordDuration = "00:00"
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingSeconds += 1
            let s = self.recordingSeconds % 60
            let m = (self.recordingSeconds / 60) % 60
            let h = self.recordingSeconds / 3600
            self.recordDuration = h > 0
                ? String(format: "%02d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    // MARK: - Player

    private func createPlayer() {
        // Drop camera/previous player frames before binding to the new player.
        playBackDisposeBag = DisposeBag()
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
                self.playBackFrame.onNext(image)
                DispatchQueue.main.async { self.previewImage = image }
            })
            .disposed(by: playBackDisposeBag)

        newPlayer.playerReady.asObservable()
            .filter { $0 }
            .take(1)
            .subscribe(onNext: { [weak self] _ in
                DispatchQueue.main.async { self?.showPlayerControls = true }
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
                DispatchQueue.main.async { self?.playerDuration = duration }
            })
            .disposed(by: playerDisposeBag)

        newPlayer.playerPosition.asObservable()
            .subscribe(onNext: { [weak self] position in
                DispatchQueue.main.async { self?.playerPosition = position }
            })
            .disposed(by: playerDisposeBag)
    }
}
