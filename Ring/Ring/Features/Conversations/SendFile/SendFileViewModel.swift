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
import SwiftyBeaver
import Contacts
import RxCocoa

enum RecordingState {
    case initial
    case recording
    case recorded
    case sent
}

class SendFileViewModel: Stateable, ViewModel {
    // Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    /// Single source of truth for recording lifecycle.
    let recordingState = BehaviorRelay<RecordingState>(value: .initial)

    var audioOnly: Bool = false
    private let videoService: VideoService
    private let accountService: AccountsService
    private let fileTransferService: DataTransferService
    var fileName = ""
    var conversation: ConversationModel!
    let injectionBag: InjectionBag

    // Current frame from camera or player, published to the observable model.
    let playBackFrame = PublishSubject<UIImage?>()
    var player: PlayerViewModel?
    var playBackDisposeBag = DisposeBag()

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.fileTransferService = injectionBag.dataTransferService
        self.injectionBag = injectionBag
    }

    /// Must be called after setting `conversation` and `audioOnly`.
    func setup() {
        if !audioOnly {
            videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            videoService.startMediumCamera()
        }
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { [weak self] frame in
                self?.playBackFrame.onNext(frame)
            })
            .disposed(by: playBackDisposeBag)
    }

    func triggerRecording() {
        if recordingState.value == .recording {
            stopRecording()
            return
        }
        startRecording()
    }

    func startRecording() {
        player?.closePlayer()
        player = nil
        playBackDisposeBag = DisposeBag()
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { [weak self] frame in
                self?.playBackFrame.onNext(frame)
            })
            .disposed(by: playBackDisposeBag)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        let random = String(UInt64.random(in: 0...9999))
        let nameForRecordingFile = dateString + "_" + random
        guard let url = self.fileTransferService.getFilePathForRecordings(forFile: nameForRecordingFile,
                                                                          accountID: conversation.accountId,
                                                                          conversationID: conversation.id,
                                                                          isSwarm: self.conversation.isSwarm()) else { return }
        guard let name = self.videoService.startLocalRecorder(audioOnly: audioOnly, path: url.path) else { return }
        recordingState.accept(.recording)
        fileName = name
    }

    func stopRecording() {
        videoService.stopLocalRecorder(path: fileName)
        recordingState.accept(.recorded)
        // Create player after a short delay to allow the recording to finish writing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.createPlayer()
        }
    }

    func sendFile() {
        guard !fileName.isEmpty else { return }
        let name = URL(fileURLWithPath: fileName).lastPathComponent
        player?.closePlayer()
        player = nil
        fileTransferService.sendFile(conversation: conversation, filePath: fileName, displayName: name, localIdentifier: nil)
        videoService.videRecordingFinished()
        recordingState.accept(.sent)
    }

    func cancel() {
        if recordingState.value == .recording {
            stopRecording()
        }
        player?.closePlayer()
        player = nil
        videoService.videRecordingFinished()
        recordingState.accept(.sent)
        if !fileName.isEmpty {
            try? FileManager.default.removeItem(atPath: fileName)
        }
    }

    func switchCamera() {
        videoService.switchCamera()
    }

    func setCameraOrientation(orientation: UIDeviceOrientation) {
        videoService.setCameraOrientation(orientation: orientation)
    }

    func createPlayer() {
        // Drop the camera subscription before starting the player stream.
        playBackDisposeBag = DisposeBag()
        let newPlayer = PlayerViewModel(injectionBag: injectionBag, path: fileName)
        newPlayer.createPlayer()
        player = newPlayer
        // Pipe player frames into playBackFrame so the background layer updates.
        newPlayer.playBackFrame.asObservable()
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self else { return }
                if let buffer = buffer, let image = UIImage.createFrom(sampleBuffer: buffer) {
                    self.playBackFrame.onNext(image)
                }
            })
            .disposed(by: playBackDisposeBag)
    }

    // MARK: - Playback controls (forwarded to player)

    func togglePause() { player?.togglePause() }
    func muteAudio() { player?.muteAudio() }
    func userStartSeeking() { player?.userStartSeeking() }
    func userStopSeeking() { player?.userStopSeeking() }
    func seek(to value: Float) { player?.seekTimeVariable.accept(value) }
}
