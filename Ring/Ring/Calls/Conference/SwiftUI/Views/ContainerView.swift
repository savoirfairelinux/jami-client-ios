//
//  SwiftUIView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ContainerView: View {
    @ObservedObject var model: ContainerViewModel
    var body: some View {
        switch model.layout {
        case .grid:
            CollectionView(model: CollectionViewModel(layout: self.model.layout, participants: self.model.participants))
        case .oneWithSmal:
            CollectionView(model: CollectionViewModel(layout: self.model.layout, participants: self.model.participants))
                .frame(height: 100)
            if let participant = model.getActiveParticipant() {
                ParticipantView(model: participant)
            }
        case .one:
            if let participant = model.getActiveParticipant() {
                ParticipantView(model: participant)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .background(Color.black)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}
