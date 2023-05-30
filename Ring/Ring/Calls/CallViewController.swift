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
class CallViewController: UIViewController, StoryboardBased, ViewModelBased, ContactPickerDelegate {

    // preview screen
    @IBOutlet private weak var profileImageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var durationLabel: UILabel!
    @IBOutlet weak var blinkAudioRecordView: UIView!
    @IBOutlet weak var audioRecordView: UIView!
    @IBOutlet private weak var infoBottomLabel: UILabel!
    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var avatarViewBlurEffect: UIVisualEffectView!
    @IBOutlet private weak var callPulse: UIView!

    @IBOutlet private weak var mainView: UIView!

    // video screen
    @IBOutlet private weak var callView: UIView!
    @IBOutlet private weak var incomingVideo: VideoViewsContainer!
    @IBOutlet weak var beforeIncomingVideo: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var capturedVideo: UIImageView!
    @IBOutlet weak var capturedVideoBlurEffect: UIVisualEffectView!
    @IBOutlet weak var viewCapturedVideo: UIView!
    @IBOutlet private weak var infoContainer: UIView!
    @IBOutlet private weak var callNameLabel: UILabel!
    @IBOutlet private weak var callInfoTimerLabel: UILabel!
    @IBOutlet weak var blinkVideoRecordView: UIView!
    @IBOutlet weak var videoRecordView: UIView!
    @IBOutlet private weak var buttonsContainer: ButtonsContainerView!
    @IBOutlet weak var infoBlurEffect: UIVisualEffectView!
    @IBOutlet weak var leftArrow: UIImageView!

    // Constraints
    @IBOutlet weak var capturedVideoWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var capturedVideoHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonsContainerBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var backButtonAudioCallTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var avatarViewImageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var conferenceCalls: UIStackView!
    @IBOutlet weak var conferenceCallsScrolView: UIScrollView!
    @IBOutlet weak var buttonsStackView: UIStackView!
    @IBOutlet weak var conferenceLayout: ConferenceLayout!

    @IBOutlet weak var backButtonAudioCall: UIButton!
    @IBOutlet weak var sendMessageButton: UIButton!
    @IBOutlet weak var conferenceCallsTop: NSLayoutConstraint!

    var viewModel: CallViewModel!
    private var callViewMode: CallViewMode = .audio
    private var isMenuShowed = false
    private var needToCleanIncomingFrame = false
    private var isCapturedVideoHidden = false
    private var orientation = UIDevice.current.orientation
    private var conferenceParticipantMenu: UIView?

    private let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    private var tapGestureRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        sendMessageButton.isHidden = self.viewModel.isBoothMode()
        sendMessageButton.isEnabled = !self.viewModel.isBoothMode()
        buttonsStackView.isHidden = self.viewModel.isBoothMode()
        backButtonAudioCall.tintColor = UIColor.jamiLabelColor
        self.beforeIncomingVideo.backgroundColor = UIColor.jamiBackgroundColor
        let callCurrent = self.viewModel.call?.state == .current
        self.setAvatarView(!callCurrent || callViewMode == .audio)
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
        UIApplication.shared.isIdleTimerDisabled = true
        initCallAnimation()
        self.configureConferenceLayout()
        if callCurrent {
            self.capturedVideoBlurEffect.alpha = 1
            hideCapturedVideo()
        }
        NotificationCenter.default.rx
            .notification(UIDevice.orientationDidChangeNotification)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: {[weak self] (_) in
                guard let self = self,
                      UIDevice.current.portraitOrLandscape else {
                    return
                }
                self.setAvatarView(!self.avatarView.isHidden)
                self.callPulse.layer.cornerRadius = (self.profileImageViewWidthConstraint.constant - 20) * 0.5
            })
            .disposed(by: self.disposeBag)
    }

    func addTapGesture() {
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
    }

    private func configureConferenceLayout() {
        //  self.updateconferenceLayoutSize()
        self.viewModel.layoutUpdated
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updated in
                guard let self = self, updated else { return }
                //  self.updateconferenceLayoutSize()
                if let participants = self.viewModel.getConferenceParticipants() {
                    self.incomingVideo.addParticipants(participants: participants)
                }
                return
                //                    self.conferenceLayout.setParticipants(participants: participants, isCurrentModerator: self.viewModel.isCurrentModerator() || self.viewModel.isHostCall )
                //
                //                guard let unwrapParticipants = participants, self.viewModel.isCurrentModerator(), !self.viewModel.isHostCall else { return }
                //                self.conferenceCalls.arrangedSubviews.forEach({ (view) in
                //                    view.removeFromSuperview()
                //                })
                //                for participant in unwrapParticipants {
                //                    let callView =
                //                        ConferenceParticipantView(frame:
                //                                                    CGRect(x: 0, y: 0,
                //                                                           width: inConfViewWidth, height: inConfViewHeight))
                //                    let injectionBag = self.viewModel.injectionBag
                //                    let isLocal = self.viewModel.isLocalCall(participantId: participant.uri ?? "")
                //                    let pendingCallViewModel =
                //                        ConferenceParticipantViewModel(with: nil,
                //                                                       injectionBag: injectionBag,
                //                                                       isLocal: isLocal,
                //                                                       participantId: participant.uri ?? "",
                //                                                       participantUserName: participant.displayName)
                //                    callView.viewModel = pendingCallViewModel
                //                    callView.delegate = self
                //                    self.conferenceCalls.addArrangedSubview(callView)
                // }
            })
            .disposed(by: self.disposeBag)
    }

    private func updateconferenceLayoutSize() {
        let size = self.viewModel.getConferenceVideoSize()
        self.conferenceLayout.setUpWithVideoSize(size: size)
    }

    @objc
    func capturedVideoSwipped(gesture: UISwipeGestureRecognizer) {
        if self.avatarView.isHidden == false { return }
        if gesture.direction == UISwipeGestureRecognizer.Direction.left && (self.isCapturedVideoHidden == false) { return }
        if gesture.direction == UISwipeGestureRecognizer.Direction.right && (self.isCapturedVideoHidden == true) { return }
        self.hideCapturedVideo()
    }

    @objc
    func hideCapturedVideo() {
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            if self?.capturedVideoBlurEffect.alpha == 0 {
                self?.isCapturedVideoHidden = true
                self?.capturedVideoBlurEffect.alpha = 1
            } else {
                self?.isCapturedVideoHidden = false
                self?.capturedVideoBlurEffect.alpha = 0
            }
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
                self?.viewModel.cancelCall(stopProvider: true, callId: "")
                self?.removeFromScreen()
            })
            .disposed(by: self.disposeBag)
        self.buttonsContainer.stopButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.cancelCall(stopProvider: true, callId: "")
                self?.removeFromScreen()
            })
            .disposed(by: self.disposeBag)
        self.sendMessageButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showConversations()
                self?.dismiss(animated: false, completion: nil)
            })
            .disposed(by: self.disposeBag)

        self.backButtonAudioCall.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showConversations()
                self?.dismiss(animated: false, completion: nil)
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.dialpadButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.showDialpad()
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.muteAudioButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toggleMuteAudio(callId: "")
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.muteVideoButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.toggleMuteVideo(callId: "")
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.pauseCallButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.togglePauseCall()
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.switchCameraButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchCamera()
            })
            .disposed(by: self.disposeBag)

        self.buttonsContainer.switchSpeakerButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.switchSpeaker()
            })
            .disposed(by: self.disposeBag)
        self.buttonsContainer.addParticipantButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                let children = self.children
                for child in children where child.isKind(of: (ContactPickerViewController).self) {
                    return
                }
                self.viewModel.showContactPickerVC()
            })
            .disposed(by: self.disposeBag)
        self.buttonsContainer.raiseHandButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.viewModel.togleRaiseHand()
            })
            .disposed(by: self.disposeBag)
        // Data bindings
        self.viewModel.videoButtonState
            .observe(on: MainScheduler.instance)
            .bind(to: self.buttonsContainer.muteVideoButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.audioButtonState
            .observe(on: MainScheduler.instance)
            .bind(to: self.buttonsContainer.muteAudioButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.speakerButtonState
            .observe(on: MainScheduler.instance)
            .bind(to: self.buttonsContainer.switchSpeakerButton.rx.image())
            .disposed(by: self.disposeBag)

        self.viewModel.pauseCallButtonState
            .observe(on: MainScheduler.instance)
            .bind(to: self.buttonsContainer.pauseCallButton.rx.image())
            .disposed(by: self.disposeBag)
    }
    func showViewRecording(viewToShow: UIView, viewToBlink: UIView) {
        viewToBlink.blink()
        viewToBlink.roundedCorners = true
        viewToShow.isHidden = false
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    func setupBindings() {
        self.viewModel.showRecordImage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] flagStatus in
                guard let self = self else { return }
                if flagStatus {
                    if self.callViewMode == .audio {
                        self.showViewRecording(viewToShow: self.audioRecordView, viewToBlink: self.blinkAudioRecordView)
                    } else {
                        self.showViewRecording(viewToShow: self.videoRecordView, viewToBlink: self.blinkVideoRecordView)
                    }
                } else {
                    self.audioRecordView.isHidden = true
                    self.videoRecordView.isHidden = true
                }
            })
            .disposed(by: disposeBag)
        self.viewModel.callViewMode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] callViewMode in
                guard let self = self else { return }
                if callViewMode == self.callViewMode {
                    return
                }
                self.callViewMode = callViewMode
                switch callViewMode {
                case .audio:
                    self.setUpAudioView()
                case .video, .videoWithSpiner:
                    self.spinner.startAnimating()
                    self.setUpVideoView()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.contactImageData?.asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dataOrNil in
                if let imageData = dataOrNil {
                    if let image = UIImage(data: imageData) {
                        self?.profileImageView.image = image
                    }
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.dismisVC
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.nameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.callNameLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.durationLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if self?.durationLabel.text != "" {
                    if self?.callViewMode == .audio {
                        self?.spinner.stopAnimating()
                        self?.buttonContainerHeightConstraint.constant = 200
                        self?.buttonsContainer.containerHeightConstraint.constant = 200
                        UIView.animate(withDuration: 0.3, animations: {
                            self?.durationLabel.alpha = 1
                            self?.buttonsContainer.stackView.alpha = 1
                        })
                    }
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.callInfoTimerLabel.rx.text)
            .disposed(by: self.disposeBag)

        self.viewModel.bottomInfo
            .observe(on: MainScheduler.instance)
            .bind(to: self.infoBottomLabel.rx.text)
            .disposed(by: self.disposeBag)
        self.viewModel.renderStarted
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] renderId in
                guard let self = self else { return }
                // self.needToCleanIncomingFrame = true
                self.setAvatarView(false)
                self.spinner.stopAnimating()
                if self.beforeIncomingVideo.alpha != 0 {
                    UIView.animate(withDuration: 0.4, animations: {
                        self.beforeIncomingVideo.alpha = 0
                    }, completion: { [weak self] _ in
                        self?.beforeIncomingVideo.isHidden = true
                    })
                }
                if let input = self.viewModel.getVideoInput(renderId: renderId) {
                    self.incomingVideo.addVideoInput(videoInput: input, renderId: renderId)
                }
            })
            .disposed(by: self.disposeBag)

        //        self.viewModel.incomingFrame
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] frame in
        //                guard let self = self else { return }
        //                guard let image = frame else {
        //                    if self.needToCleanIncomingFrame {
        //                        self.needToCleanIncomingFrame = false
        //                        DispatchQueue.main.async { [weak self] in
        //                            self?.incomingVideo.image = UIImage()
        //                        }
        //                    }
        //                    return
        //                }
        //                self.needToCleanIncomingFrame = true
        //                self.setAvatarView(false)
        //                self.spinner.stopAnimating()
        //                if self.beforeIncomingVideo.alpha != 0 {
        //                    UIView.animate(withDuration: 0.4, animations: {
        //                        self.beforeIncomingVideo.alpha = 0
        //                    }, completion: { [weak self] _ in
        //                        self?.beforeIncomingVideo.isHidden = true
        //                    })
        //                }
        //                DispatchQueue.main.async { [weak self] in
        //                    self?.incomingVideo.image = image
        //                }
        //            })
        // .disposed(by: self.disposeBag)

        self.viewModel.capturedFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.capturedVideo.image = image
                        self?.spinner.stopAnimating()
                    }
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.showCallOptions
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showContactInfo()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.showCancelOption
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showCancelButton()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observe(on: MainScheduler.instance)
            .bind(to: self.capturedVideo.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observe(on: MainScheduler.instance)
            .bind(to: self.capturedVideoBlurEffect.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.videoMuted
            .observe(on: MainScheduler.instance)
            .bind(to: self.leftArrow.rx.isHidden)
            .disposed(by: self.disposeBag)

        self.viewModel.conferenceMode
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enteredConference in
                guard let call = self?.viewModel.call,
                      let self = self else { return }
                if call.state != .current { return }
                self.updateconferenceLayoutSize()
                self.buttonsContainer.updateView()
                self.infoContainer.isHidden = enteredConference ? true : false
                self.conferenceCallsTop.constant = enteredConference ? 0 : -50
                self.resizeCapturedVideo(withInfoContainer: false)
                // for moderator participants will be added in layoutUpdated
                if self.viewModel.isCurrentModerator() { return }
                // if entered conference add first participant to conference list
                if enteredConference {
                    self.removeConferenceParticipantMenu()
                    let injectionBag = self.viewModel.injectionBag
                    // add self as a master call
                    let mainCallView =
                        ConferenceParticipantView(frame: CGRect(x: 0,
                                                                y: 0,
                                                                width: inConfViewWidth,
                                                                height: inConfViewHeight))
                    let mainCallViewModel =
                        ConferenceParticipantViewModel(with: nil,
                                                       injectionBag: injectionBag,
                                                       isLocal: true,
                                                       participantId: "",
                                                       participantUserName: "")
                    mainCallView.viewModel = mainCallViewModel
                    mainCallView.delegate = self
                    self.conferenceCalls.insertArrangedSubview(mainCallView, at: 0)
                    let callView =
                        ConferenceParticipantView(frame: CGRect(x: 0,
                                                                y: 0,
                                                                width: inConfViewWidth,
                                                                height: inConfViewHeight))
                    let name = call.displayName.isEmpty ? call.registeredName.isEmpty ? call.participantUri.filterOutHost() : call.registeredName : call.displayName
                    let pendingCallViewModel =
                        ConferenceParticipantViewModel(with: call.callId,
                                                       injectionBag: injectionBag,
                                                       isLocal: false,
                                                       participantId: call.paricipantHash(),
                                                       participantUserName: name)
                    callView.viewModel = pendingCallViewModel
                    callView.delegate = self
                    self.conferenceCalls.insertArrangedSubview(callView, at: 1)
                } else {
                    self.removeConferenceParticipantMenu()
                    self.conferenceCalls.arrangedSubviews.forEach({ (view) in
                        view.removeFromSuperview()
                    })
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.callForConference
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] call in
                guard let self = self else { return }
                // for moderator participants will be added in layoutUpdated
                if self.viewModel.isCurrentModerator() { return }
                let callView =
                    ConferenceParticipantView(frame:
                                                CGRect(x: 0, y: 0,
                                                       width: inConfViewWidth, height: inConfViewHeight))
                let injectionBag = self.viewModel.injectionBag
                let name = call.displayName.isEmpty ? call.registeredName.isEmpty ? call.participantUri.filterOutHost() : call.registeredName : call.displayName
                let pendingCallViewModel =
                    ConferenceParticipantViewModel(with: call.callId,
                                                   injectionBag: injectionBag,
                                                   isLocal: false,
                                                   participantId: call.paricipantHash(),
                                                   participantUserName: name)
                callView.viewModel = pendingCallViewModel
                callView.delegate = self
                self.conferenceCalls.addArrangedSubview(callView)
            })
            .disposed(by: self.disposeBag)

        self.viewModel.callPaused
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] paused in
                guard let self = self else { return }
                if paused {
                    self.setUpAudioView()
                    self.showCallOptions()
                    return
                }
                switch self.callViewMode {
                case .audio:
                    return
                default:
                    self.setUpVideoView()
                }
            })
            .disposed(by: self.disposeBag)
    }

    func setUpAudioView() {
        UIDevice.current.isProximityMonitoringEnabled = false
        self.setWhiteAvatarView()
        self.buttonsContainer.callViewMode = .audio
        self.callInfoTimerLabel.isHidden = true
        self.backButtonAudioCall.isHidden = false
        self.sendMessageButton.isHidden = true
        self.buttonsContainer.updateView()
        self.setAvatarView(true)
    }

    func setUpVideoView() {
        UIDevice.current.isProximityMonitoringEnabled = true
        self.buttonsContainer.callViewMode = .video
        self.callInfoTimerLabel.isHidden = false
        self.backButtonAudioCall.isHidden = true
        self.callNameLabel.isHidden = false
        self.sendMessageButton.isHidden = false
        self.buttonsContainer.updateView()
        self.setAvatarView(false)
        self.isCapturedVideoHidden = false
        self.capturedVideoBlurEffect.alpha = 0
        self.resizeCapturedFrame()
    }

    func setAvatarView(_ show: Bool) {
        if !show {
            self.avatarView.isHidden = true
            self.backButtonAudioCall.isHidden = true
        } else {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.avatarViewImageTopConstraint.constant = 200
                self.avatarView.isHidden = false
                self.backButtonAudioCall.isHidden = false
                return
            }
            let isLandscape = UIDevice.current.orientation == .landscapeRight || UIDevice.current.orientation == .landscapeLeft
            let isPortrait = UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .faceUp
            if isLandscape {
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
                    self.backButtonAudioCallTopConstraint.constant = 20
                } else {
                    self.buttonsContainerBottomConstraint.constant = 10
                    self.backButtonAudioCallTopConstraint.constant = 10
                }
                if self.callViewMode == .audio {
                    let device = UIDevice.modelName
                    if device == "iPhone 5" || device == "iPhone 5c" || device == "iPhone 5s" || device == "iPhone SE" {
                        self.durationLabel.isHidden = true
                        self.buttonsContainerBottomConstraint.constant = -10
                    }
                    self.buttonsContainer.backgroundBlurEffect.alpha = 0
                }
            } else if isPortrait {
                if UIDevice.current.hasNotch {
                    self.avatarViewImageTopConstraint.constant = 120
                    self.backButtonAudioCallTopConstraint.constant = 40
                } else {
                    self.avatarViewImageTopConstraint.constant = 85
                    self.backButtonAudioCallTopConstraint.constant = 10
                }
                if self.callViewMode == .audio || self.viewModel.call?.state != .current {
                    self.profileImageViewWidthConstraint.constant = 160
                    self.profileImageViewHeightConstraint.constant = 160
                    self.profileImageView.cornerRadius = 80
                }
                self.buttonsContainerBottomConstraint.constant = 10
            }
            self.avatarView.isHidden = false
            self.backButtonAudioCall.isHidden = false
            self.sendMessageButton.isHidden = true
            self.callNameLabel.isHidden = true
        }
    }

    func resizeCapturedFrame() {
        self.viewModel.showCapturedFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dontShow in
                if dontShow {
                    let device = UIDevice.modelName
                    // Reduce the cancel button for small iPhone
                    switch device {
                    case "iPhone 5", "iPhone 5c", "iPhone 5s", "iPhone SE":
                        self?.buttonsContainer.cancelButtonWidthConstraint.constant = 50
                        self?.buttonsContainer.cancelButtonHeightConstraint.constant = 50
                        self?.buttonsContainer.cancelButton.cornerRadius = 25
                    default: break
                    }
                    UIView.animate(withDuration: 0.4, animations: {
                        self?.beforeIncomingVideo.backgroundColor = UIColor.darkGray
                        self?.resizeCapturedVideo(withInfoContainer: false)
                        self?.capturedVideoBlurEffect.alpha = 0
                        self?.view.layoutIfNeeded()
                    }, completion: nil)
                    self?.avatarViewBlurEffect.alpha = CGFloat(1)
                }
            })
            .disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.viewModel.callFinished()
        self.dismiss(animated: false)
    }

    @objc
    func screenTapped() {
        if self.avatarView.isHidden {
            self.viewModel.respondOnTap()
            self.removeConferenceParticipantMenu()
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
                // guard let hidden = self?.infoContainer.isHidden else {return}
                self?.resizeCapturedVideo(withInfoContainer: false)
                self?.buttonsContainer.updateView()
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
        // Don't change anything if the orientation change to portraitUpsideDown, faceUp or faceDown
        if  UIDevice.current.orientation.rawValue != 5 && UIDevice.current.orientation.rawValue != 6 && UIDevice.current.orientation.rawValue != 2 {
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
                // Keep the 4:3 format of the video
                let widthCapturedVideo = ((self.infoContainerHeightConstraint.constant - 20) / 3) * 4
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
                // Keep the 4:3 format of the video
                let widthCapturedVideo = ((self.infoContainerHeightConstraint.constant - 20) / 4) * 3
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
        }
        self.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.infoContainerTopConstraint.constant = -10
            let isConference: Bool = self?.viewModel.conferenceMode.value ?? true
            self?.conferenceCallsTop.constant = isConference ? 0 : -50
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
            }
            self?.buttonsContainer.isHidden = true
        })
    }

    func showAllInfo() {
        self.buttonsContainer.isHidden = false
        self.infoContainer.isHidden = false
    }

    // MARK: ContactPickerDelegate
    func presentContactPicker(contactPickerVC: ContactPickerViewController) {
        self.addChild(contactPickerVC)
        let newFrame = CGRect(x: 0, y: self.view.frame.size.height * 0.3, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        let initialFrame = CGRect(x: 0, y: self.view.frame.size.height, width: self.view.frame.size.width, height: self.view.frame.size.height * 0.7)
        contactPickerVC.view.frame = initialFrame
        self.view.addSubview(contactPickerVC.view)
        contactPickerVC.didMove(toParent: self)
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            guard let self = self else { return }
            contactPickerVC.view.frame = newFrame
            self.mainView.removeGestureRecognizer(self.tapGestureRecognizer)
            self.view.layoutIfNeeded()
        }, completion: {  _ in
        })
    }

    func contactPickerDismissed() {
        self.addTapGesture()
    }
}

extension CallViewController: ConferenceParticipantViewDelegate {
    func addConferenceParticipantMenu(origin: CGPoint, displayName: String, participantId: String, callId: String?, hangup: @escaping (() -> Void)) {
        // remove menu if it is already present
        if self.conferenceParticipantMenu?.frame.origin == origin {
            self.removeConferenceParticipantMenu()
            return
        }
        let menuView = ConferenceActionMenu(frame: CGRect(origin: origin, size: CGSize(width: self.view.frame.size.width, height: self.view.frame.size.height)))
        var muteEnabled = false
        var muteText = ""
        var moderatorText = ""
        var isModerator = false
        var isAudioMuted = false
        var pending = true
        var deviceId = ""

        if let participant = self.viewModel.getConferencePartisipant(participantId: participantId) {
            muteEnabled = !participant.isAudioLocalyMuted
            muteText = participant.isAudioMuted ? L10n.Calls.unmuteAudio : L10n.Calls.muteAudio
            moderatorText = participant.isModerator ? L10n.Calls.removeModerator : L10n.Calls.setModerator
            isModerator = participant.isModerator
            isAudioMuted = participant.isAudioMuted
            pending = false
            deviceId = participant.device
        }

        menuView.configureWith(items: self.viewModel.getItemsForConferenceMenu(participantId: participantId, callId: callId ?? ""),
                               displayName: displayName,
                               muteText: muteText,
                               moderatorText: moderatorText,
                               muteEnabled: muteEnabled)
        menuView.addHangUpAction { [weak self] in
            if pending {
                hangup()
            } else {
                self?.viewModel.hangupParticipant(participantId: participantId, device: deviceId)
            }
            self?.removeConferenceParticipantMenu()
        }
        menuView.addMaximizeAction { [weak self] in
            self?.removeConferenceParticipantMenu()
            self?.viewModel.setActiveParticipant(jamiId: participantId, maximize: true)
        }
        menuView.addMinimizeAction { [weak self] in
            self?.removeConferenceParticipantMenu()
            self?.viewModel.setActiveParticipant(jamiId: participantId, maximize: false)
        }

        menuView.addSetModeratorAction { [weak self] in
            self?.removeConferenceParticipantMenu()
            self?.viewModel.setModeratorParticipant(participantId: participantId, active: !isModerator)
        }

        menuView.addMuteAction { [weak self] in
            self?.removeConferenceParticipantMenu()
            self?.viewModel.muteParticipant(participantId: participantId, active: !isAudioMuted)
        }
        menuView.addLowerHandAction { [weak self] in
            self?.removeConferenceParticipantMenu()
            self?.viewModel.lowerHandFor(participantId: participantId)
        }

        let point = conferenceCallsScrolView.convert(menuView.frame.origin, to: self.view)
        let offset = self.view.frame.size.width - point.x - menuView.frame.size.width
        if offset < 0 {
            conferenceCallsScrolView.setContentOffset(CGPoint(x: conferenceCallsScrolView.contentOffset.x - offset, y: 0), animated: true)
        }
        self.removeConferenceParticipantMenu()
        self.conferenceParticipantMenu = menuView
        conferenceCallsScrolView.addSubview(self.conferenceParticipantMenu!)
    }

    func removeConferenceParticipantMenu() {
        self.conferenceParticipantMenu?.removeFromSuperview()
        self.conferenceParticipantMenu = nil
    }
}
