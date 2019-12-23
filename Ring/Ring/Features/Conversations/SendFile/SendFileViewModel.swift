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

    lazy var capturedFrame: Observable<UIImage?> = {
        if !audioOnly {
            videoService.prepareVideoRecording()
        }
        return videoService.capturedVideoFrame.asObservable()
            .filter({ (image) -> Bool in
                return !self.displayMode
            })
            .map({ frame in
                return !self.displayMode ? frame : nil
        })
    }()

    lazy var incomingFrame: Observable<UIImage?> = {
        return videoService.incomingVideoFrame.asObservable()
            .filter({ (render) -> Bool in
                render?.rendererId == self.sink
            })
            .map({ renderer in
//                if self.firstFrame {
//                    self.firstFrame = false
//                    self.paused = true
//                    self.videoService.togglePause(sink: self.sink, paused: self.paused)
//                }
                return renderer?.data
        })
    }()

    var firstFrame: Bool = true

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
    }

    func triggerRecording() {
        if recordingState.value == .recording {
            self.stopRecording()
            return
        }
        startRecording()
    }

    func startRecording() {
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

    func stopRecording() {
        self.videoService.stopLocalRecorder(path: fileName)
        recordingState.value = .recorded
    }

    var sink = ""

    var paused = true

    func sendFile() {
        guard let fileUrl = URL(string: fileName) else {
            return
        }
        displayMode = true
        self.videoService.stopCapture()
        let fname = "file://" + fileName
        audioService.overrideToSpeaker()
        sink = videoService.openFile(path: fname)
//        paused = false
//        videoService.togglePause(sink: sink, paused: paused)
        let name = fileUrl.lastPathComponent
        return
        guard let accountId = accountService.currentAccount?.id else {return}
        self.fileTransferService.sendFile(filePath: fileName,
                                          displayName: name,
                                          accountId: accountId,
                                          peerInfoHash: self.conversation.hash,
                                          localIdentifier: nil)
        self.videoService.videRecordingFinished()
        recordingState.value = .sent
    }

    func toglePause() {
        paused = !paused
        videoService.togglePause(sink: sink, paused: paused)
    }

    func cancel() {
        videoService.stopPlayer(sink: sink)
//        if recordingState.value == .recording {
//            self.stopRecording()
//        }
//        self.videoService.videRecordingFinished()
//        recordingState.value = .sent
//        if fileName.isEmpty {
//            return
//        }
//        try? FileManager.default.removeItem(atPath: fileName)
    }

    var displayMode = false

    func switchCamera() {
        self.videoService.switchCamera()
    }
}
