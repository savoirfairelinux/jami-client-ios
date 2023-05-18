//
//  ContainerViewModel.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation
import SwiftUI

class ContainerViewModel: ObservableObject {

    @Published var layout: CallLayout = .grid

    @Published var participants = [ParticipantViewModel]()

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
    }

    func addParticipant(participantInfo: ConferenceParticipant) {
        for participant in self.participants where participant.id == participantInfo.sinkId {
            participant.info = participantInfo
            return
        }
    }

    func removeVideoInput(renderId: String) {
        self.participants.removeAll { participant in
            participant.id == renderId
        }
    }

    func removeParticipant(participantInfo: ConferenceParticipant) {
        self.participants.removeAll { participant in
            participant.id == participantInfo.sinkId
        }
    }

    func setCallLayout(layout: CallLayout) {
        self.layout = layout
    }

    func getActiveParticipant() -> ParticipantViewModel? {
        return self.participants.filter { participant in
            participant.info?.isActive ?? false
        }.first
    }

}
