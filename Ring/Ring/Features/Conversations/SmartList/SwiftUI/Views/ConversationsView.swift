//
//  ConversationsView.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

struct ConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    var body: some View {
        ForEach(model.conversations) { conversation in
            ConversationRowView(model: conversation)
                .frame(height: 100)
                .onTapGesture {
                    model.showConversation(withConversationViewModel: conversation)
                }
        }
    }

struct ConversationRowView: View {
    @ObservedObject var model: ConversationViewModel
    var body: some View {
        HStack {
            Image(uiImage: model.avatar)
                .resizable()
                .frame(width: 30, height: 30, alignment: .center)
                .clipShape(Circle())
            VStack {
                Text(model.name)
                    .lineLimit(1)
                Text(model.lastMessage)
                    .lineLimit(1)
            }
        }
    }
}

