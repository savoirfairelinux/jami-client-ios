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

import Reusable
import RxSwift
import SwiftUI
import SwiftyBeaver
import UIKit

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

    override func viewDidLoad() {
        super.viewDidLoad()
        if viewModel.call != nil && !viewConfigured {
            configureIncomingVideoView()
        }
        setupBindings()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func configureIncomingVideoView() {
        viewConfigured = true

        let properties = ViewModelProperties(localId: viewModel.localId(),
                                             hasVideo: viewModel.hasVideo(),
                                             incoming: viewModel.isIncoming(),
                                             callId: viewModel.callId())
        videoContainerViewModel = createContainerViewModel(with: properties)

        if let jamiId = viewModel.getJamiId() {
            updateParticipant(jamiId: jamiId)
        }

        subscribeCallActions()
        setupVideoView()
    }

    private func createContainerViewModel(with properties: ViewModelProperties)
    -> ContainerViewModel {
        return ContainerViewModel(localId: properties.localId,
                                  delegate: self,
                                  injectionBag: viewModel.injectionBag,
                                  currentCall: viewModel.currentCall.share(),
                                  hasVideo: properties.hasVideo,
                                  incoming: properties.incoming,
                                  callId: properties.callId)
    }

    private func updateParticipant(jamiId: String) {
        let participant = ConferenceParticipant(sinkId: viewModel.conferenceId, isActive: true)
        participant.uri = jamiId
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
            .subscribe(onNext: { [weak self] state in
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
        case .hangUpCall:
            handleHangUpCall()
        case .addParticipant:
            handleAddParticipant()
        case .switchCamera:
            viewModel.switchCamera()
        case .toggleSpeaker:
            viewModel.switchSpeaker()
        case .openConversation:
            handleOpenConversation()
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
        viewModel.dismisVC
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: disposeBag)
        viewModel.callFailed
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] dismiss in
                if dismiss {
                    self?.removeFromScreen()
                }
            })
            .disposed(by: disposeBag)

        viewModel.callStarted
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] started in
                guard let self = self else { return }
                if started, !self.viewConfigured {
                    self.configureIncomingVideoView()
                }
            })
            .disposed(by: disposeBag)
    }

    func removeFromScreen() {
        if videoContainerViewModel != nil {
            videoContainerViewModel.callStopped()
        }
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        viewModel.callFinished()
        dismiss(animated: false)
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        viewModel.setCameraOrientation(orientation: UIDevice.current.orientation)
        super.viewWillTransition(to: size, with: coordinator)
    }

    // MARK: ContactPickerDelegate

    func presentContactPicker(contactPickerVC: ContactPickerViewController) {
        addChild(contactPickerVC)
        let newFrame = CGRect(
            x: 0,
            y: view.frame.size.height * 0.3,
            width: view.frame.size.width,
            height: view.frame.size.height * 0.7
        )
        let initialFrame = CGRect(
            x: 0,
            y: view.frame.size.height,
            width: view.frame.size.width,
            height: view.frame.size.height * 0.7
        )
        contactPickerVC.view.frame = initialFrame
        view.addSubview(contactPickerVC.view)
        contactPickerVC.didMove(toParent: self)
        UIView.animate(withDuration: 0.2, animations: {
            contactPickerVC.view.frame = newFrame
        }, completion: { _ in
        })
    }
}

extension CallViewController: PictureInPictureManagerDelegate {
    func reopenCurrentCall() {
        if navigationController?.topViewController != self {
            viewModel.reopenCall(viewControler: self)
        }
    }
}
