//
//  ReactionsView.swift
//  Ring
//
//  Created by kateryna on 2024-01-02.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct MeasureSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geometry in
                Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
            })
    }
}

extension View {
    func measureSize() -> some View {
        self.modifier(MeasureSizeModifier())
    }
}

struct ReactionsView: View {
    var reactions: [Reaction]
    @SwiftUI.State private var contentSize: CGSize = .zero

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(reactions) { reaction in
                    ReactionRowView(reaction: reaction)
                }
            }
            .padding(.vertical, 20)
            .measureSize()
            .onPreferenceChange(SizePreferenceKey.self) { preferences in
                self.contentSize = preferences
            }
        }
        .frame(width: 300, height: min(300, contentSize.height))
        .background(Color.blue)
        .cornerRadius(15)
        .shadow(radius: 3, x: 3, y: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
