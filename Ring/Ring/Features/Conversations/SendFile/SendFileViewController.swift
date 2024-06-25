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

import Reusable
import RxSwift
import SwiftyBeaver
import UIKit

class SendFileViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: SendFileViewModel!
    private let disposeBag = DisposeBag()
    private let log = SwiftyBeaver.self

    @IBOutlet var preview: UIImageView!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var switchButton: UIButton!
    @IBOutlet var placeholderButton: UIButton!
    @IBOutlet var timerLabel: UILabel!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var placeholderLabel: UILabel!
    @IBOutlet var viewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var viewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var viewRightConstraint: NSLayoutConstraint!

    @IBOutlet var playerControls: UIView!
    @IBOutlet var togglePause: UIButton!
    @IBOutlet var muteAudio: UIButton!
    @IBOutlet var progressSlider: UISlider!
    @IBOutlet var durationLabel: UILabel!

    var sliderDisposeBag = DisposeBag()

    @IBAction func startSeekFrame(_: Any) {
        sliderDisposeBag = DisposeBag()
        viewModel.userStartSeeking()
        progressSlider.rx.value
            .subscribe(onNext: { [weak self] value in
                self?.viewModel.seekTimeVariable.accept(Float(value))
            })
            .disposed(by: sliderDisposeBag)
    }

    @IBAction func stopSeekFrame(_: UISlider) {
        sliderDisposeBag = DisposeBag()
        viewModel.userStopSeeking()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyL10()
        let isAudio = viewModel.audioOnly
        viewBottomConstraint.constant = isAudio ? 120 : 0
        viewLeftConstraint.constant = isAudio ? 20 : 0
        viewRightConstraint.constant = isAudio ? 20 : 0
        bindViewsToViewModel()
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else { return }
                self.viewModel
                    .setCameraOrientation(orientation: UIDevice.current.orientation)
            })
            .disposed(by: disposeBag)
    }

    func applyL10() {
        sendButton.setTitle(L10n.DataTransfer.sendMessage, for: .normal)
        cancelButton.setTitle(L10n.Global.cancel, for: .normal)
        infoLabel.text = L10n.DataTransfer.infoMessage
    }

    func bindViewsToViewModel() {
        viewModel.playBackFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.preview.image = image
                    }
                }
            })
            .disposed(by: disposeBag)
        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.cancel()
            })
            .disposed(by: disposeBag)
        recordButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.triggerRecording()
            })
            .disposed(by: disposeBag)
        sendButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.sendFile()
            })
            .disposed(by: disposeBag)
        switchButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchCamera()
            })
            .disposed(by: disposeBag)
        viewModel.hideVideoControls
            .observe(on: MainScheduler.instance)
            .bind(to: preview.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.hideVideoControls
            .observe(on: MainScheduler.instance)
            .bind(to: placeholderButton.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.readyToSend
            .map { !$0 }
            .drive(sendButton.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.recording
            .map { !$0 }
            .bind(to: timerLabel.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.readyToSend
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] ready in
                let audioOnly: Bool = self?.viewModel.audioOnly ?? false
                self?.switchButton.isHidden = ready || audioOnly
            })
            .disposed(by: disposeBag)
        viewModel.readyToSend
            .drive(placeholderLabel.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.recordDuration
            .drive(timerLabel.rx.text)
            .disposed(by: disposeBag)
        viewModel.finished
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] finished in
                if finished {
                    let animated: Bool = !(self?.viewModel.audioOnly ?? false)
                    self?.dismiss(animated: animated, completion: nil)
                }
            })
            .disposed(by: disposeBag)
        viewModel.recording
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] recording in
                if recording {
                    self?.animateRecordingButton()
                } else {
                    self?.recordButton.layer.removeAllAnimations()
                }
            })
            .disposed(by: disposeBag)
        viewModel.hideInfo
            .drive(infoLabel.rx.isHidden)
            .disposed(by: disposeBag)
        configurePlayerControls()
    }

    func configurePlayerControls() {
        viewModel.showPlayerControls
            .map { !$0 }
            .bind(to: playerControls.rx.isHidden)
            .disposed(by: disposeBag)
        viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.progressSlider.value = position
            })
            .disposed(by: disposeBag)
        viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                let durationString = self?.durationString(microcec: duration) ?? ""
                self?.durationLabel.text = durationString
            })
            .disposed(by: disposeBag)
        viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pause in
                var image = UIImage(asset: Asset.pauseCall)
                if pause {
                    image = UIImage(asset: Asset.unpauseCall)
                }
                self?.togglePause.setBackgroundImage(image, for: .normal)
            })
            .disposed(by: disposeBag)
        viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                var image = UIImage(asset: Asset.audioOn)
                if muted {
                    image = UIImage(asset: Asset.audioOff)
                }
                self?.muteAudio.setBackgroundImage(image, for: .normal)
            })
            .disposed(by: disposeBag)
        muteAudio.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.muteAudio()
            })
            .disposed(by: disposeBag)
        togglePause.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toglePause()
            })
            .disposed(by: disposeBag)
    }

    func durationString(microcec: Float) -> String {
        if microcec == 0 {
            return ""
        }
        let durationInSec = Int(microcec / 1_000_000)
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
