//
//  ConversationsView.swift
//  Ring
//
//  Created by kateryna on 2024-03-19.
//  Copyright © 2024 Savoir-faire Linux. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct SwipeActionsModifier: ViewModifier {
    enum ActiveAlert: Identifiable {
        case block, delete
        var id: Self { self }
    }
    let conversation: ConversationViewModel
    let model: ConversationsViewModel
    @SwiftUI.State private var activeAlert: ActiveAlert?

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing) {
                Button {
                    activeAlert = .block
                    //model.blockConversation()
                } label: {
                    Text("Block")
                }
                .tint(.red)

                Button {
                    activeAlert = .delete
                    //model.deleteConversation()
                } label: {
                    Text("Delete")
                }
                .tint(.orange)
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                    case .block:
                        return Alert(
                            title: Text(L10n.Global.blockContact),
                            message: Text(L10n.Alerts.confirmBlockContact),
                            primaryButton: .default(
                                Text("Cancel"),
                                action: {}
                            ),
                            secondaryButton: .destructive(
                                Text("Block"),
                                action: {}
                            )
                        )
                    case .delete:
                        return Alert(
                            title: Text(L10n.Alerts.confirmDeleteConversationTitle),
                            message: Text(L10n.Alerts.confirmDeleteConversation),
                            primaryButton: .default(
                                Text("Cancel"),
                                action: {}
                            ),
                            secondaryButton: .destructive(
                                Text("Delete"),
                                action: {}
                            )
                        )
                }
            }
    }
}

extension View {
    @ViewBuilder
    func conditionalSwipeActions(conversation: ConversationViewModel, model: ConversationsViewModel) -> some View {
        if #available(iOS 15.0, *) {
            self.modifier(SwipeActionsModifier(conversation: conversation, model: model))
        } else {
            self
        }
    }
}

struct ConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedConversation: ConversationViewModel?
    var body: some View {
        ForEach(model.conversations) { conversation in
            if #available(iOS 15.0, *) {
                NavigationLink(destination: MessagesListView(model: conversation.swiftUIModel).navigationBarBackButtonHidden(true).highPriorityGesture(
                    DragGesture().onChanged { _ in }
                )) {
                    ConversationRowView(model: conversation)
                }
            } else {
                NavigationLink(destination: MessagesListView(model: conversation.swiftUIModel).navigationBarBackButtonHidden(true)) {
                    ConversationRowView(model: conversation)
                }
            }
//            ConversationRowView(model: conversation)
//                .onTapGesture {
//                   // self.presentationMode.wrappedValue.dismiss()
//                    NavigationLink("New message") {
//                        MessagesListView(model: conversation.swiftUIModel)
//                    }
//                   // self.selectedConversation = conversation
////                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
////                        self.presentationMode.wrappedValue.dismiss()
////                    }
//                    // open conversation sheep
//                }
               // .conditionalSwipeActions(conversation: conversation, model: model)
        }
//        .sheet(item: $selectedConversation) { conversation in
//            // Here you present the conversation detail view in another sheet
//            // Assuming you have a ConversationDetailView that takes a ConversationModel
//            MessagesListView(model: conversation.swiftUIModel)
//        }
    }
}

struct TempConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    var body: some View {
        if let conversation = model.temporaryConversation {
            ConversationRowView(model: conversation)
                .onTapGesture {
                    model.showConversation(withConversationViewModel: conversation)
                }
        }
    }
}

struct jamsSearchResultView: View {
    @ObservedObject var model: ConversationsViewModel
    var body: some View {
        ForEach(model.jamsSearchResult) { conversation in
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

