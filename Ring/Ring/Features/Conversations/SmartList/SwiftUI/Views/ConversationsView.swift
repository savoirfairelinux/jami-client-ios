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

struct SwipeActionsModifier: ViewModifier {
    let conversation: ConversationViewModel
    let model: ConversationsViewModel
    @SwiftUI.State private var activeAction: ConversationDestructiveAction?

    func body(content: Content) -> some View {
        let actions = ConversationDestructiveAction.availableActions(for: conversation.conversation)

        return Group {
            if #available(iOS 15.0, *) {
                content
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ForEach(actions) { action in
                            Button {
                                activeAction = action
                            } label: {
                                Label(action.swipeActionTitle(for: conversation.conversation),
                                      systemImage: action.icon(for: conversation.conversation))
                            }
                            .tint(tint(for: action))
                        }
                    }
            } else {
                content
                    .contextMenu {
                        ForEach(actions) { action in
                            Button {
                                activeAction = action
                            } label: {
                                Label(action.title(for: conversation.conversation),
                                      systemImage: action.icon(for: conversation.conversation))
                            }
                        }
                    }
            }
        }
        .alert(item: $activeAction, content: alertForAction)
    }

    private func tint(for action: ConversationDestructiveAction) -> Color {
        switch action {
        case .blockContact:
            return .jamiFailure
        case .removeContact:
            return .jamiWarning
        case .removeConversation:
            return Color(.systemGray)
        }
    }

    private func alertForAction(_ action: ConversationDestructiveAction) -> Alert {
        Alert(
            title: Text(action.title(for: conversation.conversation)),
            message: Text(action.confirmationMessage(for: conversation.conversation)),
            primaryButton: .destructive(Text(action.confirmationButtonTitle(for: conversation.conversation))) {
                model.performDestructiveAction(action, conversationViewModel: conversation)
            },
            secondaryButton: .cancel()
        )
    }
}

extension View {
    func conditionalSmartListSwipeActions(conversation: ConversationViewModel, model: ConversationsViewModel) -> some View {
        self.modifier(SwipeActionsModifier(conversation: conversation, model: model))
    }
}

struct ConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    let stateEmitter: ConversationStatePublisher
    var body: some View {
        ForEach(model.filteredConversations) { [weak model] conversation in
            if let model = model {
                Button(action: { [weak conversation, weak model] in
                    guard let conversation = conversation, let model = model else { return }
                    model.showConversation(withConversationViewModel: conversation,
                                           publisher: stateEmitter)
                }, label: {
                    // withSeparator: false — the in-content Divider() slides with the
                    // row during a swipe (native separators stay pinned), which makes
                    // the swipe reveal jumpy. Separator is handled by the List instead.
                    ConversationRowView(model: conversation, withSeparator: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                })
                .buttonStyle(.plain)
                .conditionalSmartListSwipeActions(conversation: conversation, model: model)
                .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                .listRowBackground(Color.clear)
                .conversationRowSeparator()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct TempConversationsView: View {
    @ObservedObject var model: ConversationsViewModel
    let state: ConversationStatePublisher
    var body: some View {
        if let conversation = model.temporaryConversation {
            ConversationRowView(model: conversation, withSeparator: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { [weak conversation, weak model] in
                    guard let conversation = conversation, let model = model else { return }
                    model.showConversation(withConversationViewModel: conversation,
                                           publisher: state)
                }
                .transition(.opacity)
                .accessibilityIdentifier(SmartListAccessibilityIdentifiers.temporaryConversationRow)
        }
    }
}

struct JamsSearchResultView: View {
    @ObservedObject var model: ConversationsViewModel
    let state: ConversationStatePublisher
    var body: some View {
        ForEach(model.jamsSearchResult) { conversation in
            ConversationRowView(model: conversation, withSeparator: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { [weak conversation, weak model] in
                    guard let conversation = conversation, let model = model else { return }
                    model.showConversation(withConversationViewModel: conversation,
                                           publisher: state)
                }
                .transition(.opacity)
        }
    }
}

struct ActiveCallIndicator: View {
    @SwiftUI.State private var isAnimating = false

    var body: some View {
        Image(systemName: "phone")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.jami)
            .padding(.horizontal)
            .opacity(isAnimating ? 0.4 : 1.0)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct ConversationRowView: View {
    @ObservedObject var model: ConversationViewModel
    var withSeparator: Bool = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack(alignment: .bottomTrailing) {
                    AvatarSwiftUIView(source: model.avatarProvider)
                    presenceIndicator
                }
                Spacer()
                    .frame(width: 12)
                VStack(alignment: .leading) {
                    Text(model.nameWithSuffix)
                        .fontWeight(model.unreadMessages > 0 ? .bold : .regular)
                        .lineLimit(1)
                    if model.swiftUIModel.isBlocked {
                        Spacer()
                            .frame(height: 5)
                        Text(L10n.Swarm.blocked)
                            .italic()
                            .font(.footnote)
                            .lineLimit(1)
                    } else if !model.lastMessage.isEmpty {
                        Spacer()
                            .frame(height: 5)
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(model.lastMessageDate + " -")
                                .fontWeight(.regular)
                                .font(.footnote)
                                .lineLimit(1)
                            Text( model.lastMessage)
                                .font(.footnote)
                                .lineLimit(1)
                        }
                    } else if model.swiftUIModel.isSyncing {
                        Spacer()
                            .frame(height: 5)
                        Text(L10n.Smartlist.inSynchronization)
                            .italic()
                            .font(.footnote)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if model.swiftUIModel.callBannerViewModel.isVisible {
                    ActiveCallIndicator()
                }
                if model.unreadMessages > 0 {
                    Text("\(model.unreadMessages)")
                        .fontWeight(.semibold)
                        .font(.footnote)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .foregroundColor(Color.unreadMessageText)
                        .background(Color.unreadMessageBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            if withSeparator {
                Divider()
                    .padding(.leading, Constants.defaultAvatarSize)
            }
        }
        .accessibilityElement(children: /*@START_MENU_TOKEN@*/.ignore/*@END_MENU_TOKEN@*/)
        .accessibilityLabel(constreuctChatRowAccessibilityLabel())

    }

    private var presenceIndicator: some View {
        Group {
            switch model.presence {
            case .connected:
                presenceCircle(color: Color.onlinePresence)
            case .available:
                presenceCircle(color: Color.availablePresence)
            default:
                EmptyView()
            }
        }
    }

    private func presenceCircle(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2)
            )
            .offset(x: -1, y: -1)
    }

    private func constreuctChatRowAccessibilityLabel() -> String {
        var label = "\(model.name)"

        if model.unreadMessages > 0 {
            label += ". " + L10n.Accessibility.conversationRowUnreadCount(model.unreadMessages)
        }

        if model.swiftUIModel.isBlocked {
            label += ". " + L10n.Accessibility.conversationRowBlocked
        } else if model.swiftUIModel.isSyncing {
            label += ". " + L10n.Accessibility.conversationRowSyncing
        } else if !model.lastMessage.isEmpty {
            label += ". " + L10n.Accessibility.conversationRowLastMessage(model.lastMessageDate) + ": \(model.lastMessage)"
        }

        switch model.presence {
        case .connected:
            label += ". " + L10n.Accessibility.userPresenceOnline
        case .available:
            label += ". " + L10n.Accessibility.userPresenceAvailable
        default:
            break
        }

        return label
    }

}
