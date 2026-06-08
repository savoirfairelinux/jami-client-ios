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
                conversationsSearchHeaderView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .smartListRowStyle()
                // When the query is empty, filteredConversations holds every
                // conversation, so keep the full list visible; the hint only
                // appears when there are none.
                if !model.filteredConversations.isEmpty {
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
        // The paired Jami actions split the row into two equal halves: a fixed gap
        // between them and fillWidth on each so both pills fill the width evenly.
        HStack(spacing: 12) {
            actionItem(icon: "qrcode", title: L10n.Smartlist.newContact,
                       identifier: SmartListAccessibilityIdentifiers.newContactButton,
                       fillWidth: true,
                       action: { isShowingScanner.toggle() })
            actionItem(icon: "person.2", title: L10n.Smartlist.newGroup,
                       identifier: SmartListAccessibilityIdentifiers.newGroupButton,
                       fillWidth: true,
                       action: { [weak model] in model?.startSwarmCreation() })
        }
        .hideRowSeparator()
        .transition(.opacity)
    }

    private func actionItem(icon: String, title: String, identifier: String, fillWidth: Bool = false, action: @escaping () -> Void) -> some View {
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
        // Apply the fill before the background so the pill itself stretches, rather
        // than an invisible frame around a content-sized pill.
        .frame(maxWidth: fillWidth ? .infinity : nil)
        .background(Color.jamiTertiaryControl)
        .cornerRadius(12)
        .onTapGesture(perform: action)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
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
                if model.searchQuery.isEmpty {
                    sectionHint(L10n.Smartlist.conversationsSearchHint)
                } else {
                    sectionHint(L10n.Smartlist.noConversationsFound)
                }
            }
        }
    }

    private func sectionHint(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .hideRowSeparator()
    }

    @ViewBuilder private var publicDirectorySearchView: some View {
        VStack(alignment: .leading) {
            if model.isSipAccount() {
                dialpadOption
                    .padding(.vertical, 10)
            } else {
                newChatOptions
                    .padding(.vertical, 10)
            }
            directoryCard
        }
    }

    @ViewBuilder private var directoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(directorySectionTitle)
                .fontWeight(.semibold)
            directoryResultSlot
            if !model.searchQuery.isEmpty, let conversation = model.blockedConversation {
                blockedcontactsView(conversation: conversation)
            }
        }
    }

    @ViewBuilder private var directoryResultSlot: some View {
        if model.searchQuery.isEmpty {
            sectionHint(directorySectionHint)
        } else {
            searchResultView
                .hideRowSeparator()
        }
    }

    private var directorySectionTitle: String {
        model.isSipAccount() ? L10n.Smartlist.callANumber : model.publicDirectoryTitle
    }

    private var directorySectionHint: String {
        model.isSipAccount() ? L10n.Smartlist.callANumberHint : model.publicDirectoryHint
    }

    @ViewBuilder private var dialpadOption: some View {
        // A lone action: keep it content-sized and leading, matching the size of
        // a single Jami action pill rather than stretching the full width.
        HStack {
            actionItem(icon: "circle.grid.3x3.fill", title: L10n.Smartlist.dialpad,
                       identifier: SmartListAccessibilityIdentifiers.dialpadButton,
                       action: stateEmitter.showDialpad)
            Spacer()
        }
        .hideRowSeparator()
        .transition(.opacity)
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
        // Same helper-text style as the section hints (callout, secondary).
        sectionHint(model.searchStatus.toString())
    }
}
