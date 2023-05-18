//
//  VideoViewsContainer.swift
//  Ring
//
//  Created by kateryna on 2023-05-18.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

class VideoViewsContainer: UIView {
    private var participants: [ConferenceParticipant] = [ConferenceParticipant]()

    func addParticipant(participant: ConferenceParticipant) {
        self.participants.append(participant)
        self.layoutParticipantsViews()
    }

    func removeParticipant(participantToRemove: ConferenceParticipant) {
        self.participants.removeAll { participant in
            participantToRemove == participant
        }
        self.layoutParticipantsViews()
    }

    func layoutParticipantsViews() {
    }
}
