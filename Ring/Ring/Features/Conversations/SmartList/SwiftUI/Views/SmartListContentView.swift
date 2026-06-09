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
        .id(model.currentAccountId)
        .onAppear { [weak model] in
            guard let model = model else { return }
            // If there was an active search before presenting the conversation, restore
            // it upon returning to the page. Otherwise, flickering will occur.
            if model.presentedConversation.hasPresentedConversation() && !model.searchQuery.isEmpty {
                model.presentedConversation.resetPresentedConversation()
                onRestoreSearch?()
            }
        }
        .sheet(isPresented: $requestsModel.requestViewOpened) {
            RequestsView(model: requestsModel)
        }
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
}
