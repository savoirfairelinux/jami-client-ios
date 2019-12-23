/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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
import RxCocoa

protocol PlayerDelegate: class {
    func extractedVideoFrame(with height: CGFloat)
}

class PlayerViewModel {
    var hasVideo = Variable<Bool>(true)
    var playerDuration = Variable<Float>(0)
    var playerPosition = PublishSubject<Float>()
    let seekTimeVariable = Variable<Float>(0)
    let playBackFrame = PublishSubject<UIImage?>()

    let pause = Variable<Bool>(true)
    let audioMuted = Variable<Bool>(true)
    let playerReady = Variable<Bool>(false)
    weak var delegate: PlayerDelegate?

    var firstFrame: UIImage?

    fileprivate let disposeBag = DisposeBag()
    fileprivate var playBackDisposeBag = DisposeBag()

    fileprivate let videoService: VideoService
    fileprivate let filePath: String
    fileprivate var playerId = ""
    fileprivate var progressTimer: Timer?

    init(injectionBag: InjectionBag, path: String) {
        self.videoService = injectionBag.videoService
        filePath = path
    }

    func createPlayer() {
        self.playerReady.value = false
        let fname = "file://" + filePath
        if !self.playerId.isEmpty {
            if let frame = firstFrame {
                self.playerReady.value = true
                self.playBackFrame.onNext(frame)
            }
            return
        }
        invalidateTimer()
        self.playerId = self.videoService.createPlayer(path: fname)
        self.pause.value = true
        self.playerPosition.onNext(0)
        // subscribe for frame playback
        //get first frame, pause player and seek back to first frame
        self.playBackDisposeBag = DisposeBag()
        self.incomingFrame.filter {  [weak self] (render) -> Bool in
            render?.rendererId == self?.playerId
        }
        .take(1)
        .map({[unowned self] (renderer) -> Observable<RendererTuple?>  in
            self.firstFrame = renderer?.data
            self.playBackFrame.onNext(renderer?.data)
            self.playerPosition.onNext(0)
            self.toglePause()
            self.muteAudio()
            self.seekToTime(time: 0)
            self.startTimer()
            self.playerReady.value = true
            if let image = renderer?.data {
                DispatchQueue.main.async {
                    self.delegate?.extractedVideoFrame(with: image.size.height)
                }
            }
            return self.incomingFrame.filter {  [weak self] (render) -> Bool in
                render?.rendererId == self?.playerId
            }
        })
            .merge()
            .subscribe(onNext: {  [weak self] (renderer) in
                self?.playBackFrame.onNext(renderer?.data)
            }).disposed(by: self.playBackDisposeBag)

        // subscribe for fileInfo
        self.videoService.playerInfo
            .asObservable()
            .filter {  [weak self] (player) -> Bool in
                player.playerId == self?.playerId
        }
        .take(1)
        .subscribe(onNext: {  [unowned self] player in
            guard let duration = Float(player.duration),
            duration > 0 else {
                self.videoService.closePlayer(playerId: self.playerId)
                return
            }
            self.playerDuration.value = duration
            self.hasVideo.value = player.hasVideo
            if !player.hasVideo {
                self.startTimer()
                self.playerReady.value = true
                return
            }
            // mute audio so it is not played when extracting first frame
            self.audioMuted.value = true
            self.videoService.mutePlayerAudio(playerId: player.playerId,
                                              mute: self.audioMuted.value)
            //unpause player to get first video frame
            self.toglePause()
        }).disposed(by: self.playBackDisposeBag)
    }

    func userStartSeeking() {
        invalidateTimer()
        if pause.value {
            return
        }
        pause.value = true
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
    }

    func userStopSeeking() {
        pause.value = false
        videoService.pausePlayer(playerId: playerId, pause: pause.value)
        startTimer()
        let time = Int(self.playerDuration.value * seekTimeVariable.value)
        self.videoService.seekToTime(time: time, playerId: playerId)
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

    @objc func updateTimer(timer: Timer) {
        let time = self.videoService.getPlayerPosition(playerId: self.playerId)
        if time < 0 {
            return
        }
        let progress = Float(time) / self.playerDuration.value
        self.playerPosition.onNext(progress)
    }

    deinit {
        closePlayer()
    }

    func closePlayer() {
        self.invalidateTimer()
        videoService.closePlayer(playerId: playerId)
    }
}
