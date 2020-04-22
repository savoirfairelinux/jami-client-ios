/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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
    //stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let recordingState = Variable<RecordingState>(.initial)

    lazy var hideVideoControls: Observable<Bool> = {
        Observable.just(audioOnly)
    }()

    lazy var finished: Observable<Bool> = {
        recordingState
            .asObservable()
            .map({ state in
                state == .sent
            }).share()
    }()

    lazy var hideInfo: Driver<Bool> = {
        recordingState
            .asObservable()
            .map({ [weak self] state in
                state != .initial || !(self?.audioOnly ?? true)
            }).share()
            .asDriver(onErrorJustReturn: false)
    }()

    lazy var readyToSend: Driver<Bool> = {
        recordingState
            .asObservable()
            .map({ state in
                state == .recorded
            }).share()
            .asDriver(onErrorJustReturn: false)
    }()

    lazy var recording: Observable<Bool> = {
        recordingState
            .asObservable()
            .map({ state in
                state == .recording
            }).share()
    }()

    lazy var recordDuration: Driver<String> = {
        let emptyString = Observable.just("")
        let durationTimer = Observable<Int>
            .interval(1.0, scheduler: MainScheduler.instance)
            .takeUntil(self.recordingState
                .asObservable()
                .filter { state in
                    return state == .recorded
            })
            .map({ interval -> String in
                let seconds = interval % 60
                let minutes = (interval / 60) % 60
                let hours = (interval / 3600)
                switch hours {
                case 0:
                    return String(format: "%02d:%02d", minutes, seconds)
                default:
                    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                }
            }).share()
        return self.recordingState
            .asObservable()
            .filter({ state in
            return (state == .recording || state == .recorded)
        }).flatMap({ (state) -> Observable<String>  in
            if state == .recording {
                return durationTimer
            } else {
                return emptyString
            }
        }).asDriver(onErrorJustReturn: "")
    }()

    var audioOnly: Bool = false
    fileprivate let videoService: VideoService
    fileprivate let accountService: AccountsService
    fileprivate let fileTransferService: DataTransferService
    var fileName = ""

    var conversation: ConversationModel!

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.fileTransferService = injectionBag.dataTransferService
        self.injectionBag = injectionBag
        if !audioOnly {
            videoService.updateEncodongPreferences()
            videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
            videoService.startCamera()
        }
        videoService.capturedVideoFrame.asObservable()
       .subscribe(onNext: { [weak self] frame in
            self?.playBackFrame.onNext(frame)
        }).disposed(by: playBackDisposeBag)
    }

    func triggerRecording() {
        if recordingState.value == .recording {
            self.stopRecording()
            return
        }
        startRecording()
    }

    func startRecording() {
        player?.closePlayer()
        player = nil
        videoService.updateEncodongPreferences()
        playBackDisposeBag = DisposeBag()
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { [weak self] frame in
                self?.playBackFrame.onNext(frame)
            }).disposed(by: playBackDisposeBag)
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let date = Date()
        let dateString = dateFormatter.string(from: date)
        let random = String(arc4random_uniform(9999))
        let nameForRecordingFile = dateString + "_" + random
        guard let url = self.fileTransferService.getFilePathForRecordings(forFile: nameForRecordingFile, accountID: conversation.accountId, conversationID: conversation.conversationId) else {return}
        guard let name = self.videoService
            .startLocalRecorder(audioOnly: audioOnly, path: url.path) else {
                return
        }
        recordingState.value = .recording
        fileName = name
    }

    lazy var showPlayerControls: Observable<Bool> = {
        return Observable
            .combineLatest(playerReady.asObservable(),
                           readyToSend.asObservable()) {(playerReady, fileReady) in
                            return (playerReady && fileReady)
        }
    }()

    func stopRecording() {
        self.videoService.stopLocalRecorder(path: fileName)
        recordingState.value = .recorded
        //create player after delay so recording could be finished
        DispatchQueue.main.asyncAfter(deadline: (.now() + 1)) { [weak self] in
            self?.createPlayer()
        }
    }

    let injectionBag: InjectionBag

    lazy var incomingFrame: Observable<RendererTuple?> = {
        return videoService.incomingVideoFrame.asObservable()
    }()

    func sendFile() {
        guard let fileUrl = URL(string: fileName) else {
            return
        }
        player?.closePlayer()
        self.player = nil
        let name = fileUrl.lastPathComponent
        guard let accountId = self.accountService.currentAccount?.id else {return}
        self.fileTransferService.sendFile(filePath: self.fileName,
                                          displayName: name,
                                          accountId: accountId,
                                          peerInfoHash: self.conversation.hash,
                                          localIdentifier: nil)
        self.videoService.videRecordingFinished()
        self.recordingState.value = .sent
    }

    func cancel() {
        if recordingState.value == .recording {
            self.stopRecording()
        }
        player?.closePlayer()
        self.player = nil
        self.videoService.videRecordingFinished()
        recordingState.value = .sent
        if fileName.isEmpty {
            return
        }
        try? FileManager.default.removeItem(atPath: fileName)
    }

    func switchCamera() {
        self.videoService.switchCamera()
    }

    //player
    var player: PlayerViewModel?

    var playerDuration = Variable<Float>(0)
    var playerPosition = PublishSubject<Float>()

    var seekTimeVariable = Variable<Float>(0) //player position set by user
    let playBackFrame = PublishSubject<UIImage?>()

    var pause = Variable<Bool>(true)
    var audioMuted = Variable<Bool>(true)
    var playerReady = Variable<Bool>(false)
    var playBackDisposeBag = DisposeBag()
}

// MARK: media player

extension SendFileViewModel {
    func userStartSeeking() {
        self.player?.userStartSeeking()
    }

    func userStopSeeking() {
        self.player?.userStopSeeking()
    }

    func toglePause() {
        self.player?.toglePause()
    }

    func muteAudio() {
        self.player?.muteAudio()
    }

    func seekToTime(time: Int) {
        self.player?.seekToTime(time: time)
    }

    func createPlayer() {
        player = PlayerViewModel(injectionBag: injectionBag, path: fileName)
        player?.createPlayer()
        player?.playerReady.asObservable()
            .filter({ (ready) -> Bool in
                return ready
            })
        .take(1)
        .subscribe(onNext: { [weak self] ready in
            self?.playerReady.value = ready
            self?.playBackDisposeBag = DisposeBag()
            self?.subscribePlayerControls()
        }).disposed(by: playBackDisposeBag)
    }

    func subscribePlayerControls() {
        player?.audioMuted.asObservable()
            .subscribe(onNext: { [weak self] muted in
                self?.audioMuted.value = muted
            }).disposed(by: playBackDisposeBag)

        player?.pause.asObservable()
            .subscribe(onNext: { [weak self] pause in
                self?.pause.value = pause
            }).disposed(by: playBackDisposeBag)

        player?.playerDuration.asObservable()
            .subscribe(onNext: { [weak self] duration in
                self?.playerDuration.value = duration
            }).disposed(by: playBackDisposeBag)

        player?.playerPosition.asObservable()
            .subscribe(onNext: { [weak self] position in
                self?.playerPosition.onNext(position)
            }).disposed(by: playBackDisposeBag)

        player?.playBackFrame.asObservable()
            .subscribe(onNext: { [weak self] image in
                self?.playBackFrame.onNext(image)
            }).disposed(by: playBackDisposeBag)

        seekTimeVariable.asObservable()
            .subscribe(onNext: { [weak self](position) in
                self?.player?.seekTimeVariable.value = position
            }).disposed(by: playBackDisposeBag)
    }

    func setCameraOrientation(orientation: UIDeviceOrientation) {
        videoService.setCameraOrientation(orientation: orientation)
    }
}
