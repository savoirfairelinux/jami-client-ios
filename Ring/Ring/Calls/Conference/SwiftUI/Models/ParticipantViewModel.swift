//
//  ParticipantViewModel.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import Foundation

class ParticipantViewModel: Identifiable, ObservableObject {
    let videoInput: VideoInput
    var info: ConferenceParticipant?
    let id: String
    @Published var image = UIImage()
    @Published var name = ""

    init(videoInput: VideoInput) {
        self.videoInput = videoInput
        self.id = videoInput.renderId
    }
}
