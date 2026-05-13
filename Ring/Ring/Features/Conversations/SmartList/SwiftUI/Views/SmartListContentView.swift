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

struct SmartListContentView: View {
    @ObservedObject var model: ConversationsViewModel
    let stateEmitter: ConversationStatePublisher
    @ObservedObject var requestsModel: RequestsViewModel
    /// Called (in `.list` mode) to re-open search when returning to a conversation
    /// that was opened from search results.
    var onRestoreSearch: (() -> Void)?
    var onAddContact: (() -> Void)?
    @Environment(\.sizeCategory) private var sizeCategory

    private var conversationsView: ConversationsView {
        ConversationsView(model: model, stateEmitter: stateEmitter)
    }

    var body: some View {
        listContent
    }

    private var listContent: some View {
        List {
            if !model.searchFlow.isActive {
                smartListTopView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                conversationsView
            }
        }
        .listStyle(.plain)
        .overlay {
            if showsNoConversations {
                noConversationsView()
            }
        }
        .id(model.currentAccountId)
        .onAppear { [weak model] in
            guard let model = model else { return }
            if model.smartListDidReappear() {
                onRestoreSearch?()
            }
        }
        .sheet(isPresented: $requestsModel.requestViewOpened) {
            RequestsView(model: requestsModel)
        }
    }

    private var showsNoConversations: Bool {
        !model.searchFlow.isActive
            && model.conversationsLoaded
            && model.filteredConversations.isEmpty
            && model.searchQuery.isEmpty
            && requestsModel.unreadRequests == 0
            && model.connectionState != .none
    }

    @ViewBuilder private var smartListTopView: some View {
        if requestsModel.unreadRequests > 0 || model.connectionState == .none {
            VStack {
                if model.connectionState == .none {
                    networkSettingsButton()
                }
                if requestsModel.unreadRequests > 0 {
                    RequestsIndicatorView(model: requestsModel)
                        .onTapGesture { [weak requestsModel] in
                            requestsModel?.presentRequests()
                        }
                }
            }
            .padding(.bottom)
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
        }
    }

    private func networkSettingsButton() -> some View {
        HStack {
            networkInfo()
            Spacer()
                .frame(width: 15)
            Image(systemName: "gear")
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(Color.networkAlertBackground)
        .cornerRadius(12)
        .onTapGesture {
            openSettings()
        }
    }

    private func networkInfo() -> some View {
        VStack(spacing: 5) {
            Text(L10n.Smartlist.noNetworkConnectivity)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text(L10n.Smartlist.cellularAccess)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, completionHandler: nil)
        }
    }

    private func noConversationsView() -> some View {
        let emptyStateSpacing: CGFloat = 16
        let textSpacing: CGFloat = 7
        let iconSize: CGFloat = 40
        let buttonIconSize: CGFloat = 18
        let buttonSpacing: CGFloat = 8
        let textHorizontalPadding: CGFloat = sizeCategory.isAccessibilityCategory ? 16 : 48
        return VStack(spacing: emptyStateSpacing) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: iconSize))
                .foregroundColor(Color.jami)
                .accessibilityHidden(true)
            VStack(spacing: textSpacing) {
                Text(L10n.Smartlist.noConversations)
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color(UIColor.label))
                Text(model.isSipAccount() ? L10n.Smartlist.noConversationsSubtitleSip : L10n.Smartlist.noConversationsSubtitle)
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, textHorizontalPadding)
            HStack(spacing: buttonSpacing) {
                Button(action: { onAddContact?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .frame(width: buttonIconSize, height: buttonIconSize)
                            .foregroundColor(.jami)
                            .accessibilityHidden(true)
                        Text(L10n.Smartlist.addContact)
                            .font(.callout)
                            .foregroundColor(Color(UIColor.label))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.jamiTertiaryControl)
                    .cornerRadius(12)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.Smartlist.addContact)
                .accessibilityAddTraits(.isButton)
                if !model.isSipAccount() {
                    ShareButtonView(infoToShare: model.accountInfoToShare) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: buttonIconSize, height: buttonIconSize)
                            .foregroundColor(.jami)
                            .padding(.horizontal, 12)
                            .frame(maxHeight: .infinity)
                            .background(Color.jamiTertiaryControl)
                            .cornerRadius(12)
                            .accessibilityLabel(L10n.Smartlist.shareJamiId)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}
