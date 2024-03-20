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
                .onTapGesture {
                    model.showConversation(withConversationViewModel: conversation)
                }
        }
    }
}

struct ConversationRowView: View {
    @ObservedObject var model: ConversationViewModel
    var body: some View {
        HStack {
            if let image = model.avatar {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 45, height: 45, alignment: .center)
                    .clipShape(Circle())
            } else {
                Image(uiImage: model.getDefaultAvatar())
                    .resizable()
                    .frame(width: 45, height: 45, alignment: .center)
                    .clipShape(Circle())
            }
            Spacer()
                .frame(width: 15)
            VStack(alignment: .leading) {
                Text(model.name)
                    .bold()
                    .lineLimit(1)
                Spacer()
                    .frame(height: 5)
                if model.synchronizing.value {
                    Text("conversation in synchronization")
                        .italic()
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Text(model.lastMessage)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
    }
}

