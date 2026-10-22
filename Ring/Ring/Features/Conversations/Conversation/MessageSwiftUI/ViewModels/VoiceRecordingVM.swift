/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

import AVFoundation
import RxCocoa
import RxSwift
import UIKit

enum VoiceRecordingState: Equatable {
    case idle
    case recording
    case preview
}

final class VoiceRecordingVM: ObservableObject {

    @Published private(set) var state: VoiceRecordingState = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var hint: String?
    @Published private(set) var isPreviewPlaying = false
    @Published private(set) var previewDuration: TimeInterval = 0
    @Published private(set) var previewElapsed: TimeInterval = 0

    var conversation: ConversationModel?
    var takeReplyId: () -> String = { "" }

    var isRecording: Bool {
        state == .recording
    }

    private static let minimumDuration: TimeInterval = 0.5
    private static let maximumDuration: TimeInterval = 300
    private static let fileFinalizationDelay: TimeInterval = 1
    private static let hintDuration: TimeInterval = 2

    private let injectionBag: InjectionBag
    private let videoService: VideoService
    private let dataTransferService: DataTransferService
    private let callService: CallService
    private let transferHelper: TransferHelper
    private let messagePanelState: PublishSubject<State>
    private var recordingPath: String?
    private var recordingStart: Date?
    private var elapsedTimer: Timer?
    private var pendingHintReset: DispatchWorkItem?
    private var previewPlayer: PlayerViewModel?
    private var previewProgress: Float = 0
    private var previewSliderUpdate: ((Float) -> Void)?
    private var previewDisposeBag = DisposeBag()
    private let disposeBag = DisposeBag()

    init(injectionBag: InjectionBag, transferHelper: TransferHelper, messagePanelState: PublishSubject<State>) {
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.dataTransferService = injectionBag.dataTransferService
        self.callService = injectionBag.callService
        self.transferHelper = transferHelper
        self.messagePanelState = messagePanelState

        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.stop()
            })
            .disposed(by: disposeBag)

        transferHelper.playbackStarted
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.interrupt()
            })
            .disposed(by: disposeBag)

        callService.callsUpdated
            .observe(on: MainScheduler.instance)
            .filter { [weak self] in
                !(self?.callService.stateMirror.ongoingCalls.isEmpty ?? true)
            }
            .subscribe(onNext: { [weak self] in
                self?.interrupt()
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Actions

    func start() {
        guard state == .idle, isMicrophoneAuthorized() else { return }
        startRecording()
    }

    func cancel() {
        guard state != .idle else { return }
        discardRecording()
        UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.voiceMessageDeleted)
    }

    func stop() {
        guard isRecording, let path = recordingPath else { return }
        guard stopRecorder() >= Self.minimumDuration else {
            discardRecording()
            return
        }
        state = .preview
        afterFileIsWritten { [weak self] in
            guard let self = self, self.state == .preview, self.recordingPath == path else { return }
            self.bindPreview(PlayerViewModel(injectionBag: self.injectionBag, path: path))
        }
    }

    func retake() {
        guard state == .preview else { return }
        discardRecording()
        start()
    }

    func interrupt() {
        if isRecording {
            stop()
        } else {
            previewPlayer?.pauseIfPlaying()
        }
    }

    func send() {
        guard state != .idle, let path = recordingPath, let conversation = conversation else {
            discardRecording()
            return
        }
        if isRecording, stopRecorder() < Self.minimumDuration {
            discardRecording()
            return
        }
        previewPlayer?.closePlayer()
        reset()
        let dataTransferService = self.dataTransferService
        let replyId = takeReplyId()
        afterFileIsWritten {
            dataTransferService.sendFile(conversation: conversation,
                                         filePath: path,
                                         displayName: URL(fileURLWithPath: path).lastPathComponent,
                                         localIdentifier: nil,
                                         replyTo: replyId)
        }
    }

    // MARK: - Preview

    func togglePreview() {
        previewPlayer?.togglePause()
    }

    func beginPreviewSeek() {
        previewPlayer?.userStartSeeking()
    }

    func seekPreview(to progress: Float) {
        previewPlayer?.seekTimeVariable.accept(progress)
        updatePreviewPosition(progress)
    }

    func endPreviewSeek() {
        previewPlayer?.userStopSeeking()
    }

    func registerPreviewSlider(_ update: @escaping (Float) -> Void) {
        previewSliderUpdate = update
        update(previewProgress)
    }

    private func updatePreviewPosition(_ progress: Float) {
        previewProgress = progress
        previewSliderUpdate?(progress)
        let elapsed = (previewDuration * TimeInterval(progress)).rounded(.down)
        if elapsed != previewElapsed {
            previewElapsed = elapsed
        }
    }

    private func bindPreview(_ player: PlayerViewModel) {
        previewPlayer = player
        previewDisposeBag = DisposeBag()
        player.pause
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] paused in
                self?.isPreviewPlaying = !paused
            })
            .disposed(by: previewDisposeBag)
        player.playerDuration
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                guard let self = self else { return }
                self.previewDuration = TimeInterval(duration) / 1_000_000
                self.updatePreviewPosition(self.previewProgress)
            })
            .disposed(by: previewDisposeBag)
        player.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] progress in
                self?.updatePreviewPosition(progress)
            })
            .disposed(by: previewDisposeBag)
        player.createPlayer()
    }

    // MARK: - Recording

    private var currentDuration: TimeInterval {
        recordingStart.map { Date().timeIntervalSince($0) } ?? 0
    }

    private func startRecording() {
        guard callService.stateMirror.ongoingCalls.isEmpty else {
            show(hint: L10n.Conversation.voiceMessageUnavailableInCall)
            return
        }
        guard let basePath = makeBasePath() else { return }
        transferHelper.releaseAllPlayers()
        guard let path = videoService.startLocalRecorder(audioOnly: true, path: basePath) else { return }
        recordingPath = path
        recordingStart = Date()
        elapsed = 0
        state = .recording
        startElapsedTimer()
        UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.voiceMessageRecording)
    }

    @discardableResult
    private func stopRecorder() -> TimeInterval {
        let duration = currentDuration
        stopElapsedTimer()
        if let path = recordingPath {
            videoService.stopLocalRecorder(path: path)
        }
        transferHelper.releaseAllPlayers()
        recordingStart = nil
        return duration
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsed = self.currentDuration
            if self.elapsed >= Self.maximumDuration {
                self.stop()
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func afterFileIsWritten(_ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fileFinalizationDelay, execute: action)
    }

    private func makeBasePath() -> String? {
        guard let conversation = conversation else { return nil }
        return dataTransferService.newRecordingURL(for: conversation)?.path
    }

    private func discardRecording() {
        if recordingStart != nil {
            stopRecorder()
        }
        previewPlayer?.closePlayer()
        if let path = recordingPath {
            afterFileIsWritten {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        reset()
    }

    private func reset() {
        stopElapsedTimer()
        recordingPath = nil
        recordingStart = nil
        previewPlayer = nil
        previewDisposeBag = DisposeBag()
        isPreviewPlaying = false
        previewDuration = 0
        previewProgress = 0
        previewElapsed = 0
        previewSliderUpdate = nil
        elapsed = 0
        state = .idle
    }

    // MARK: - Permission

    private func isMicrophoneAuthorized() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.start()
                    } else {
                        self.messagePanelState.onNext(MessagePanelState.microphonePermissionDenied)
                    }
                }
            }
            return false
        default:
            messagePanelState.onNext(MessagePanelState.microphonePermissionDenied)
            return false
        }
    }

    // MARK: - Hint

    private func show(hint: String) {
        pendingHintReset?.cancel()
        self.hint = hint
        UIAccessibility.post(notification: .announcement, argument: hint)
        let reset = DispatchWorkItem { [weak self] in
            self?.hint = nil
        }
        pendingHintReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hintDuration, execute: reset)
    }

    deinit {
        elapsedTimer?.invalidate()
        pendingHintReset?.cancel()
        previewPlayer?.closePlayer()
        if let path = recordingPath {
            if recordingStart != nil {
                videoService.stopLocalRecorder(path: path)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fileFinalizationDelay) {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }
}
