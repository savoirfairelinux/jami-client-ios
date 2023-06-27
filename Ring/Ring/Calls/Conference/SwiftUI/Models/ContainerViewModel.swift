/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

import Foundation
import SwiftUI
import RxSwift

protocol PictureInPictureManagerDelegate: AnyObject {
    func reopenCurrentCall()
    func getMenuFor(participantId: String, callId: String) -> [MenuItem]
}

class PictureInPictureManager: NSObject, AVPictureInPictureControllerDelegate {

    var pipController: AVPictureInPictureController! = nil
    let delegate: PictureInPictureManagerDelegate

    init(delegate: PictureInPictureManagerDelegate) {
        self.delegate = delegate
    }

    func updatePIP(layer: AVSampleBufferDisplayLayer) {
        if #available(iOS 15.0, *) {
            guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
            let contentSource = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
            if pipController == nil {
                pipController = AVPictureInPictureController(contentSource: contentSource)
                pipController.delegate = self
                // Set requiresLinearPlayback to true to hide buttons from Picture in Picture except cancel and restoreView
                pipController.requiresLinearPlayback = true
                pipController.canStartPictureInPictureAutomaticallyFromInline = true
                // Hide the overlay text and controls except for the cancel and restore view buttons
                pipController.setValue(true, forKey: "controlsStyle")
            } else {
                pipController.contentSource = contentSource
            }
        }
    }
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        self.delegate.reopenCurrentCall()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        pipController.stopPictureInPicture()
        completionHandler(true)
    }

    func callStopped() {
        if #available(iOS 15.0, *) {
            if self.pipController != nil {
                self.pipController.stopPictureInPicture()
                self.pipController = nil
            }
        }
    }

    func showPiP() {
        if #available(iOS 15.0, *) {
            if self.pipController != nil {
                self.pipController.startPictureInPicture()
            }
        }
    }
}

extension PictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}

    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .zero, duration: CMTimeMake(value: 3600 * 24, timescale: 1))
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

class ContainerViewModel: ObservableObject {

    @Published var layout: CallLayout = .one

    var participants = [ParticipantViewModel]()

    // state
    private let actionsStateSubject = PublishSubject<State>()
    lazy var actionsState: Observable<State> = {
        return self.actionsStateSubject.asObservable()
    }()

    private let conferenceStateSubject = PublishSubject<State>()
    lazy var conferenceState: Observable<State> = {
        return self.conferenceStateSubject.asObservable()
    }()

    var pipManager: PictureInPictureManager

    var mainGridViewModel: MainGridViewModel = MainGridViewModel()

    let localId: String

    let disposeBag = DisposeBag()
    var videoRunningBag = DisposeBag()

    let videoService: VideoService
    let injectionBag: InjectionBag

    let actionsViewModel: ActionsViewModel
    let currentCall: Observable<CallModel>
    @Published var hasLocalVideo: Bool = false
    @Published var hasIncomingVideo: Bool = false
    @Published var localImage = UIImage()
    @Published var callAnswered = false

    lazy var capturedFrame: Observable<UIImage?> = {
        return videoService.capturedVideoFrame.asObservable().map({ frame in
            return frame
        })
    }()

    init(localId: String, delegate: PictureInPictureManagerDelegate, injectionBag: InjectionBag, currentCall: Observable<CallModel>, hasVideo: Bool, incoming: Bool) {
        self.hasLocalVideo = hasVideo
        self.hasIncomingVideo = hasVideo
        self.localId = localId
        self.injectionBag = injectionBag
        self.videoService = injectionBag.videoService
        self.currentCall = currentCall
        self.callAnswered = incoming
        self.actionsViewModel = ActionsViewModel(actionsState: self.actionsStateSubject, currentCall: currentCall, audioService: injectionBag.audioService)
        self.pipManager = PictureInPictureManager(delegate: delegate)
        self.capturedFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] frame in
                if let image = frame {
                    DispatchQueue.main.async {
                        self?.localImage = image
                    }
                }
            })
            .disposed(by: self.disposeBag)
        currentCall
            .filter({ call in
                return call.state == .current
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.callAnswered = true
            })
            .disposed(by: self.disposeBag)
    }

    func updateParticipantInfo(info: ConferenceParticipant) -> Bool {
        if let participant = participants.first(where: { $0.id == info.sinkId }) {
            participant.info = info
            let menu = self.pipManager.delegate.getMenuFor(participantId: info.uri ?? "", callId: info.sinkId)
            participant.setActions(items: menu)
            return true
        }
        return false
    }

    func addParticipantInfo(info: ConferenceParticipant) {
        let participant = ParticipantViewModel(info: info, injectionBag: injectionBag, conferenceState: self.conferenceStateSubject)
        let menu = self.pipManager.delegate.getMenuFor(participantId: info.uri ?? "", callId: info.sinkId)
        participant.setActions(items: menu)
        self.participants.append(participant)
        if self.participants.count == 1 {
            participant.videoRunning
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] hasVideo in
                    self?.hasIncomingVideo = hasVideo
                })
                .disposed(by: self.videoRunningBag)
        } else {
            videoRunningBag = DisposeBag()
        }
    }

    var activeVoiceParticipant: String = ""
    var activeParticipant: String = ""

    func conferenceUpdated(participantsInfo: [ConferenceParticipant]) {
        updateParticipants(with: participantsInfo)

        if let currentActiveParticipant = getActiveParticipant(),
           currentActiveParticipant.id != activeParticipant {
            activeParticipant = currentActiveParticipant.id
            reorderParticipantsIfNeeded(participant: currentActiveParticipant)
        }

        // Check if there is a new active voice participant and reorder the participants list if needed
        if let currentVoiceActiveParticipant = getActiveVoiceParticipant(), currentVoiceActiveParticipant.id != activeVoiceParticipant {
            activeVoiceParticipant = currentVoiceActiveParticipant.id
            reorderParticipantsIfNeeded(participant: currentVoiceActiveParticipant)
        }
        updateLayoutForConference()
        if self.participants.count == 1 {
            self.participants[0].setActions(items: [MenuItem]())
        }

        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func updateLayoutForConference() {
        let count = participants.count
        mainGridViewModel.updatedLayout(participantsCount: count, firstParticipant: participants.first?.id ?? "")
        setCallLayout(layout: getNewLayout())
    }

    private func calculateValidParticipantsCount() -> Int {
        var count = participants.count
        if count > 1 {
            count = participants.filter({ participant in
                participant.info != nil
            }).count
        }
        return count
    }

    func getNewLayout() -> CallLayout {
        if participants.count == 1 {
            return .one
        }

        guard let currentActiveParticipant = getActiveParticipant() else {
            // If there's no active participant, default to grid layout
            return .grid
        }

        let participantsWithValidVideo = getParticipantsWithValidVideoSize(excluding: currentActiveParticipant)
        return participantsWithValidVideo.isEmpty ? .one : .oneWithSmal
    }

    func getParticipantsWithValidVideoSize(excluding activeParticipant: ParticipantViewModel) -> [ParticipantViewModel] {
        return self.participants.filter { participant in
            let hasValidWidth = participant.info?.width ?? 0 > 0
            let hasValidHeight = participant.info?.height ?? 0 > 0
            return hasValidWidth && hasValidHeight
        }
        .filter { $0 != activeParticipant }
    }

    func conferenceDestroyed() {
        self.participants = [ParticipantViewModel]()
    }

    private func updateParticipants(with participantsInfo: [ConferenceParticipant]) {
        let filtered = participantsInfo.filter { participant in
            !participant.sinkId.isEmpty
        }
        let ids = Set(filtered.map { $0.sinkId })
        participants.removeAll { !ids.contains($0.id) }

        // Update participant info or add new participants
        for info in filtered where !updateParticipantInfo(info: info) {
            addParticipantInfo(info: info)
        }
    }

    private func reorderParticipantsIfNeeded(participant: ParticipantViewModel) {
        guard let currentActiveParticipant = getActiveParticipant(), let index = participants.firstIndex(of: currentActiveParticipant), !mainGridViewModel.isFirstPage(index: index) else {
            return
        }

        participants.swapAt(0, index)
    }

    private func getActiveParticipant() -> ParticipantViewModel? {
        if participants.count == 1 {
            return participants.first
        }
        return participants.first(where: { $0.info?.isActive ?? false })
    }

    private func getActiveVoiceParticipant() -> ParticipantViewModel? {
        return participants.first(where: { $0.info?.voiceActivity ?? false })
    }

    func setCallLayout(layout: CallLayout) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.layout == layout { return }
            self.layout = layout
            if let pipLayout = self.participants.filter({ participant in
                participant.info?.uri != self.localId
            }).first?.mainDisplayLayer {
                self.updatePipLayer(layer: pipLayout)
            }
        }
    }

    func callStopped() {
        self.pipManager.callStopped()
    }

    func showPiP() {
        self.pipManager.showPiP()
    }

    func updatePipLayer(layer: AVSampleBufferDisplayLayer) {
        self.pipManager.updatePIP(layer: layer)
    }
}
