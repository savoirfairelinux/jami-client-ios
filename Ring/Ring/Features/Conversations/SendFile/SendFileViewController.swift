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

import UIKit
import RxSwift
import Reusable
import SwiftyBeaver

class SendFileViewController: UIViewController, StoryboardBased, ViewModelBased {

    var viewModel: SendFileViewModel!
    fileprivate let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    @IBOutlet weak var preview: UIImageView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var placeholderButton: UIButton!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var placeholderLabel: UILabel!
    @IBOutlet weak var viewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRightConstraint: NSLayoutConstraint!

    @IBOutlet weak var playerControls: UIView!
    @IBOutlet weak var togglePause: UIButton!
    @IBOutlet weak var muteAudio: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var durationLabel: UILabel!

    var sliderDisposeBag = DisposeBag()

    @IBAction func startSeekFrame(_ sender: Any) {
        sliderDisposeBag = DisposeBag()
        self.viewModel.userStartSeeking()
        progressSlider.rx.value
        .subscribe(onNext: { [weak self] (value) in
            self?.viewModel.seekTimeVariable.value = Float(value)
        })
        .disposed(by: self.sliderDisposeBag)
    }

    @IBAction func stopSeekFrame(_ sender: UISlider) {
        sliderDisposeBag = DisposeBag()
        self.viewModel.userStopSeeking()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.applyL10()
        let isAudio = self.viewModel.audioOnly
        viewBottomConstraint.constant = isAudio ? 120 : 0
        viewLeftConstraint.constant = isAudio ? 20 : 0
        viewRightConstraint.constant = isAudio ? 20 : 0
        self.bindViewsToViewModel()
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (_) in
                //filter out upside orientation
                if  UIDevice.current.orientation.rawValue == 5 ||   UIDevice.current.orientation.rawValue == 6 {
                    return
                }
                guard let self = self else {
                    return
                }
                self.viewModel
                    .setCameraOrientation(orientation: UIDevice.current.orientation)
            }).disposed(by: self.disposeBag)
    }

    func applyL10() {
        self.sendButton.setTitle(L10n.DataTransfer.sendMessage, for: .normal)
        self.cancelButton.setTitle(L10n.Actions.cancelAction, for: .normal)
        self.infoLabel.text = L10n.DataTransfer.infoMessage
    }

    func bindViewsToViewModel() {
        self.viewModel.playBackFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.preview.image = image
                    }
                }
            }).disposed(by: self.disposeBag)
        self.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.cancel()
            }).disposed(by: self.disposeBag)
        self.recordButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.triggerRecording()
            }).disposed(by: self.disposeBag)
        self.sendButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.sendFile()
            }).disposed(by: self.disposeBag)
        self.switchButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchCamera()
            }).disposed(by: self.disposeBag)
        self.viewModel.hideVideoControls
            .observeOn(MainScheduler.instance)
            .bind(to: self.preview.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.hideVideoControls
            .observeOn(MainScheduler.instance)
            .bind(to: self.placeholderButton.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.readyToSend
            .map {!$0}
            .drive(self.sendButton.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.recording
            .map {!$0}
            .bind(to: self.timerLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.readyToSend
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] ready in
                let audioOnly: Bool = self?.viewModel.audioOnly ?? false
                self?.switchButton.isHidden = ready || audioOnly
            }).disposed(by: self.disposeBag)
        self.viewModel.readyToSend
            .drive(self.placeholderLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.recordDuration
            .drive(self.timerLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.finished
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] finished in
                if finished {
                    let animated: Bool = !(self?.viewModel.audioOnly ?? false)
                    self?.dismiss(animated: animated, completion: nil)
                }
            }).disposed(by: self.disposeBag)
        self.viewModel.recording
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] recording in
                if recording {
                    self?.animateRecordingButton()
                } else {
                    self?.recordButton.layer.removeAllAnimations()
                }
            }).disposed(by: self.disposeBag)
        self.viewModel.hideInfo
            .drive(self.infoLabel.rx.isHidden)
            .disposed(by: self.disposeBag)
        configurePlayerControls()
    }

    func configurePlayerControls() {
        self.viewModel.showPlayerControls
            .map {!$0}
            .bind(to: self.playerControls.rx.isHidden)
            .disposed(by: self.disposeBag)
        self.viewModel.playerPosition
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.progressSlider.value = position
            }).disposed(by: self.disposeBag)
        self.viewModel.playerDuration
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                let durationString = self?.durationString(microcec: duration) ?? ""
                self?.durationLabel.text = durationString
            }).disposed(by: self.disposeBag)
        self.viewModel.pause
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] pause in
                var image = UIImage(asset: Asset.pauseCall)
                if pause {
                    image = UIImage(asset: Asset.unpauseCall)
                }
                self?.togglePause.setBackgroundImage(image, for: .normal)
            }).disposed(by: self.disposeBag)
        self.viewModel.audioMuted
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                var image = UIImage(asset: Asset.audioOn)
                if muted {
                    image = UIImage(asset: Asset.audioOff)
                }
                self?.muteAudio.setBackgroundImage(image, for: .normal)
            }).disposed(by: self.disposeBag)
        self.muteAudio.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            }).disposed(by: self.disposeBag)
        self.togglePause.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toglePause()
            }).disposed(by: self.disposeBag)
    }

    func durationString(microcec: Float) -> String {
        if microcec == 0 {
            return ""
        }
        let durationInSec = Int(microcec / 1000000)
        let seconds = durationInSec % 60
        let minutes = (durationInSec / 60) % 60
        let hours = (durationInSec / 3600)
        switch hours {
        case 0:
            return String(format: "%02d:%02d", minutes, seconds)
        default:
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    func animateRecordingButton() {
        UIView
            .animate(withDuration: 1,
                     delay: 0.0,
                     options: [.curveEaseInOut,
                               .allowUserInteraction,
                               .autoreverse,
                               .repeat],
                     animations: { [weak self] in
                        self?.recordButton.alpha = 0.1
                },
                     completion: { [weak self] _ in
                        self?.recordButton.alpha = 1.0
            })
    }
}
