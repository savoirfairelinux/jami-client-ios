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
    private var callViewMode: CallViewMode = .audio
    private var orientation = UIDevice.current.orientation
    private var videoContainerViewModel: ContainerViewModel!

    private let disposeBag = DisposeBag()

    private let log = SwiftyBeaver.self

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureIncomingVideView()
        self.setupBindings()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // swiftlint:disable cyclomatic_complexity
    func configureIncomingVideView() {
        let localId = self.viewModel.localId()
        let incoming = self.viewModel.call?.callType == .incoming
        let hasVideo = !(self.viewModel.call?.isAudioOnly ?? true)
        let callId = self.viewModel.call?.callId ?? ""
        videoContainerViewModel = ContainerViewModel(localId: localId,
                                                     delegate: self,
                                                     injectionBag: self.viewModel.injectionBag,
                                                     currentCall: self.viewModel.currentCall.share(),
                                                     hasVideo: hasVideo,
                                                     incoming: incoming, callId: callId)
        if let jamiId = self.viewModel.getJamiId() {
            let participant = ConferenceParticipant(sinkId: self.viewModel.conferenceId, isActive: true)
            participant.uri = jamiId
            self.videoContainerViewModel.updateWith(participantsInfo: [participant], mode: .resizeAspect)
        }

        subscribeCallActions()

        let videoViewSwiftUI = ContainerView(model: videoContainerViewModel)
        let hostingController = UIHostingController(rootView: videoViewSwiftUI)
        self.addChild(hostingController)
        hostingController.view.frame = self.view.frame
        self.view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 0).isActive = true
        hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 0).isActive = true
        hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 0).isActive = true
        hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: 0).isActive = true
        hostingController.didMove(toParent: self)
        self.view.sendSubviewToBack(hostingController.view)
    }

    func subscribeCallActions() {
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
                default:
                    break

                }
            })
            .disposed(by: self.disposeBag)
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
