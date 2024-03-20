//
//  ConversationsAndRequestsSegment.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct RowSeparatorHiddenModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Check for iOS 15 and above
        if #available(iOS 15.0, *) {
            content
                .listRowSeparator(.hidden) // Apply the modifier for iOS 15 and above
        } else {
            content // Just return the content for earlier iOS versions
        }
    }
}

// An extension on View to make it easy to apply our custom modifier
extension View {
    func hideRowSeparator() -> some View {
        self.modifier(RowSeparatorHiddenModifier())
    }
}

struct SmartListCotainer: View {
    @ObservedObject var model: ConversationsViewModel
    var body: some View {
        List {
            if !model.searchingLabel.isEmpty {
                Text(model.searchingLabel)
            }
            // requests
            if model.unreadRequests > 0 {
                Button {
                    model.openRequests()
                } label: {
                    Text("You have unread requests")
                }
                .hideRowSeparator()
            }
            ConversationsView(model: model)
        }
        .listStyle(.plain)
    }
}

