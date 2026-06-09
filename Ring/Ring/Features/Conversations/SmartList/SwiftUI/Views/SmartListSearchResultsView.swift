/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

struct SmartListSearchResultsView: View {
    @ObservedObject var model: ConversationsViewModel
    let stateEmitter: ConversationStatePublisher
    let onDismissEmptyArea: () -> Void
    @SwiftUI.State private var isShowingScanner: Bool = false

    private var conversationsView: ConversationsView {
        ConversationsView(model: model, stateEmitter: stateEmitter)
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                publicDirectorySearchView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .smartListRowStyle()
                if !model.searchQuery.isEmpty {
                    conversationsSearchHeaderView
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .smartListRowStyle()
                    conversationsView
                }
                // Preserve tap-to-dismiss on the empty area below the results.
                Color.clear
                    .frame(minHeight: geometry.size.height / 2)
                    .contentShape(Rectangle())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .hideRowSeparator()
                    .onTapGesture(perform: onDismissEmptyArea)
            }
            .listStyle(.plain)
            .id(model.currentAccountId)
        }
        .sheet(isPresented: $isShowingScanner) {
            ScanView(onCodeScanned: { [weak model, weak stateEmitter] code in
                defer {
                    isShowingScanner = false
                }
                guard let model = model,
                      let stateEmitter = stateEmitter else { return }
                model.showConversationFromQRCode(jamiId: code,
                                                 publisher: stateEmitter)
            }, injectionBag: model.injectionBag)
        }
    }

    @ViewBuilder private var newChatOptions: some View {
        HStack {
            actionItem(icon: "qrcode", title: L10n.Smartlist.newContact,
                       identifier: SmartListAccessibilityIdentifiers.newContactButton,
                       action: { isShowingScanner.toggle() })
            Spacer()
            actionItem(icon: "person.2", title: L10n.Smartlist.newGroup,
                       identifier: SmartListAccessibilityIdentifiers.newGroupButton,
                       action: { [weak model] in model?.startSwarmCreation() })
        }
        .hideRowSeparator()
        .transition(.opacity)
    }

    private func actionItem(icon: String, title: String, identifier: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(.jami)
            Text(title)
                .font(.callout)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.jamiTertiaryControl)
        .cornerRadius(12)
        .onTapGesture(perform: action)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var conversationsSearchHeaderView: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 10)
            Text(L10n.Smartlist.conversations)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .hideRowSeparator()
                .padding(.bottom, 3)
            if model.filteredConversations.isEmpty {
                Text(L10n.Smartlist.noConversationsFound)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .hideRowSeparator()
            }
        }
    }

    @ViewBuilder private var publicDirectorySearchView: some View {
        VStack(alignment: .leading) {
            if !model.isSipAccount() {
                newChatOptions
                    .padding(.vertical, 10)
            }
            if !model.searchQuery.isEmpty {
                if !model.isSipAccount() {
                    Text(model.publicDirectoryTitle)
                        .fontWeight(.semibold)
                        .hideRowSeparator()
                        .padding(.top)
                }
                searchResultView
                    .hideRowSeparator()
                    .padding(.bottom)
                    .padding(.top, 3)
                if let conversation = model.blockedConversation {
                    blockedcontactsView(conversation: conversation)
                }
            }
        }
    }

    @ViewBuilder private var searchResultView: some View {
        switch model.searchStatus {
        case .foundTemporary:
            tempConversationsView
                .hideRowSeparator()
        case .foundJams:
            jamsSearchResultContainerView
        case .searching:
            searchingView
        case .noResult, .invalidId:
            noResultView
                .hideRowSeparator()
        case .notSearching:
            EmptyView()
        }
    }

    private var searchingView: some View {
        VStack {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }

    func blockedcontactsView(conversation: ConversationViewModel) -> some View {
        VStack(alignment: .leading) {
            Text(L10n.AccountPage.blockedContacts)
                .fontWeight(.semibold)
            ConversationRowView(model: conversation, withSeparator: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { [weak conversation, weak model] in
                    guard let conversation = conversation, let model = model else { return }
                    model.showConversation(withConversationViewModel: conversation,
                                           publisher: stateEmitter)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 0, trailing: 15))
                .transition(.opacity)
                .hideRowSeparator()
        }
    }

    private var tempConversationsView: some View {
        VStack(alignment: .leading) {
            TempConversationsView(model: model, state: stateEmitter)
        }
    }

    private var jamsSearchResultContainerView: some View {
        VStack(alignment: .leading) {
            JamsSearchResultView(model: model, state: stateEmitter)
        }
    }

    private var noResultView: some View {
        VStack(alignment: .leading) {
            Text(model.searchStatus.toString())
                .font(.callout)
        }
    }
}
