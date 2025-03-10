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
    @SwiftUI.State var mode: ConversationsViewModel.Target
    @SwiftUI.State var hideTopView: Bool = true
    @ObservedObject var requestsModel: RequestsViewModel
    @Binding var isSearchBarActive: Bool
    @SwiftUI.State var currentSearchBarStatus: Bool = false
    @SwiftUI.State var isShowingScanner: Bool = false
    @SwiftUI.State var isShowingTopView: Bool = true

    var body: some View {
        // Use ScrollView instead of List to prevent memory leaks when using a conversation model inside ForEach.
        ScrollView {
            VStack(alignment: .leading) {
                publicDirectorySearchView
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                if !hideTopView {
                    if mode == .smartList {
                        smartListTopView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    } else {
                        newMessageTopView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
                conversationsSearchHeaderView
                    .hideRowSeparator()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                ConversationsView(model: model, stateEmitter: stateEmitter)
            }
            .padding(.horizontal, 15)
        }
        .transition(.opacity)
        .onAppear { [weak model] in
            guard let model = model else { return }
            // If there was an active search before presenting the conversation, the search results should remain the same upon returning to the page. Otherwise, flickering will occur.
            if model.presentedConversation.hasPresentedConversation() && !model.searchQuery.isEmpty {
                isSearchBarActive = true
                model.presentedConversation.resetPresentedConversation()
            }
            hideTopView = false
        }
        .onChange(of: isSearchBarActive) { _ in
            if isSearchBarActive {
                isShowingTopView = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isShowingTopView = !isSearchBarActive
                    }
                }
            }
        }
        .listStyle(.plain)
        .hideRowSeparator()
        .sheet(isPresented: $requestsModel.requestViewOpened) {
            RequestsView(model: requestsModel)
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

    @ViewBuilder private var smartListTopView: some View {
        if isShowingTopView && (requestsModel.unreadRequests > 0 || model.connectionState == .none) {
            VStack {
                if model.connectionState == .none {
                    networkSettingsButton()
                        .transition(.opacity)
                }
                if requestsModel.unreadRequests > 0 {
                    RequestsIndicatorView(model: requestsModel)
                        .onTapGesture { [weak requestsModel] in
                            requestsModel?.presentRequests()
                        }
                        .transition(.opacity)
                }
            }
            .padding(.bottom)
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
            .transition(.opacity)
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

    @ViewBuilder private var newMessageTopView: some View {
        if !isSearchBarActive {
            VStack {
                if isShowingTopView {
                    newChatOptions
                }
            }
            .padding(.bottom)
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
            .transition(.opacity)
        }
    }

    @ViewBuilder private var newChatOptions: some View {
        HStack {
            actionItem(icon: "qrcode", title: L10n.Smartlist.newContact, action: { isShowingScanner.toggle() })
            Spacer()
            actionItem(icon: "person.2", title: L10n.Smartlist.newGroup, action: stateEmitter.createSwarm)
        }
        .hideRowSeparator()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    @ViewBuilder private var conversationsSearchHeaderView: some View {
        VStack(alignment: .leading) {
            if isSearchBarActive {
                Spacer()
                    .frame(height: 10)
            }
            if !model.searchQuery.isEmpty {
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
    }

    @ViewBuilder private var publicDirectorySearchView: some View {
        if isSearchBarActive {
            VStack(alignment: .leading) {
                if mode == .smartList && !model.isSipAccount() {
                    newChatOptions
                        .padding(.vertical, 10)
                }
                if !model.searchQuery.isEmpty {
                    Text(model.publicDirectoryTitle)
                        .fontWeight(.semibold)
                        .hideRowSeparator()
                        .padding(.top)
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
                SwiftUI.ProgressView()
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
