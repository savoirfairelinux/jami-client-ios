/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

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
                swipeButton(for: .block, color: .red, title: L10n.Global.block)
                swipeButton(for: .delete, color: .orange, title: L10n.Actions.deleteAction)
            }
            .alert(item: $activeAlert, content: alertForType)
    }

    private func swipeButton(for alertType: ActiveAlert, color: Color, title: String) -> some View {
        Button {
            activeAlert = alertType
        } label: {
            Text(title)
        }
        .tint(color)
    }

    private func alertForType(_ alertType: ActiveAlert) -> Alert {
        switch alertType {
            case .block:
                return Alert(
                    title: Text(L10n.Global.blockContact),
                    message: Text(L10n.Alerts.confirmBlockContact),
                    primaryButton: .default(Text(L10n.Global.cancel)),
                    secondaryButton: .destructive(Text(L10n.Global.block), action: model.blockConversation)
                )
            case .delete:
                return Alert(
                    title: Text(L10n.Alerts.confirmDeleteConversationTitle),
                    message: Text(L10n.Alerts.confirmDeleteConversation),
                    primaryButton: .default(Text(L10n.Global.cancel)),
                    secondaryButton: .destructive(Text(L10n.Actions.deleteAction), action: model.deleteConversation)
                )
        }
    }
}

extension View {
    @ViewBuilder
    func conditionalSmartListSwipeActions(conversation: ConversationViewModel, model: ConversationsViewModel) -> some View {
        if #available(iOS 15.0, *), model.navigationTarget == .smartList {
            self.modifier(SwipeActionsModifier(conversation: conversation, model: model))
        } else {
            self
        }
    }
}

struct ConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    @SwiftUI.State private var searchText = ""
    var body: some View {
        ForEach(model.conversations) { conversation in
            ConversationRowView(model: conversation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 0, trailing: 15))
                .onTapGesture {
                    model.showConversation(withConversationViewModel: conversation)
                }
                .conditionalSmartListSwipeActions(conversation: conversation, model: model)
        }
        .hideRowSeparator()
        .navigationBarBackButtonHidden(true)

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
//                .onTapGesture {
//                    model.showConversation(withConversationViewModel: conversation)
//                }
        }
    }
}


struct ConversationRowView: View {
    @ObservedObject var model: ConversationViewModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if let image = model.avatar {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
            //.background(Color.blue)
            Divider()//.background(Color.red)
                .padding(.leading, 45)
        }
        //.background(Color.green)
    }
}

