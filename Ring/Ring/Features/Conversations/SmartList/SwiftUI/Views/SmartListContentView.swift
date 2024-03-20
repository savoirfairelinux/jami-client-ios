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
    @SwiftUI.State var mode: ConversationsViewModel.Target
    @SwiftUI.State var hideTopView: Bool = true
    @ObservedObject var requestsModel: RequestsViewModel
    @Binding var isSearchBarActive: Bool
    @SwiftUI.State var currentSearchBarStatus: Bool = false
    @SwiftUI.State var isShowingScanner: Bool = false
    @SwiftUI.State var isShowingNewMessageTop: Bool = true
    var body: some View {
        List {
            publicDirectorySearchView
            if !hideTopView {
                if mode == .smartList {
                    smartListTopView
                        .transition(.opacity)
                } else {
                    newMessageTopView
                        .transition(.opacity)
                }
            }
            conversationsSearchHeaderView
                .hideRowSeparator()
            ConversationsView(model: model)
        }
        .onAppear {
            // If there was an active search before presenting the conversation, the search results should remain the same upon returning to the page.
            if model.presentedConversation.hasPresentedConversation() && !model.searchQuery.isEmpty {
                isSearchBarActive = true
                model.presentedConversation.resetPresentedConversation()
            }
            mode = model.navigationTarget
            hideTopView = false
        }
        .onChange(of: isSearchBarActive) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isShowingNewMessageTop = !isSearchBarActive
                }
            }
        }
        .listStyle(.plain)
        .hideRowSeparator()
        .sheet(isPresented: $requestsModel.requestViewOpened) {
            RequestsView(model: requestsModel)
        }
        .sheet(isPresented: $isShowingScanner) {
            ScanView(onCodeScanned: { code in
                model.showConversationFromQRCode(jamiId: code)
                isShowingScanner = false
            }, injectionBag: model.injectionBag)
        }
    }


    @ViewBuilder
    private var smartListTopView: some View {
        if  !isSearchBarActive && (requestsModel.unreadRequests > 0 || model.connectionState == .none) {
            VStack {
                if model.connectionState == .none {
                    networkSettingsButton()
                }
                if requestsModel.unreadRequests > 0 {
                    RequestsIndicatorView(model: requestsModel)
                        .onTapGesture {
                            requestsModel.presentRequests()
                        }
                }
            }
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

    @ViewBuilder
    private var newMessageTopView: some View {
        if !isSearchBarActive {
            VStack {
                if isShowingNewMessageTop {
                    HStack {
                        actionItem(icon: "qrcode", title: "New Contact", action: {isShowingScanner.toggle()})
                        Spacer()
                        actionItem(icon: "person.2", title: "New Swarm", action: model.createSwarm)
                    }
                    .hideRowSeparator()
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
        }
    }

    private func actionItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(.jamiColor)
            Text(title)
                .font(.callout)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.jamiTertiaryControl)
        .cornerRadius(12)
        .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var conversationsSearchHeaderView: some View {
        if !model.searchQuery.isEmpty {
            Text("Conversations")
                .fontWeight(.semibold)
                .hideRowSeparator()
            if model.conversations.isEmpty {
                Text("No conversations match your search")
                    .font(.callout)
                    .hideRowSeparator()
            }
        }
    }

    @ViewBuilder
    private var publicDirectorySearchView: some View {
        if isSearchBarActive && !model.searchQuery.isEmpty {
                Text(model.publicDirectoryTitle)
                    .fontWeight(.semibold)
                    .hideRowSeparator()
                searchResultView
                    .hideRowSeparator()
            }
    }

    @ViewBuilder
    private var searchResultView: some View {
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
                SwiftUI.ProgressView()
                Spacer()
            }
        }
    }

    private var tempConversationsView: some View {
        VStack(alignment: .leading) {
            TempConversationsView(model: model)
        }
    }

    private var jamsSearchResultContainerView: some View {
        jamsSearchResultView(model: model)
    }

    private var noResultView: some View {
        VStack(alignment: .leading) {
            Text(model.searchStatus.toString())
                .font(.callout)
        }
    }
}

