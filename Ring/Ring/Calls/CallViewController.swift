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
import SwiftUI

// swiftlint:disable type_body_length
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
    @IBOutlet weak var beforeIncomingVideo: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var incomingVideo: UIView!
    @IBOutlet private weak var infoContainer: UIView!
    @IBOutlet private weak var callNameLabel: UILabel!
    @IBOutlet private weak var callInfoTimerLabel: UILabel!
    @IBOutlet weak var blinkVideoRecordView: UIView!
    @IBOutlet weak var videoRecordView: UIView!
    @IBOutlet weak var infoBlurEffect: UIVisualEffectView!

    // Constraints
    @IBOutlet weak var infoContainerTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var backButtonAudioCallTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var avatarViewImageTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var profileImageViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var backButtonAudioCall: UIButton!
    @IBOutlet weak var sendMessageButton: UIButton!

    var viewModel: CallViewModel!
    private var callViewMode: CallViewMode = .audio
    private var isMenuShowed = false
    private var needToCleanIncomingFrame = false
    private var orientation = UIDevice.current.orientation
    private var conferenceParticipantMenu: UIView?
    private var videoContainerViewModel: ContainerViewModel!

    private let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    private var tapGestureRecognizer: UITapGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureIncomingVideView()
        sendMessageButton.isHidden = self.viewModel.isBoothMode()
        sendMessageButton.isEnabled = !self.viewModel.isBoothMode()
        backButtonAudioCall.tintColor = UIColor.jamiLabelColor
        self.beforeIncomingVideo.backgroundColor = UIColor.jamiBackgroundColor
        let callCurrent = self.viewModel.call?.state == .current
        self.setAvatarView(!callCurrent || callViewMode == .audio)
        self.setupBindings()
        self.profileImageView.tintColor = UIColor.jamiDefaultAvatar
        nameLabel.textColor = UIColor.jamiLabelColor
        durationLabel.textColor = UIColor.jamiLabelColor
        infoBottomLabel.textColor = UIColor.jamiLabelColor
        UIApplication.shared.isIdleTimerDisabled = true
        if !callCurrent {
            initCallAnimation()
        }
        self.configureConferenceLayout()
        self.configureConferenceInfo()

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

    func incomingVideoStarted() {
        self.setAvatarView(false)
        self.spinner.stopAnimating()
        if self.beforeIncomingVideo.alpha != 0 {
            UIView.animate(withDuration: 0.4, animations: {
                self.beforeIncomingVideo.alpha = 0
            }, completion: { [weak self] _ in
                self?.beforeIncomingVideo.isHidden = true
            })
        }
    }

    func addTapGesture() {
        self.mainView.addGestureRecognizer(tapGestureRecognizer)
    }

    // swiftlint:disable cyclomatic_complexity
    func configureIncomingVideView() {
        let localId = self.viewModel.localId()
        videoContainerViewModel = ContainerViewModel(localId: localId,
                                                     delegate: self,
                                                     injectionBag: self.viewModel.injectionBag,
                                                     currentCall: self.viewModel.currentCall.share(),
                                                     hasVideo: !(self.viewModel.call?.isAudioOnly ?? true),
                                                     incoming: self.viewModel.call?.callType == .incoming)
        if let jamiId = self.viewModel.getJamiId() {
            let participant = ConferenceParticipant(sinkId: self.viewModel.conferenceId, isActive: true)
            participant.uri = jamiId
            self.videoContainerViewModel.conferenceUpdated(participantsInfo: [participant])
        }
        videoContainerViewModel.actionsState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? CallAction else { return }
                switch state {
                case .toggleAudio:
                    self.viewModel.toggleMuteAudio()
                case .toggleVideo:
                    self.viewModel.toggleMuteVideo()
                case .pauseCall:
                    self.viewModel.togglePauseCall()
                case .hangUpCall:
                    self.viewModel.cancelCall()
                    self.removeFromScreen()
                case .addParticipant:
                    let children = self.children
                    for child in children where child.isKind(of: (ContactPickerViewController).self) {
                        return
                    }
                    self.viewModel.showContactPickerVC()
                case .switchCamera:
                    self.viewModel.switchCamera()
                case .toggleSpeaker:
                    self.viewModel.switchSpeaker()
                case .openConversation:
                    self.viewModel.showConversations()
                    if !self.viewModel.isAudioOnly {
                        self.videoContainerViewModel.showPiP()
                    }
                    self.dismiss(animated: false)
                case .showDialpad:
                    self.viewModel.showDialpad()

                }
            })
            .disposed(by: self.disposeBag)

        videoContainerViewModel.conferenceState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? ParticipantAction else { return }
                switch state {
                case .hangup(let info):
                    self.viewModel.hangupParticipant(participantId: info.uri?.filterOutHost() ?? "", device: info.device)
                case .maximize(let info):
                    self.viewModel.setActiveParticipant(jamiId: info.uri?.filterOutHost() ?? "", maximize: true)
                case .minimize(let info):
                    self.viewModel.setActiveParticipant(jamiId: info.uri?.filterOutHost() ?? "", maximize: false)
                case .setModerator(let info):
                    self.viewModel.setModeratorParticipant(participantId: info.uri?.filterOutHost() ?? "", active: !info.isModerator)
                case .muteAudio(let info):
                    self.viewModel.muteParticipant(participantId: info.uri?.filterOutHost() ?? "", active: !info.isAudioMuted)
                case .raseHand(let info):
                    self.viewModel.lowerHandFor(participantId: info.uri?.filterOutHost() ?? "")

                }
            })
            .disposed(by: self.disposeBag)
        let videoViewSwiftUI = ContainerView(model: videoContainerViewModel)
        let hostingController = UIHostingController(rootView: videoViewSwiftUI)
        self.addChild(hostingController)
        hostingController.view.frame = incomingVideo.bounds
        self.incomingVideo.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.topAnchor.constraint(equalTo: self.incomingVideo.topAnchor, constant: 0).isActive = true
        hostingController.view.bottomAnchor.constraint(equalTo: self.incomingVideo.bottomAnchor, constant: 0).isActive = true
        hostingController.view.leadingAnchor.constraint(equalTo: self.incomingVideo.leadingAnchor, constant: 0).isActive = true
        hostingController.view.trailingAnchor.constraint(equalTo: self.incomingVideo.trailingAnchor, constant: 0).isActive = true
        hostingController.didMove(toParent: self)

        self.viewModel.renderStarted
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] sinkId in
                if sinkId == self?.viewModel.conferenceId {
                    self?.incomingVideoStarted()
                }
            })
            .disposed(by: self.disposeBag)
    }

    private func configureConferenceLayout() {
        self.viewModel.layoutUpdated
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updated in
                guard let self = self, updated else { return }
                if let participants = self.viewModel.getConferenceParticipants() {
                    self.videoContainerViewModel.conferenceUpdated(participantsInfo: participants)
                }
            })
            .disposed(by: self.disposeBag)
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
            // self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            if self?.viewModel.call?.state == .ringing || self?.viewModel.call?.state == .connecting || self?.viewModel.call?.state == .unknown {
                self?.animateCallCircle()
            }
        })
    }

    func showViewRecording(viewToShow: UIView, viewToBlink: UIView) {
        viewToBlink.blink()
        viewToBlink.roundedCorners = true
        viewToShow.isHidden = false
    }

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
        //        self.viewModel.callViewMode
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] callViewMode in
        //                guard let self = self else { return }
        //                if callViewMode == self.callViewMode {
        //                    return
        //                }
        //                self.callViewMode = callViewMode
        //                switch callViewMode {
        //                case .audio:
        //                    self.setUpAudioView()
        //                case .video, .videoWithSpiner:
        //                    self.spinner.startAnimating()
        //                    self.setUpVideoView()
        //                }
        //            })
        //            .disposed(by: self.disposeBag)

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
                        UIView.animate(withDuration: 0.3, animations: {
                            self?.durationLabel.alpha = 1
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
    }

    func configureConferenceInfo() {
        // participants list with the actions
        self.viewModel.conferenceMode
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enteredConference in
                guard let call = self?.viewModel.call,
                      let self = self else { return }
                if call.state != .current { return }
                self.infoContainer.isHidden = enteredConference ? true : false
                // for moderator participants will be added in layoutUpdated
                if self.viewModel.isCurrentModerator() { return }
                if !enteredConference {
                    self.videoContainerViewModel.conferenceDestroyed()
                }
            })
            .disposed(by: self.disposeBag)
    }

    func setUpAudioView() {
        UIDevice.current.isProximityMonitoringEnabled = false
        self.setWhiteAvatarView()
        self.callInfoTimerLabel.isHidden = true
        self.backButtonAudioCall.isHidden = false
        self.sendMessageButton.isHidden = true
        self.setAvatarView(true)
    }

    func setUpVideoView() {
        UIDevice.current.isProximityMonitoringEnabled = true
        self.callInfoTimerLabel.isHidden = false
        self.backButtonAudioCall.isHidden = true
        self.callNameLabel.isHidden = false
        self.sendMessageButton.isHidden = false
        self.setAvatarView(false)
    }

    func setAvatarView(_ show: Bool) {
        if self.avatarView.isHidden != show {
            return
        }
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
                    self.backButtonAudioCallTopConstraint.constant = 20
                } else {
                    self.backButtonAudioCallTopConstraint.constant = 10
                }
                if self.callViewMode == .audio {
                    let device = UIDevice.modelName
                    if device == "iPhone 5" || device == "iPhone 5c" || device == "iPhone 5s" || device == "iPhone SE" {
                        self.durationLabel.isHidden = true
                    }
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
            }
            self.avatarView.isHidden = false
            self.backButtonAudioCall.isHidden = false
            self.sendMessageButton.isHidden = true
            self.callNameLabel.isHidden = true
        }
    }

    func removeFromScreen() {
        self.videoContainerViewModel.callStopped()
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.viewModel.callFinished()
        self.dismiss(animated: false)
    }

    @objc
    func screenTapped() {
        if self.avatarView.isHidden {
            self.viewModel.respondOnTap()
        }
    }

    func showCancelButton() {
        // self.view.layoutIfNeeded()
    }

    func hideCancelButton() {
        self.infoContainerTopConstraint.constant = 150
        // self.view.layoutIfNeeded()
    }

    func showCallOptions() {
        // self.view.layoutIfNeeded()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
        super.viewWillTransition(to: size, with: coordinator)
    }

    func showContactInfo() {
        if !self.infoContainer.isHidden {
            self.hideContactInfo()
            return
        }
        self.isMenuShowed = true
        if !self.viewModel.conferenceMode.value {
            self.infoContainer.isHidden = false
        }
        // self.view.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.infoContainerTopConstraint.constant = -10
            // self?.view.layoutIfNeeded()
        })
    }

    func hideContactInfo() {
        self.isMenuShowed = false
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.infoContainerTopConstraint.constant = 250
            // self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            if !(self?.viewModel.conferenceMode.value ?? false) {
                self?.infoContainer.isHidden = true
            }
        })
    }

    func showAllInfo() {
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
            //  self.view.layoutIfNeeded()
        }, completion: {  _ in
        })
    }

    func contactPickerDismissed() {
        self.addTapGesture()
    }
}

extension CallViewController: PictureInPictureManagerDelegate {
    func reopenCurrentCall() {
        if self.navigationController?.topViewController != self {
            self.viewModel.reopenCall(viewControler: self)
        }
    }

    func getMenuFor(participantId: String, callId: String) -> [MenuItem] {
        return self.viewModel.getItemsForConferenceMenu(participantId: participantId, callId: callId)
    }
}
