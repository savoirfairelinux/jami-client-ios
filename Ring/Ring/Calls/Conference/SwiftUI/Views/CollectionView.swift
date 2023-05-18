//
//  CollectionView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct CollectionView: View {
    @ObservedObject var model = CollectionViewModel()
    var participants: [ParticipantViewModel]
    var body: some View {
        ScrollView {
            LazyHGrid(rows: model.gridItems, spacing: 10) {
                ForEach(participants) { participant in
                    ParticipantView(model: participant)
                }
            }
            .padding()
        }
    }
}
