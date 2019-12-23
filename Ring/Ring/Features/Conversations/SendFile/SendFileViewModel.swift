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
        if !audioOnly {
            videoService.prepareVideoRecording()
        }
        videoService.capturedVideoFrame.asObservable()
       .subscribe(onNext: { frame in
            self.playBackFrame.onNext(frame)
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
        videoService.closePlayer(playerId: playerId)
        self.playerDuration.value = 0
        invalidateTimer()
        videoService.restartSettings()
        playBackDisposeBag = DisposeBag()
        videoService.capturedVideoFrame.asObservable()
            .subscribe(onNext: { frame in
                self.playBackFrame.onNext(frame)
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

    //player
    var playBackDisposeBag = DisposeBag()

    var playerDuration = Variable<Float>(0)
    var playerPosition = PublishSubject<Float>()

    var progressTimer: Timer?
    var seekTimeVariable = Variable<Float>(0) //player position set by user
    let playBackFrame = PublishSubject<UIImage?>()

    var playerId = ""
    var pause = Variable<Bool>(true)
    var audioMuted = Variable<Bool>(true)
    var playerReady = Variable<Bool>(false)

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
        DispatchQueue.main.asyncAfter(deadline: (.now() + 0.3)) { [unowned self] in
            self.createPlayer()
        }
    }

    @objc func updateTimer(timer: Timer) {
        let time = self.videoService.getPlayerPosition(playerId: self.playerId)
        if time < 0 {
            return
        }
        let progress = Float(time) / self.playerDuration.value
        self.playerPosition.onNext(progress)
    }

    func createPlayer() {
        self.playerReady.value = false
        invalidateTimer()
        let fname = "file://" + fileName
        self.playerId = self.videoService.createPlayer(path: fname)
        self.pause.value = true
        self.audioMuted.value = true
        self.playerPosition.onNext(0)
        // subscribe for frame playback
        //get first frame, pause player and seek back to first frame
        self.playBackDisposeBag = DisposeBag()
        self.incomingFrame.filter { (render) -> Bool in
            render?.rendererId == self.playerId
        }
        .take(1)
        .map({(renderer) -> Observable<RendererTuple?>  in
            self.toglePause()
            self.muteAudio()
            self.seekToTime(time: 0)
            self.playBackFrame.onNext(renderer?.data)
            self.playerPosition.onNext(0)
            self.startTimer()
            self.playerReady.value = true
            return self.incomingFrame.filter { (render) -> Bool in
                render?.rendererId == self.playerId
            }
        })
            .merge()
            .subscribe(onNext: { (renderer) in
                self.playBackFrame.onNext(renderer?.data)
            }).disposed(by: self.playBackDisposeBag)

        // subscribe for fileInfo
        self.videoService.playerInfo
            .asObservable()
            .filter { (player) -> Bool in
                player.playerId == self.playerId
        }
        .take(1)
        .subscribe(onNext: { player in
            guard let duration = Float(player.duration) else {
                self.videoService.closePlayer(playerId: self.playerId)
                return
            }
            self.playerDuration.value = duration
            if !player.hasVideo {
                self.seekToTime(time: 0)
                self.muteAudio()
                self.startTimer()
                self.playerReady.value = true
                return
            }
            self.toglePause()
        }).disposed(by: self.playBackDisposeBag)
    }

    func toglePause() {
        pause.value = !pause.value
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
    }

    func muteAudio() {
        audioMuted.value = !audioMuted.value
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted.value)
    }

    func seekToTime(time: Int) {
        videoService.seekToTime(time: time, playerId: playerId)
    }

    lazy var incomingFrame: Observable<RendererTuple?> = {
        return videoService.incomingVideoFrame.asObservable()
    }()

    func sendFile() {
        guard let fileUrl = URL(string: fileName) else {
            return
        }
        let name = fileUrl.lastPathComponent
        guard let accountId = accountService.currentAccount?.id else {return}
        self.fileTransferService.sendFile(filePath: fileName,
                                          displayName: name,
                                          accountId: accountId,
                                          peerInfoHash: self.conversation.hash,
                                          localIdentifier: nil)
        videoService.closePlayer(playerId: playerId)
        invalidateTimer()
        self.videoService.videRecordingFinished()
        recordingState.value = .sent
    }

    func cancel() {
        if recordingState.value == .recording {
            self.stopRecording()
        }
        invalidateTimer() 
        videoService.closePlayer(playerId: playerId)
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

    func userStartSeeking() {
        invalidateTimer()
        pause.value = true
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
    }

    func userStopSeeking() {
        let time = Int(self.playerDuration.value * seekTimeVariable.value)
        self.videoService.seekToTime(time: time, playerId: playerId)
        pause.value = false
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
}
