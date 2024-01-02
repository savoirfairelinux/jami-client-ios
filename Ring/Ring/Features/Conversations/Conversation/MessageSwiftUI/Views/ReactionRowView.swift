//
//  ReactionsRowView.swift
//  Ring
//
//  Created by kateryna on 2024-01-02.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

class Reaction: Identifiable {
    let id = UUID()
    let image: Image
    let name: String
    let reasctions: String

    init(image: Image, name: String, reasctions: String) {
        self.image = image
        self.name = name
        self.reasctions = reasctions
    }
}

struct ReactionRowView: View {
    var reaction: Reaction

    var body: some View {
        HStack {
            reaction.image
                .resizable()
                .frame(width: 50, height: 50)
            Spacer()
                .frame(width: 20)
            Text(reaction.name)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer()
            Text(reaction.reasctions)
                .font(.subheadline)
                .lineLimit(nil)
        }
        .padding(.horizontal, 20)
    }
}
