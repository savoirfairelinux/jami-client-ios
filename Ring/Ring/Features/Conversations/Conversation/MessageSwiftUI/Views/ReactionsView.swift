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
    var reactions: [ReactionsRowViewModel]
    @SwiftUI.State private var contentHeight: CGFloat = 100

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(reactions) { reaction in
                    ReactionRowView(reaction: reaction)
                        .frame(height: 50)
                }
                .background(GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                })
            }
            .padding(.vertical, 20)
        }
        .onPreferenceChange(SizePreferenceKey.self) { preferences in
            self.contentHeight = preferences.height
        }
        .background(Color.blue)
        .cornerRadius(15)
        .shadow(radius: 3, x: 3, y: 3)
        .frame(maxWidth: 300, maxHeight: min(300, contentHeight), alignment: .center)
    }
}
