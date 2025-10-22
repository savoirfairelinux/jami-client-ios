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

class CallViewController: UIViewController, StoryboardBased, ViewModelBased, ContactPickerDelegate {

    var viewModel: CallViewModel!
    private var videoContainerViewModel: ContainerViewModel!

    private let disposeBag = DisposeBag()

    private var viewConfigured = false

    struct ViewModelProperties {
        let localId: String
        let hasVideo: Bool
        let incoming: Bool
        let callId: String
    }

    deinit {
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if self.viewModel.call != nil && !self.viewConfigured {
            self.configureIncomingVideoView()
        }
        self.view.backgroundColor = .black
        self.setupBindings()
        self.title = ""
        self.navigationItem.hidesBackButton = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func configureIncomingVideoView() {
        viewConfigured = true

        let properties = ViewModelProperties(localId: viewModel.localId(),
                                             hasVideo: viewModel.hasVideo(),
                                             incoming: viewModel.isIncoming(),
                                             callId: viewModel.callId())
        videoContainerViewModel = createContainerViewModel(with: properties)

        if let uri = viewModel.callURI(), !uri.isEmpty {
            updateParticipant(uri: uri)
        }

        subscribeCallActions()
        setupVideoView()
    }

    private func createContainerViewModel(with properties: ViewModelProperties) -> ContainerViewModel {
        return ContainerViewModel(localId: properties.localId,
                                  delegate: self,
                                  injectionBag: viewModel.injectionBag,
                                  currentCall: viewModel.currentCall.share(),
                                  hasVideo: properties.hasVideo,
                                  incoming: properties.incoming,
                                  callId: properties.callId)
    }

    private func updateParticipant(uri: String) {
        let participant = ConferenceParticipant(sinkId: viewModel.conferenceId, isActive: true)
        participant.uri = uri
        if let call = viewModel.call {
            participant.isVideoMuted = call.isAudioOnly
        }
        videoContainerViewModel.updateWith(participantsInfo: [participant], mode: .resizeAspect)
    }

    private func setupVideoView() {
        let videoViewSwiftUI = ContainerView(model: videoContainerViewModel)
        let hostingController = UIHostingController(rootView: videoViewSwiftUI)
        addChild(hostingController)
        setupHostViewConstraints(hostingController.view)
        hostingController.didMove(toParent: self)
        view.sendSubviewToBack(hostingController.view)
    }

    private func setupHostViewConstraints(_ hostView: UIView) {
        hostView.frame = view.frame
        view.addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: view.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func subscribeCallActions() {
        videoContainerViewModel.actionsState
            .subscribe(onNext: { [weak self] (state) in
                guard let self = self, let state = state as? CallAction else { return }
                self.handleCallAction(state)
            })
            .disposed(by: disposeBag)
    }

    private func handleCallAction(_ action: CallAction) {
        switch action {
        case .toggleAudio:
            viewModel.toggleMuteAudio()
        case .toggleVideo:
            viewModel.toggleMuteVideo()
        case .pauseCall:
            viewModel.togglePauseCall()
        case .endCall:
            self.handleHangUpCall()
        case .addParticipant:
            self.handleAddParticipant()
        case .switchCamera:
            viewModel.switchCamera()
        case .toggleSpeaker:
            viewModel.switchSpeaker()
        case .openConversation:
            self.handleOpenConversation()
        case .showDialpad:
            viewModel.showDialpad()
        default:
            break
        }
    }

    private func handleHangUpCall() {
        viewModel.cancelCall()
        removeFromScreen()
    }

    private func handleAddParticipant() {
        if children.contains(where: { $0.isKind(of: ContactPickerViewController.self) }) {
            return
        }
        viewModel.showContactPickerVC()
    }

    private func handleOpenConversation() {
        viewModel.showConversations()
        if !viewModel.isAudioOnly {
            videoContainerViewModel.showPiP()
        }
        dismiss(animated: false)
    }

    func showViewRecording(viewToShow: UIView, viewToBlink: UIView) {
        viewToBlink.blink()
        viewToBlink.roundedCorners = true
        viewToShow.isHidden = false
    }

    func setupBindings() {
        self.viewModel.dismisVC
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: self.disposeBag)
        self.viewModel.callFailed
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: self.disposeBag)

        self.viewModel.callStarted
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] started in
                guard let self = self else { return }
                if started && !self.viewConfigured {
                    self.configureIncomingVideoView()
                }
            })
            .disposed(by: self.disposeBag)
    }

    func removeFromScreen() {
        if self.videoContainerViewModel != nil {
            self.videoContainerViewModel.callStopped()
            self.videoContainerViewModel = nil
        }

        for child in children {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        self.viewModel.callFinished()

        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: false, completion: nil)
        } else {
            self.dismiss(animated: false, completion: nil)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
        super.viewWillTransition(to: size, with: coordinator)
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
}
