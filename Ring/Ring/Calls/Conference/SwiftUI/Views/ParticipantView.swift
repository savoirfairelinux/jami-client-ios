//
//  ParticipantView.swift
//  Ring
//
//  Created by kateryna on 2023-06-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ParticipantView: View {
    @ObservedObject var model: ParticipantViewModel
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: model.image)
            Text(model.name)
        }
    }
}
