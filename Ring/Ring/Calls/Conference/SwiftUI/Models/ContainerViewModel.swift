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
import RxRelay

protocol PictureInPictureManagerDelegate {
    func reopenCurrentCall()
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
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
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

    var pipManager: PictureInPictureManager

    var collectionViewModel: CollectionViewModel

    @Published var layout: CallLayout = .one

    @Published var participants = [ParticipantViewModel]()

    let localId: String

    let disposeBag = DisposeBag()

    init(localId: String, delegate: PictureInPictureManagerDelegate) {
        self.localId = localId
        self.pipManager = PictureInPictureManager(delegate: delegate)
        self.collectionViewModel = CollectionViewModel(layout: .grid, participants: [ParticipantViewModel]())
    }

    func addVideoInput(videoInput: VideoInput, renderId: String) {
        let renderIds = self.participants.map { participant in
            participant.id
        }
        if renderIds.contains(videoInput.renderId) {
            print("video input already added for \(videoInput.renderId)")
            return
        }
        let model = ParticipantViewModel(videoInput: videoInput)
        self.participants.append(model)
        self.collectionViewModel.updateparticipants(participants: self.participants)
    }

    func removeVideoInput(renderId: String) {
        self.participants.removeAll { participant in
            participant.id == renderId
        }
    }

    func addParticipant(participantInfo: ConferenceParticipant) {
        for participant in self.participants where participant.id == participantInfo.sinkId {
            participant.info = participantInfo
            return
        }
    }

    func removeParticipant(participantInfo: ConferenceParticipant) {
        self.participants.removeAll { participant in
            participant.id == participantInfo.sinkId
        }
    }

    func conferenceUpdated(participantsInfo: [ConferenceParticipant]) {
        for participant in participantsInfo {
            self.addParticipant(participantInfo: participant)
        }

        let ids = participantsInfo.map { $0.sinkId }

        // remove
        self.participants.removeAll { participant in
            !ids.contains(participant.id)
        }
        self.collectionViewModel.updateparticipants(participants: self.participants)
    }

    func setCallLayout(layout: CallLayout) {
        if self.layout == layout { return }
        DispatchQueue.main.async {
            self.layout = layout
            if let pipLayout = self.participants.filter({ participant in
                participant.info?.uri != self.localId
            }).first?.displayLayer {
                self.updatePipLayer(layer: pipLayout)
            }
            self.collectionViewModel.setLayout(layout: self.layout)
        }
    }

    func callStopped() {
        self.pipManager.callStopped()
    }

    func showPiP() {
        self.pipManager.showPiP()
    }

    func getActiveParticipant() -> ParticipantViewModel? {
        if self.participants.count == 1 {
            return self.participants.first
        }
        return self.participants.filter { participant in
            participant.info?.isActive ?? false
        }.first
    }

    func updatePipLayer(layer: AVSampleBufferDisplayLayer) {
        self.pipManager.updatePIP(layer: layer)
    }
}
