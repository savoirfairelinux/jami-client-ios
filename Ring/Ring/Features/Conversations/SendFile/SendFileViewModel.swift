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

    lazy var duration: Driver<String> = {
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
            return state == .recording
        }).flatMap({ _ in
            return durationTimer
        }).asDriver(onErrorJustReturn: "")
    }()

    var audioOnly: Bool = false
    fileprivate let videoService: VideoService
    fileprivate let accountService: AccountsService
    fileprivate let fileTransferService: DataTransferService
    fileprivate let audioService: AudioService
    var fileName = ""

    var conversation: ConversationModel!

    required init(with injectionBag: InjectionBag) {
        self.videoService = injectionBag.videoService
        self.accountService = injectionBag.accountService
        self.fileTransferService = injectionBag.dataTransferService
        self.audioService = injectionBag.audioService
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

    var playerDuration = PublishSubject<String>()
    var playerPosition = PublishSubject<Float>()
    var durationDouble: Float = 0

    var progressTimer: Timer?
    var seekTimeVariable = Variable<Float>(0)

    func stopRecording() {
        self.videoService.stopLocalRecorder(path: fileName)
        recordingState.value = .recorded
        let fname = "file://" + fileName
        playerId = videoService.createPlayer(path: fname)
        pause = true
        audioMuted = true
        playerPosition.onNext(0)

        // subscribe for frame playback
        playBackDisposeBag = DisposeBag()
        incomingFrame.filter { (render) -> Bool in
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

//            if @available(iOS 10.0, *) do {
//            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (timer) in
//                let time = self.videoService.getPlayerPosition(playerId: self.playerId)
//                       if time < 0 {
//                           return
//                       }
//                let progress = Float(time) / self.durationDouble
//                self.playerPosition.onNext(progress)
//            }
//            }
//            Timer
//            .scheduledTimer(timeInterval: 0.5,
//                            target: self,
//                            selector: #selector(self.updatetimer),
//                            userInfo: nil,
//                            repeats: true)
            return self.incomingFrame.filter { (render) -> Bool in
                render?.rendererId == self.playerId
            }
        })
        .merge()
        .subscribe(onNext: { (renderer) in
            self.playBackFrame.onNext(renderer?.data)
        }).disposed(by: playBackDisposeBag)

        // subscribe for fileInfo
        self.videoService.playerInfo
            .asObservable()
            .filter { (player) -> Bool in
                player.playerId == self.playerId
        }
        .take(1)
        .subscribe(onNext: { player in
            self.toglePause()
            self.playerDuration.onNext(player.duration)
            self.durationDouble =  Float(player.duration) as! Float
        }).disposed(by: playBackDisposeBag)
    }

//    @objc func updatetimer(timer: Timer) {
//        let time = self.videoService.getPlayerPosition(playerId: playerId)
//        if time < 0 {
//            return
//        }
//        let progress = Float(time) / durationDouble
//        playerPosition.onNext(progress)
////        guard let userInfoDict = timer.userInfo as? NSDictionary else { return }
////        guard let transferId = userInfoDict["transferId"] as? UInt64 else { return }
////        guard let viewModel = userInfoDict["conversationViewModel"] as? ConversationViewModel else { return }
////        if let progress = viewModel.getTransferProgress(transferId: transferId) {
////            DispatchQueue.main.async {
////                self.progressBar.progress = progress
////            }
////        }
//    }

    let playBackFrame = PublishSubject<UIImage?>()

    var playerId = ""
    var pause = true
    var audioMuted = true

    func toglePause() {
        pause = !pause
        videoService.pausePlayer(playerId: playerId, pause: pause)
    }

    func muteAudio() {
        audioMuted = !audioMuted
        videoService.mutePlayerAudio(playerId: playerId, mute: audioMuted)
    }

    func seekToTime(time: Int) {
        videoService.seekToFrame(playerId: playerId, time: time)
    }

    lazy var incomingFrame: Observable<RendererTuple?> = {
        return videoService.incomingVideoFrame.asObservable()
    }()

    var firstFrame: Bool = true

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
        self.videoService.videRecordingFinished()
        recordingState.value = .sent
    }

    func cancel() {
        if recordingState.value == .recording {
            self.stopRecording()
        }
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

    func userStartProgress() {
        invalidateTimer()
        pause = true
        videoService.pausePlayer(playerId: playerId, pause: pause)
    }

    func userStopProgress() {
        let time = Int(self.durationDouble * seekTimeVariable.value)
        self.videoService.seekToFrame(playerId: playerId, time: time)
        startTimer()
        pause = false
        videoService.pausePlayer(playerId: playerId, pause: pause)
    }

    func invalidateTimer() {
        if self.progressTimer != nil {
            self.progressTimer?.invalidate()
        }
        self.progressTimer = nil
    }

    func startTimer() {
        if #available(iOS 10.0, *) {
                       DispatchQueue.main.async {
                           self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (timer) in
                                  let time = self.videoService.getPlayerPosition(playerId: self.playerId)
                                         if time < 0 {
                                             return
                                         }
                                  let progress = Float(time) / self.durationDouble
                                  self.playerPosition.onNext(progress)
                              }
                          }
                   }

    }
}
