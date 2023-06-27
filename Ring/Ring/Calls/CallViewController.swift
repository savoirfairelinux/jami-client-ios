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
        self.setupBindings()
        UIApplication.shared.isIdleTimerDisabled = true
        self.configureConferenceLayout()
        self.configureConferenceInfo()

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

        //        self.viewModel.renderStarted
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] sinkId in
        //                if sinkId == self?.viewModel.conferenceId {
        //                    self?.incomingVideoStarted()
        //                }
        //            })
        //            .disposed(by: self.disposeBag)
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
                self.videoRecordView.isHidden = !flagStatus
            })
            .disposed(by: disposeBag)

        self.viewModel.dismisVC
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.contactName.drive(self.callNameLabel.rx.text)
            .disposed(by: self.disposeBag)

        //        self.viewModel.callDuration
        //            .asObservable()
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] _ in
        //                if self?.durationLabel.text != "" {
        //                    if self?.callViewMode == .audio {
        //                        self?.spinner.stopAnimating()
        //                        UIView.animate(withDuration: 0.3, animations: {
        //                            self?.durationLabel.alpha = 1
        //                        })
        //                    }
        //                }
        //            })
        //            .disposed(by: self.disposeBag)

        self.viewModel.callDuration.drive(self.callInfoTimerLabel.rx.text)
            .disposed(by: self.disposeBag)

        //        self.viewModel.bottomInfo
        //            .observe(on: MainScheduler.instance)
        //            .bind(to: self.infoBottomLabel.rx.text)
        //            .disposed(by: self.disposeBag)

        self.viewModel.showCallOptions
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                if show {
                    self?.showContactInfo()
                }
            })
            .disposed(by: self.disposeBag)

        //        self.viewModel.showCancelOption
        //            .observe(on: MainScheduler.instance)
        //            .subscribe(onNext: { [weak self] show in
        //                if show {
        //                    self?.showCancelButton()
        //                }
        //            })
        //            .disposed(by: self.disposeBag)
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

    func removeFromScreen() {
        self.videoContainerViewModel.callStopped()
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.viewModel.callFinished()
        self.dismiss(animated: false)
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
        UIView.animate(withDuration: 0.2, animations: {
            contactPickerVC.view.frame = newFrame
        }, completion: {  _ in
        })
    }
}

extension CallViewController: PictureInPictureManagerDelegate {
    func reopenCurrentCall() {
        if self.navigationController?.topViewController != self {
            self.viewModel.reopenCall(viewControler: self)
        }
    }

    func getMenuFor(participantId: String, callId: String) -> [MenuItem] {
        return [MenuItem.maximize]
        //        return self.viewModel.getItemsForConferenceMenu(participantId: participantId, callId: callId)
    }
}
