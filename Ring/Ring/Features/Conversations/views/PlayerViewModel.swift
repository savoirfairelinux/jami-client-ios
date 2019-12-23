//
//  PlayerViewModel.swift
//  Ring
//
//  Created by Kateryna Kostiuk on 2020-01-02.
//  Copyright © 2020 Savoir-faire Linux. All rights reserved.
//

import RxSwift
import RxCocoa

protocol PlayerDelegate: class {
    func extractedVideoFrame(with height: CGFloat)
}

class PlayerViewModel {
    let disposeBag = DisposeBag()
    var audioOnly: Bool = false
    fileprivate let videoService: VideoService
    let filePath: String
    weak var delegate: PlayerDelegate?
    var playerId = ""

    init(injectionBag: InjectionBag, path: String) {
        self.videoService = injectionBag.videoService
        filePath = path
        print("***init player")
    }

      var playBackDisposeBag = DisposeBag()

      var playerDuration = Variable<Float>(0)
      var playerPosition = PublishSubject<Float>()

      var progressTimer: Timer?
      var seekTimeVariable = Variable<Float>(0)
      let playBackFrame = PublishSubject<UIImage?>()

      var pause = Variable<Bool>(true)
      var audioMuted = Variable<Bool>(true)
      var playerReady = Variable<Bool>(false)

    var firstFrame: UIImage?

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
        print ("***create player")
        self.playerId = self.videoService.createPlayer(path: fname)
        self.pause.value = true
        self.audioMuted.value = true
        self.playerPosition.onNext(0)
        // subscribe for frame playback
        //get first frame, pause player and seek back to first frame
        self.playBackDisposeBag = DisposeBag()
        self.incomingFrame.filter {  [weak self] (render) -> Bool in
            render?.rendererId == self?.playerId
        }
        .take(1)
        .map({(renderer) -> Observable<RendererTuple?>  in
            self.firstFrame = renderer?.data
            self.toglePause()
            self.muteAudio()
            self.seekToTime(time: 0)
            self.playBackFrame.onNext(renderer?.data)
            self.playerPosition.onNext(0)
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
            guard let duration = Float(player.duration) else {
                self.videoService.closePlayer(playerId: self.playerId)
                return
            }
            if duration <= 0 {
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
         print ("***deinit player")
         invalidateTimer()
         videoService.closePlayer(playerId: playerId)
    }

    func closePlayer() {
        self.invalidateTimer()
        videoService.closePlayer(playerId: playerId)
    }
}
