/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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
import Chameleon
import RxSwift
import Reusable
import SwiftyBeaver

class CallViewController: UIViewController, StoryboardBased, ViewModelBased {

    //preview screen
    @IBOutlet private weak var profileImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var infoBottomLabel: UILabel!
    @IBOutlet weak var avatarView: UIView!

    @IBOutlet private weak var mainView: UIView!

    //video screen
    @IBOutlet private weak var callView: UIView!
    @IBOutlet private weak var incomingVideo: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var capturedVideo: UIImageView!
    @IBOutlet weak var capturedVideoWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var infoContainer: UIView!
    @IBOutlet weak var infoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var callProfileImage: UIImageView!
    @IBOutlet private weak var callNameLabel: UILabel!
    @IBOutlet private weak var callInfoTimerLabel: UILabel!
    @IBOutlet private weak var infoLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var callPulse: UIView!

    @IBOutlet private weak var buttonsContainer: ButtonsContainerView!
    @IBOutlet weak var buttonsContainerHeightConstraint: NSLayoutConstraint!

    var viewModel: CallViewModel!

    fileprivate let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    private var task: DispatchWorkItem?

    private var shouldRotateScreen = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setColorButtons()
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
        self.setUpCallButtons()
        self.setupBindings()
        let device = UIDevice.modelName
        switch device {
        case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR" :
            //keep the 4:3 format of the captured video on iPhone X and later when display it in full screen
            if !self.avatarView.isHidden {
                self.capturedVideoWidthConstraint.constant += 200
                self.capturedVideoTrailingConstraint.constant = (self.capturedVideoWidthConstraint.constant - UIScreen.main.bounds.width) / 2
                self.infoLabelHeightConstraint.constant = 90
            }
        default :
            //On other devices, we don't have notch, so the infoContainerHeightConstraint should be smaller
            self.infoContainerHeightConstraint.constant = 204
        }
        if self.viewModel.isAudioOnly {
            // The durationLabel and buttonsContainer alpha is set here to 0, and to 1 (with a duration) when appear on the screen to have a fade in animation
            self.durationLabel.alpha = 0
            self.buttonsContainer.stackView.alpha = 0
            self.showAllInfo()
            self.setWhiteAvatarView()
        } else {
            UIApplication.shared.statusBarStyle = .lightContent
        }

        UIDevice.current.isProximityMonitoringEnabled = self.viewModel.isAudioOnly

        initCallAnimation()
    }

    func setColorButtons() {
        if !(self.viewModel.call?.isAudioOnly ?? false) {
            self.buttonsContainer.cancelButton.backgroundColor = UIColor.white
            self.buttonsContainer.muteAudioButton.tintColor = UIColor.white
            self.buttonsContainer.muteAudioButton.borderColor = UIColor.white
            self.buttonsContainer.muteVideoButton.tintColor = UIColor.white
            self.buttonsContainer.muteVideoButton.borderColor = UIColor.white
            self.buttonsContainer.pauseCallButton.tintColor = UIColor.white
            self.buttonsContainer.pauseCallButton.borderColor = UIColor.white
            self.buttonsContainer.switchCameraButton.tintColor = UIColor.white
            self.buttonsContainer.switchCameraButton.borderColor = UIColor.white
            self.buttonsContainer.switchSpeakerButton.tintColor = UIColor.white
            self.buttonsContainer.switchSpeakerButton.borderColor = UIColor.white
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    func setWhiteAvatarView() {
                UIApplication.shared.statusBarStyle = .default
                self.callPulse.backgroundColor = UIColor.ringCallPulse
                self.avatarView.backgroundColor = UIColor.white
                self.nameLabel.textColor = UIColor.ringCallInfos
                self.durationLabel.textColor = UIColor.ringCallInfos
                self.infoBottomLabel.textColor = UIColor.ringCallInfos
    }

    func initCallAnimation() {
        self.callPulse.alpha = 0.5
        self.callPulse.layer.cornerRadius = self.callPulse.frame.size.width / 2
        animateCallCircle()
    }

    func animateCallCircle() {
        self.callPulse.alpha = 0.5
        self.callPulse.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        UIView.animate(withDuration: 1.5, animations: {
            self.callPulse.alpha = 0.0
            self.callPulse.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            self.view.layoutIfNeeded()
        }, completion: { [unowned self] _ in
            if self.viewModel.call?.state == .ringing || self.viewModel.call?.state == .connecting {
                self.animateCallCircle()
            }
        })
    }

    func setUpCallButtons() {
        self.buttonsContainer.viewModel = self.viewModel.containerViewModel
        self.buttonsContainerHeightConstraint.constant = self.buttonsContainer.containerHeightConstraint.constant
        //bind actions
        self.buttonsContainer.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.removeFromScreen()
                self?.viewModel.cancelCall()
            }).disposed(by: self.disposeBag)

        self.buttonsContainer.muteAudioButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toggleMuteAudio()
            }).disposed(by: self.disposeBag)

        if !(self.viewModel.call?.isAudioOnly ?? false) {
            self.buttonsContainer.muteVideoButton.rx.tap
                .subscribe(onNext: { [weak self] in
                    self?.viewModel.toggleMuteVideo()
                }).disposed(by: self.disposeBag)
        }

        self.buttonsContainer.pauseCallButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.togglePauseCall()
            }).disposed(by: self.disposeBag)

        self.buttonsContainer.switchCameraButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchCamera()
            }).disposed(by: self.disposeBag)

        self.buttonsContainer.switchSpeakerButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchSpeaker()
            }).disposed(by: self.disposeBag)

        //Data bindings
        self.viewModel.videoButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.buttonsContainer.muteVideoButton.rx.image())
            .disposed(by: self.disposeBag)

        self.buttonsContainer.muteVideoButton.isEnabled = !(self.viewModel.call?.isAudioOnly ?? false)

        self.viewModel.audioButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.buttonsContainer.muteAudioButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.speakerButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.buttonsContainer.switchSpeakerButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.pauseCallButtonState
            .observeOn(MainScheduler.instance)
            .bind(to: self.buttonsContainer.pauseCallButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.isActiveVideoCall
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] rotate in
                self?.shouldRotateScreen = rotate
            }).disposed(by: self.disposeBag)

        // disable switch camera button for audio only calls
        self.buttonsContainer.switchCameraButton.isEnabled = !(self.viewModel.isAudioOnly)
    }

    func setupBindings() {

        self.viewModel.contactImageData?.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dataOrNil in
                if let imageData = dataOrNil {
                    if let image = UIImage(data: imageData) {
                        self?.profileImageView.image = image
                        self?.callProfileImage.image = image
                    }
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.dismisVC
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.callNameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.durationLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.asObservable().observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if self?.durationLabel.text == "00:00:00" {
                    UIView.animate(withDuration: 0.3, animations: {
                        self?.durationLabel.alpha = 1
                        self?.buttonsContainer.stackView.alpha = 1
                    })
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.callInfoTimerLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.bottomInfo
            .observeOn(MainScheduler.instance)
            .bind(to: self.infoBottomLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.incomingFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    self?.spinner.stopAnimating()
                    DispatchQueue.main.async {
                        self?.incomingVideo.image = image
                    }
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.capturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.capturedVideo.image = image
                    }
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.showCallOptions
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { show in
                if show {
                    self.showContactInfo()
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.showCancelOption
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { show in
                if show {
                    self.showCancelButton()
                }
            }).disposed(by: self.disposeBag)

        if !self.viewModel.isAudioOnly {
            self.setupShowCapturedFrame()
        }

        self.viewModel.videoMuted
            .observeOn(MainScheduler.instance)
            .bind(to: self.capturedVideo.rx.isHidden)
            .disposed(by: self.disposeBag)

        if !self.viewModel.isAudioOnly {
            self.viewModel.callPaused
                .observeOn(MainScheduler.instance)
                .map({value in return !value })
                .bind(to: self.avatarView.rx.isHidden)
                .disposed(by: self.disposeBag)
        }

        self.viewModel.callPaused
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] show in
                if show {
                    self.task?.cancel()
                    self.showCallOptions()
                }
            }).disposed(by: self.disposeBag)
    }

    func setupShowCapturedFrame() {
        self.viewModel.showCapturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { dontShow in
                if dontShow {
                    self.showAllInfo()
                    DispatchQueue.global(qos: .background).async {
                        sleep(3)
                        DispatchQueue.main.async {
                            self.hideContactInfo()
                            self.hideCancelButton()
                        }
                    }
                    UIView.animate(withDuration: 0.4, animations: { [unowned self] in
                                    let device = UIDevice.modelName
                                    switch device {
                                    case "iPhone X", "iPhone XS", "iPhone XS Max", "iPhone XR" :
                                        self.capturedVideoTopConstraint.constant = 40
                                    default :
                                        self.capturedVideoTopConstraint.constant = 32
                                    }
                                    self.capturedVideoTrailingConstraint.constant = 10
                                    self.capturedVideoWidthConstraint.constant = -UIScreen.main.bounds.width + 120
                                    self.capturedVideoHeightConstraint.constant = -UIScreen.main.bounds.height + 160
                                    self.capturedVideo.cornerRadius = 10
                                    self.view.layoutIfNeeded()
                        }, completion: nil)
                }
            }).disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        UIDevice.current.isProximityMonitoringEnabled = false
        self.dismiss(animated: false)
    }

    @objc func screenTapped() {
        self.viewModel.respondOnTap()
    }

    func showCancelButton() {
        self.buttonsContainer.isHidden = false
        self.view.layoutIfNeeded()
    }

    func hideCancelButton() {
        self.buttonsContainer.isHidden = true
        self.view.layoutIfNeeded()
    }

    func showCallOptions() {
        self.buttonsContainer.isHidden = false
        self.view.layoutIfNeeded()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeRight, .landscapeLeft:
            let height = size.height - 150
            self.infoLabelHeightConstraint.constant = height
        default:
           self.infoLabelHeightConstraint.constant = 200
        }
        self.viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
        super.viewWillTransition(to: size, with: coordinator)
    }

    func showContactInfo() {
        if !self.infoContainer.isHidden {
            task?.cancel()
            self.hideContactInfo()
            return
        }
        self.buttonsContainer.isHidden = false
        self.infoContainer.isHidden = false
        self.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.4, delay: 0.0,
                       options: .curveEaseOut,
                       animations: { [unowned self] in
                        self.infoContainer.alpha = 1
                        self.buttonsContainer.alpha = 1
                        self.view.layoutIfNeeded()
            }, completion: nil)

        task = DispatchWorkItem { self.hideContactInfo() }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 7, execute: task!)
    }

    func hideContactInfo() {
            UIView.animate(withDuration: 0.4, delay: 0.00,
                           options: .curveEaseOut,
                           animations: { [unowned self] in
                            self.infoContainer.alpha = 0
                            self.buttonsContainer.alpha = 0
                            self.view.layoutIfNeeded()
                }, completion: { [weak self] _ in
                    self?.infoContainer.isHidden = true
                    self?.buttonsContainer.isHidden = true
            })
    }

    func showAllInfo() {
        self.buttonsContainer.isHidden = false
        self.infoContainer.isHidden = false
    }

    @objc func canRotate() {
        // empty function to support call screen rotation
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        super.viewWillDisappear(animated)
    }

    override var shouldAutorotate: Bool {
      return self.shouldRotateScreen
    }
}
