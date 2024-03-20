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
    @ObservedObject var requestsModel: RequestsViewModel
    @Binding var isSearchBarActive: Bool
    var body: some View {
        List {
            publicDirectorySearchView
            if model.navigationTarget == .smartList {
               smartListTopView
            } else {
                newMessageTopView
            }
            conversationsSearchHeaderView
            ConversationsView(model: model)
        }
        .listStyle(.plain)
        .hideRowSeparator()
        .sheet(isPresented: $requestsModel.requestViewOpened) {
            RequestsView(model: requestsModel)
        }
    }


    @ViewBuilder
    private var smartListTopView: some View {
        if requestsModel.unreadRequests > 0 && !isSearchBarActive {
            Button {
                requestsModel.presentRequests()
            } label: {
                RequestsIndicatorView(model: requestsModel)
            }
            .padding(0)
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
        }
    }

    @ViewBuilder
    private var newMessageTopView: some View {
        if !isSearchBarActive {
            VStack {
                actionItem(icon: "qrcode", title: "Add Contact", action: model.scanQRCode)
                actionItem(icon: "person.2", title: "Create Swarm", action: model.createSwarm)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 5, trailing: 15))
            .hideRowSeparator()
            .transition(.opacity)
        }
    }

    private func actionItem(icon: String, title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(.jamiPrimaryControl)
            Spacer()
                .frame(width: 15)
            Text(title)
                .lineLimit(1)
        }
        .padding()
        .frame(height: 35)
        .frame(maxWidth: .infinity)
        .background(Color.jamiTertiaryControl)
        .cornerRadius(12)
        .onTapGesture(perform: action)
    }

    @ViewBuilder
    private var conversationsSearchHeaderView: some View {
        if isSearchBarActive {
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
        if isSearchBarActive {
            Text(model.publicDirectoryTitle)
                .fontWeight(.semibold)
                .hideRowSeparator()

            if !model.searchQuery.isEmpty {
                searchResultView
                    .hideRowSeparator()
            } else {
                defaultPublicSearchView
                    .hideRowSeparator()
            }
        }
    }

    @ViewBuilder
    private var searchResultView: some View {
        switch model.searchStatus {
            case .foundTemporary:
                tempConversationsView
            case .foundJams:
                jamsSearchResultContainerView
            case .searching:
                searchingView
            case .noResult, .invalidId:
                noResultView
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
        VStack(alignment: .leading) {
            jamsSearchResultView(model: model)
        }
    }

    private var noResultView: some View {
        VStack(alignment: .leading) {
            Text(model.searchStatus.toString())
                .font(.callout)
        }
    }

    private var defaultPublicSearchView: some View {
        VStack(alignment: .leading) {
            Image(systemName: "network")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 30, height: 30)
        }
    }
}

