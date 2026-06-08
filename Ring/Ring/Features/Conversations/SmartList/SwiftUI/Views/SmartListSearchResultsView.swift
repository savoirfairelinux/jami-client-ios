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
    @SwiftUI.State private var isShowingContactPicker: Bool = false

    private enum Layout {
        static let actionRowSpacing: CGFloat = 12
        static let verticalPadding: CGFloat = 15
        static let actionIconSize: CGFloat = 18
        static let actionCornerRadius: CGFloat = 12
    }

    private var isSipAccount: Bool { model.isSipAccount() }
    private var showsDirectorySection: Bool { !isSipAccount || !model.searchQuery.isEmpty }

    private var conversationsView: ConversationsView {
        ConversationsView(model: model, stateEmitter: stateEmitter)
    }

    var body: some View {
        List {
            accountActions
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.vertical, Layout.verticalPadding)
                .padding(.bottom, 10)
                .smartListRowStyle()
            if showsDirectorySection {
                directorySection
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.bottom, Layout.verticalPadding)
                    .smartListRowStyle()
            }
            conversationsSearchHeaderView
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .smartListRowStyle()
            if !model.filteredConversations.isEmpty {
                conversationsView
            }
            // Preserve tap-to-dismiss on the empty area below the results.
            Color.clear
                .frame(minHeight: 600)
                .contentShape(Rectangle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .hideRowSeparator()
                .onTapGesture(perform: onDismissEmptyArea)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 30)
        .id(model.currentAccountId)
        .sheet(isPresented: $isShowingScanner) {
            ScanView(onCodeScanned: { code in
                isShowingScanner = false
                model.showConversationFromQRCode(jamiId: code,
                                                 publisher: stateEmitter)
            }, injectionBag: model.injectionBag)
        }
        .sheet(isPresented: $isShowingContactPicker) {
            ContactPicker { contact in
                isShowingContactPicker = false
                model.showSipConversation(withNumber: contact, publisher: stateEmitter)
            }
            .accessibility(identifier: SmartListAccessibilityIdentifiers.contactPicker)
        }
    }

    private var newChatOptions: some View {
        HStack(spacing: Layout.actionRowSpacing) {
            actionItem(icon: "qrcode", title: L10n.Smartlist.newContact,
                       identifier: SmartListAccessibilityIdentifiers.newContactButton,
                       fillWidth: true,
                       action: { isShowingScanner.toggle() })
            actionItem(icon: "person.2", title: L10n.Smartlist.newGroup,
                       identifier: SmartListAccessibilityIdentifiers.newGroupButton,
                       fillWidth: true,
                       action: { model.startSwarmCreation() })
        }
    }

    private func actionItem(icon: String, title: String, identifier: String, fillWidth: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.actionIconSize, height: Layout.actionIconSize)
                    .foregroundColor(.jami)
                Text(title)
                    .font(.callout)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .background(Color.jamiTertiaryControl)
            .cornerRadius(Layout.actionCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private var conversationsSearchHeaderView: some View {
        VStack(alignment: .leading, spacing: Layout.verticalPadding) {
            Text(L10n.Smartlist.conversations)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
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
    }

    @ViewBuilder private var accountActions: some View {
        if isSipAccount {
            sipActions
        } else {
            newChatOptions
        }
    }

    @ViewBuilder private var directorySection: some View {
        VStack(alignment: .leading, spacing: Layout.verticalPadding) {
            if !isSipAccount {
                Text(model.publicDirectoryTitle)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
            }
            if model.searchQuery.isEmpty {
                sectionHint(model.publicDirectoryHint)
            } else {
                searchResultView
            }
            if !model.searchQuery.isEmpty, let conversation = model.blockedConversation {
                blockedContactsView(conversation: conversation)
            }
        }
    }

    private var sipActions: some View {
        HStack(spacing: Layout.actionRowSpacing) {
            actionItem(icon: "circle.grid.3x3.fill", title: L10n.Smartlist.dialpad,
                       identifier: SmartListAccessibilityIdentifiers.dialpadButton,
                       fillWidth: true,
                       action: stateEmitter.showDialpad)
            actionItem(icon: "person.crop.circle", title: L10n.ContactPicker.contacts,
                       identifier: SmartListAccessibilityIdentifiers.contactsButton,
                       fillWidth: true,
                       action: { isShowingContactPicker = true })
        }
    }

    @ViewBuilder private var searchResultView: some View {
        switch model.searchStatus {
        case .foundTemporary:
            TempConversationsView(model: model, state: stateEmitter)
        case .foundJams:
            JamsSearchResultView(model: model, state: stateEmitter)
        case .searching:
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        case .noResult, .invalidId:
            sectionHint(model.searchStatus.toString())
        case .notSearching:
            EmptyView()
        }
    }

    private func blockedContactsView(conversation: ConversationViewModel) -> some View {
        VStack(alignment: .leading, spacing: Layout.verticalPadding) {
            Text(L10n.AccountPage.blockedContacts)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            ConversationRowView(model: conversation, withSeparator: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.showConversation(withConversationViewModel: conversation,
                                           publisher: stateEmitter)
                }
        }
    }
}
