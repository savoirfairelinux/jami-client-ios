/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

// swiftlint:disable type_body_length
// swiftlint:disable file_length
class CallViewController: UIViewController, StoryboardBased, ViewModelBased {

    //preview screen
    @IBOutlet private weak var profileImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet private weak var infoBottomLabel: UILabel!
    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var avatarViewBlurEffect: UIVisualEffectView!
    @IBOutlet private weak var callPulse: UIView!

    @IBOutlet private weak var mainView: UIView!

    //video screen
    @IBOutlet private weak var callView: UIView!
    @IBOutlet private weak var incomingVideo: UIImageView!
    @IBOutlet weak var beforeIncomingVideo: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var capturedVideo: UIImageView!
    @IBOutlet weak var capturedVideoBlurEffect: UIVisualEffectView!
    @IBOutlet weak var viewCapturedVideo: UIView!
    @IBOutlet private weak var infoContainer: UIView!
    //@IBOutlet private weak var callProfileImage: UIImageView!
    @IBOutlet private weak var callNameLabel: UILabel!
    @IBOutlet private weak var callInfoTimerLabel: UILabel!
    @IBOutlet private weak var buttonsContainer: ButtonsContainerView!
    @IBOutlet weak var infoBlurEffect: UIVisualEffectView!
    @IBOutlet weak var leftArrow: UIImageView!

    //Constraints
    @IBOutlet weak var capturedVideoWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonsContainerBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var avatarViewImageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var conferenceCalls: UIStackView!
    @IBOutlet weak var conferenceCallsScrolView: UIScrollView!
    @IBOutlet weak var buttonsStackView: UIStackView!

    @IBOutlet weak var sendMessageButton: UIButton!
    @IBOutlet weak var inConferenceAddContactButton: UIView!
    @IBOutlet weak var conferenceCallsLeading: NSLayoutConstraint!
    @IBOutlet weak var conferenceCallsTop: NSLayoutConstraint!

    var viewModel: CallViewModel!
    var isCallStarted: Bool = false
    var isMenuShowed = false
    var isVideoHidden = false
    var orientation = UIDevice.current.orientation
    var conferenceParticipantMenu: UIView?

    fileprivate let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    var tapGestureRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.beforeIncomingVideo.backgroundColor = UIColor.jamiBackgroundColor
        let callCurrent = self.viewModel.call?.state == .current
        self.setAvatarView(!callCurrent || self.viewModel.isAudioOnly)
        self.capturedVideoBlurEffect.isHidden = callCurrent
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        let tapCapturedVideo = UITapGestureRecognizer(target: self, action: #selector(hideCapturedVideo))
        let swipeLeftCapturedVideo = UISwipeGestureRecognizer(target: self, action: #selector(capturedVideoSwipped(gesture:)))
        swipeLeftCapturedVideo.direction = .left
        let swipeRightCapturedVideo = UISwipeGestureRecognizer(target: self, action: #selector(capturedVideoSwipped(gesture:)))
        swipeRightCapturedVideo.direction = .right
        self.viewCapturedVideo.addGestureRecognizer(tapCapturedVideo)
        self.viewCapturedVideo.addGestureRecognizer(swipeLeftCapturedVideo)
        self.viewCapturedVideo.addGestureRecognizer(swipeRightCapturedVideo)
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
        self.setUpCallButtons()
        self.setupBindings()
        self.profileImageView.tintColor = UIColor.jamiDefaultAvatar
        nameLabel.textColor = UIColor.jamiLabelColor
        durationLabel.textColor = UIColor.jamiLabelColor
        infoBottomLabel.textColor = UIColor.jamiLabelColor
        if self.viewModel.isAudioOnly {
            // The durationLabel and buttonsContainer alpha is set here to 0, and to 1 (with a duration) when appear on the screen to have a fade in animation
            self.durationLabel.alpha = 0
            self.buttonsContainer.stackView.alpha = 0
            self.showAllInfo()
            self.setWhiteAvatarView()
        }
        UIDevice.current.isProximityMonitoringEnabled = self.viewModel.isAudioOnly
        UIApplication.shared.isIdleTimerDisabled = true
        initCallAnimation()
        self.inConferenceAddContactButton.isHidden = !self.viewModel.conferenceMode.value
        if callCurrent {
            self.capturedVideoBlurEffect.alpha = 1
            hideCapturedVideo()
        }
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                guard let self = self else {
                    return
                }
                self.setAvatarView(!self.avatarView.isHidden)
                self.callPulse.layer.cornerRadius = (self.profileImageViewWidthConstraint.constant - 20) * 0.5
            }).disposed(by: self.disposeBag)
    }

    @IBAction func addParticipant(_ sender: Any) {
        let children = self.children
        for child in children where child.isKind(of: (ContactPickerViewController).self) {
            return
        }
        self.viewModel.showContactPickerVC()
    }

    func addTapGesture() {
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc func capturedVideoSwipped(gesture: UISwipeGestureRecognizer) {
        if self.avatarView.isHidden == false { return }
        if gesture.direction == UISwipeGestureRecognizer.Direction.left && (self.isVideoHidden == false) { return }
        if gesture.direction == UISwipeGestureRecognizer.Direction.right && (self.isVideoHidden == true) { return }
        self.hideCapturedVideo()
    }

    @objc func hideCapturedVideo() {
        //if self.isMenuShowed { return }
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            if self?.capturedVideoBlurEffect.alpha == 0 {
                self?.isVideoHidden = true
                self?.capturedVideoBlurEffect.alpha = 1
            } else {
                self?.isVideoHidden = false
                self?.capturedVideoBlurEffect.alpha = 0
            }
            //guard let hidden = self?.infoContainer.isHidden else {return}
            self?.resizeCapturedVideo(withInfoContainer: false)
            self?.view.layoutIfNeeded()
        })
    }

    func setWhiteAvatarView() {
        self.callPulse.backgroundColor = UIColor.jamiCallPulse
        self.avatarView.backgroundColor = UIColor.jamiBackgroundColor
    }

    func initCallAnimation() {
        self.callPulse.alpha = 0.6
        self.callPulse.layer
            .cornerRadius = (self.profileImageViewWidthConstraint.constant - 20) * 0.5
        animateCallCircle()
    }

    func animateCallCircle() {
        self.callPulse.alpha = 0.6
        self.callPulse.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        UIView.animate(withDuration: 1.5, animations: { [weak self] in
            self?.callPulse.alpha = 0.0
            self?.callPulse.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            if self?.viewModel.call?.state == .ringing || self?.viewModel.call?.state == .connecting || self?.viewModel.call?.state == .unknown {
                self?.animateCallCircle()
            }
        })
    }

    func setUpCallButtons() {
        self.mainView.bringSubviewToFront(self.buttonsContainer)
        self.buttonsContainer.viewModel = self.viewModel.containerViewModel
        self.buttonsContainer.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.cancelCall(stopProvider: true)
                self?.removeFromScreen()
            }).disposed(by: self.disposeBag)
        self.sendMessageButton.rx.tap
        .subscribe(onNext: { [weak self] in
            self?.viewModel.showConversations()
            self?.dismiss(animated: false, completion: nil)
        }).disposed(by: self.disposeBag)

        self.buttonsContainer.acceptCallButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else {return}
                self.viewModel.answerCall()
                    .subscribe()
                    .disposed(by: self.disposeBag)
            }).disposed(by: self.disposeBag)

        self.buttonsContainer.dialpadButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showDialpad()
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
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    func setupBindings() {

        self.viewModel.contactImageData?.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dataOrNil in
                if let imageData = dataOrNil {
                    if let image = UIImage(data: imageData) {
                        self?.profileImageView.image = image
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

        self.viewModel.callDuration
            .asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if self?.durationLabel.text != "" {
                    if self?.viewModel.isAudioOnly ?? true {
                        self?.buttonContainerHeightConstraint.constant = 200
                        self?.buttonsContainer.containerHeightConstraint.constant = 200
                        self?.buttonsContainer.stackViewYConstraint.constant = 110
                        self?.buttonsContainer.stackViewWidthConstraint.priority = UILayoutPriority(rawValue: 999)
                        UIView.animate(withDuration: 0.3, animations: {
                            self?.durationLabel.alpha = 1
                            self?.buttonsContainer.stackView.alpha = 1
                        })
                    }
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
                    self?.isCallStarted = true
                    if self?.beforeIncomingVideo.alpha != 0 {
                        UIView.animate(withDuration: 0.4, animations: {
                            self?.beforeIncomingVideo.alpha = 0
                            }, completion: { [weak self] _ in
                                self?.beforeIncomingVideo.isHidden = true
                        })
                    }
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
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showContactInfo()
                }
            }).disposed(by: self.disposeBag)

        self.viewModel.showCancelOption
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showCancelButton()
                }
            }).disposed(by: self.disposeBag)

        if !self.viewModel.isAudioOnly {
            self.resizeCapturedFrame()
        }
        self.viewModel.videoMuted
            .observeOn(MainScheduler.instance)
            .bind(to: self.capturedVideo.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observeOn(MainScheduler.instance)
            .bind(to: self.capturedVideoBlurEffect.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observeOn(MainScheduler.instance)
            .bind(to: self.leftArrow.rx.isHidden)
            .disposed(by: self.disposeBag)

        if !self.viewModel.isAudioOnly {
            self.viewModel.callPaused
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { [weak self] show in
                    self?.setAvatarView(show)
                }).disposed(by: self.disposeBag)
        }

        self.viewModel.conferenceMode
        .asObservable()
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] enteredConference in
            guard let call = self?.viewModel.call else {return}
            if call.state != .current {return}
            self?.buttonsContainer.updateView()
            self?.infoContainer.isHidden = enteredConference ? true : false
            self?.resizeCapturedVideo(withInfoContainer: false)
            self?.inConferenceAddContactButton.isHidden = !enteredConference
            self?.conferenceCallsLeading.constant = enteredConference ? 0 : -80
            // if entered conference add first participant to conference list
            if enteredConference {
                let callView =
                    ConferenceParticipantView(frame: CGRect(x: 0,
                                                            y: 0,
                                                            width: inConfViewWidth,
                                                            height: inConfViewHeight))
                guard let injectionBag = self?.viewModel.injectionBag
                    else {return}
                let pendingCallViewModel =
                    ConferenceParticipantViewModel(with: call,
                                                   injectionBag: injectionBag)
                callView.viewModel = pendingCallViewModel
                callView.delegate = self
                self?.conferenceCalls.insertArrangedSubview(callView, at: 0)
            } else {
                self?.conferenceCalls.arrangedSubviews.forEach({ (view) in
                    view.removeFromSuperview()
                })
            }
        }).disposed(by: self.disposeBag)

        self.viewModel.callForConference
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                let callView =
                    ConferenceParticipantView(frame:
                        CGRect(x: 0, y: 0,
                               width: inConfViewWidth, height: inConfViewHeight))
                guard let injectionBag = self?.viewModel.injectionBag else {return}
                let pendingCallViewModel =
                    ConferenceParticipantViewModel(with: call,
                                                   injectionBag: injectionBag)
                callView.viewModel = pendingCallViewModel
                callView.delegate = self
                self?.conferenceCalls.addArrangedSubview(callView)
            }).disposed(by: self.disposeBag)

        self.viewModel.callPaused
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showCallOptions()
                }
            }).disposed(by: self.disposeBag)
    }

    func setAvatarView(_ show: Bool) {
        if !show {
            self.avatarView.isHidden = true
        } else {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.avatarViewImageTopConstraint.constant = 200
                self.avatarView.isHidden = false
                return
            }
            let isPortrait = UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height
            if !isPortrait {
                self.profileImageViewWidthConstraint.constant = 90
                self.profileImageViewHeightConstraint.constant = 90
                self.profileImageView.cornerRadius = 45
                if self.viewModel.call?.state == .ringing || self.viewModel.call?.state == .connecting {
                    self.avatarViewImageTopConstraint.constant = 20
                } else {
                    self.avatarViewImageTopConstraint.constant = 10
                }
                if UIDevice.current.hasNotch {
                    self.buttonsContainerBottomConstraint.constant = 0
                } else {
                    self.buttonsContainerBottomConstraint.constant = 10
                }
                if self.viewModel.isAudioOnly {
                    let device = UIDevice.modelName
                    if device == "iPhone 5" || device ==  "iPhone 5c" || device == "iPhone 5s" || device == "iPhone SE" {
                        self.durationLabel.isHidden = true
                        self.buttonsContainerBottomConstraint.constant = -10
                    }
                    self.buttonsContainer.backgroundBlurEffect.alpha = 0
                }
            } else {
                if UIDevice.current.hasNotch {
                    self.avatarViewImageTopConstraint.constant = 120
                } else {
                    self.avatarViewImageTopConstraint.constant = 85
                }
                if self.viewModel.isAudioOnly || self.viewModel.call?.state != .current {
                    self.profileImageViewWidthConstraint.constant = 160
                    self.profileImageViewHeightConstraint.constant = 160
                    self.profileImageView.cornerRadius = 80
                }
                self.buttonsContainerBottomConstraint.constant = 10
            }
            self.avatarView.isHidden = false
        }
    }

    func resizeCapturedFrame() {
        self.viewModel.showCapturedFrame
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] dontShow in
                if dontShow && (!(self?.isCallStarted ?? false)) {
                    self?.isCallStarted = true
                    let device = UIDevice.modelName
                    //Reduce the cancel button for small iPhone
                    switch device {
                    case "iPhone 5", "iPhone 5c", "iPhone 5s", "iPhone SE" :
                        self?.buttonsContainer.cancelButtonWidthConstraint.constant = 50
                        self?.buttonsContainer.cancelButtonHeightConstraint.constant = 50
                        self?.buttonsContainer.cancelButton.cornerRadius = 25
                    default : break
                    }
                    UIView.animate(withDuration: 0.4, animations: {
                        self?.beforeIncomingVideo.backgroundColor = UIColor.darkGray
                        self?.resizeCapturedVideo(withInfoContainer: false)
                        self?.capturedVideoBlurEffect.alpha = 0
                        self?.view.layoutIfNeeded()
                    }, completion: nil)
                    self?.avatarViewBlurEffect.alpha = CGFloat(1)
                }
            }).disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.viewModel.showConversations()
        self.dismiss(animated: false)
    }

    @objc func screenTapped() {
        if self.avatarView.isHidden {
            self.viewModel.respondOnTap()
            self.conferenceParticipantMenu?.removeFromSuperview()
            self.conferenceParticipantMenu = nil
        }
    }

    func showCancelButton() {
        self.buttonsContainer.isHidden = false
        self.view.layoutIfNeeded()
    }

    func hideCancelButton() {
        self.buttonsContainerBottomConstraint.constant = -150
        self.infoContainerTopConstraint.constant = 150
        self.buttonsContainer.isHidden = true
        self.view.layoutIfNeeded()
    }

    func showCallOptions() {
        self.buttonsContainer.isHidden = false
        self.view.layoutIfNeeded()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // Waiting for screen size change
        DispatchQueue.global(qos: .background).async {
            sleep(UInt32(0.5))
            DispatchQueue.main.async { [weak self] in
                //guard let hidden = self?.infoContainer.isHidden else {return}
                self?.resizeCapturedVideo(withInfoContainer: false)
                if UIDevice.current.hasNotch && (UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft) && self?.infoContainer.isHidden == false {
                    self?.buttonsContainerBottomConstraint.constant = 1
                }
            }
        }
        self.viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
        super.viewWillTransition(to: size, with: coordinator)
    }

    func resizeCapturedVideo(withInfoContainer: Bool) {
        self.leftArrow.alpha = 0
        if self.viewModel.call?.state != .current {
            return
        }
        //Don't change anything if the orientation change to portraitUpsideDown, faceUp or faceDown
        if  UIDevice.current.orientation.rawValue != 5  && UIDevice.current.orientation.rawValue != 6 && UIDevice.current.orientation.rawValue != 2 {
            self.orientation = UIDevice.current.orientation
        }
        let conference = self.viewModel.conferenceMode.value
        switch self.orientation {
        case .landscapeRight, .landscapeLeft:
            if !withInfoContainer {
                self.capturedVideoWidthConstraint.constant = -UIScreen.main.bounds.width + 160
                self.capturedVideoHeightConstraint.constant = conference ? -UIScreen.main.bounds.height : -UIScreen.main.bounds.height + 120
                self.viewCapturedVideo.cornerRadius = 15
                if UIDevice.current.userInterfaceIdiom == .pad {
                    self.capturedVideoTrailingConstraint.constant = 35
                    self.capturedVideoTopConstraint.constant = -13
                } else if UIDevice.current.hasNotch && orientation == .landscapeRight {
                    self.capturedVideoTrailingConstraint.constant = 45
                    self.capturedVideoTopConstraint.constant = -15
                } else {
                    self.capturedVideoTrailingConstraint.constant = 15
                    self.capturedVideoTopConstraint.constant = -15
                }
            } else {
                //Keep the 4:3 format of the video
                let widthCapturedVideo = ((self.infoContainerHeightConstraint.constant - 20)/3)*4
                self.capturedVideoHeightConstraint.constant = conference ? -UIScreen.main.bounds.height : -UIScreen.main.bounds.height + self.infoContainerHeightConstraint.constant - 20
                self.capturedVideoWidthConstraint.constant = -UIScreen.main.bounds.width + widthCapturedVideo
                let leftPointInfoContainer = self.infoBlurEffect?
                    .convert((self.infoBlurEffect?.frame.origin)!, to: nil).x ?? 0
                self.capturedVideoTrailingConstraint.constant = leftPointInfoContainer + 10
                self.capturedVideoTopConstraint.constant = -20
                self.viewCapturedVideo.cornerRadius = 25
            }
        default:
            if !withInfoContainer {
                self.capturedVideoWidthConstraint.constant = -UIScreen.main.bounds.width + 120
                self.capturedVideoHeightConstraint.constant = conference ? -UIScreen.main.bounds.height : -UIScreen.main.bounds.height + 160
                self.viewCapturedVideo.cornerRadius = 15
                if UIDevice.current.userInterfaceIdiom == .pad {
                    self.capturedVideoTrailingConstraint.constant = 35
                    self.capturedVideoTopConstraint.constant = -13
                } else if UIDevice.current.hasNotch {
                    self.capturedVideoTrailingConstraint.constant = 10
                    self.capturedVideoTopConstraint.constant = 0
                } else {
                    self.capturedVideoTrailingConstraint.constant = 10
                    self.capturedVideoTopConstraint.constant = -5
                }
            } else {
                //Keep the 4:3 format of the video
                let widthCapturedVideo = ((self.infoContainerHeightConstraint.constant - 20)/4)*3
                self.capturedVideoHeightConstraint.constant = conference ? -UIScreen.main.bounds.height : -UIScreen.main.bounds.height + self.infoContainerHeightConstraint.constant - 20
                self.capturedVideoWidthConstraint.constant = -UIScreen.main.bounds.width + widthCapturedVideo
                let leftPointInfoContainer = self.infoBlurEffect?.convert((self.infoBlurEffect?
                    .frame.origin)!, to: nil).x ?? 0
                self.capturedVideoTrailingConstraint.constant = leftPointInfoContainer + 10
                self.capturedVideoTopConstraint.constant = -20
                self.viewCapturedVideo.cornerRadius = 25
            }
        }
        if self.capturedVideoBlurEffect.alpha == 1
            && self.avatarView.isHidden == true {
            self.leftArrow.alpha = 1
            self.capturedVideoTrailingConstraint.constant = -200
        }
    }

    func showContactInfo() {
        if !self.buttonsContainer.isHidden {
            self.hideContactInfo()
            return
        }
        self.isMenuShowed = true
        self.buttonsContainer.isHidden = false
        if !self.viewModel.conferenceMode.value {
            self.infoContainer.isHidden = false
        } else {
            self.conferenceCallsScrolView.isHidden = false
            self.inConferenceAddContactButton.isHidden = false
        }
        self.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.infoContainerTopConstraint.constant = -10
            self?.conferenceCallsTop.constant = 0
            if UIDevice.current.hasNotch && (self?.orientation == .landscapeRight || self?.orientation == .landscapeLeft) {
                self?.buttonsContainerBottomConstraint.constant = 1
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                self?.buttonsContainerBottomConstraint.constant = 30
            } else {
                self?.buttonsContainerBottomConstraint.constant = 10
            }
            self?.view.layoutIfNeeded()
        })
    }

    func hideContactInfo() {
        self.isMenuShowed = false
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.infoContainerTopConstraint.constant = 250
            self?.buttonsContainerBottomConstraint.constant = -200
            self?.conferenceCallsTop.constant = -400
            self?.view.layoutIfNeeded()
            }, completion: { [weak self] _ in
                if !(self?.viewModel.conferenceMode.value ?? false) {
                    self?.infoContainer.isHidden = true
                } else {
                    self?.conferenceCallsScrolView.isHidden = true
                    self?.inConferenceAddContactButton.isHidden = true
                }
                self?.buttonsContainer.isHidden = true
        })
    }

    func showAllInfo() {
        self.buttonsContainer.isHidden = false
        self.infoContainer.isHidden = false
    }

    func presentContactPicker(contactPickerVC: ContactPickerViewController) {
        self.addChild(contactPickerVC)
        let newFrame = CGRect(x: 0, y: self.view.frame.size.height * 0.3, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        let initialFrame = CGRect(x: 0, y: self.view.frame.size.height, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        contactPickerVC.view.frame = initialFrame
        self.view.addSubview(contactPickerVC.view)
        contactPickerVC.didMove(toParent: self)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else {return}
            contactPickerVC.view.frame = newFrame
            self.mainView.removeGestureRecognizer(self.tapGestureRecognizer)
            self.view.layoutIfNeeded()
            }, completion: {  _ in
        })
    }
}

extension CallViewController: ConferenceParticipantViewDelegate {
    func setConferenceParticipantMenu(menu: UIView?) {
        guard let menuView = menu else {
            self.conferenceParticipantMenu?.removeFromSuperview()
            self.conferenceParticipantMenu = nil
            return
        }
        if self.conferenceParticipantMenu?.frame == menuView.frame {
            self.conferenceParticipantMenu?.removeFromSuperview()
            self.conferenceParticipantMenu = nil
            return
        }
        let point = conferenceCallsScrolView.convert(menuView.frame.origin, to: self.view)
        let offset = self.view.frame.size.width - point.x - menuView.frame.size.width
        if offset < 0 {
            conferenceCallsScrolView
                .setContentOffset(CGPoint(x: conferenceCallsScrolView.contentOffset.x - offset,
                                          y: 0), animated: true)
        }
        self.conferenceParticipantMenu?.removeFromSuperview()
        self.conferenceParticipantMenu = menuView
        conferenceCallsScrolView.addSubview(self.conferenceParticipantMenu!)
    }
}
