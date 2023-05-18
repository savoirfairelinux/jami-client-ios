//
//  SwiftUIView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ContainerView: View {
    let model: ContainerViewModel
    var body: some View {
        switch model.layout {
        case .grid:
            CollectionView(participants: self.model.participants)
        case .oneWithSmal:
            CollectionView(participants: self.model.participants)
                .frame(height: 100)
            if let participant = model.getActiveParticipant() {
                ParticipantView(model: participant)
            }
        case .one:
            if let participant = model.getActiveParticipant() {
                ParticipantView(model: participant)
            }
        }
    }
}
