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

import Foundation
import SwiftUI

struct RequestsIndicatorView: View {
    @ObservedObject var model: RequestsViewModel
    private let iconSize: CGFloat = 25
    private let cornerRadius: CGFloat = 12
    private let padding: CGFloat = 15
    private let badgePadding: CGFloat = 8
    private let badgeCornerRadius: CGFloat = 4
    private let verticalPaddingForBadge: CGFloat = 20
    private let horizontalPaddingForBody: CGFloat = 20
    private let verticalTextPadding: CGFloat = 5

    var body: some View {
        HStack(spacing: horizontalPaddingForBody) {
            icon
            description
            Spacer()
            unreadCounter
        }
        .frame(maxWidth: .infinity)
        .background(Color.jamiPrimaryControl)
        .cornerRadius(cornerRadius)
    }

    private var icon: some View {
        Image(systemName: "envelope.badge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(.white)
            .padding(.leading, horizontalPaddingForBody)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: verticalTextPadding) {
            Text(model.title)
                .bold()
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.white)
            Text(model.requestNames)
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(.white)
        }
    }

    private var unreadCounter: some View {
        Text("\(model.unreadRequests)")
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, badgePadding)
            .padding(.vertical, 4)
            .background(Color.jamiSecondaryControl)
            .clipShape(RoundedRectangle(cornerRadius: badgeCornerRadius))
            .padding(.vertical, verticalPaddingForBadge)
            .padding(.trailing, horizontalPaddingForBody)
    }
}

struct RequestsView: View {
    @ObservedObject var model: RequestsViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text(model.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 20)

                requestsList
            }
            .background(Color.jamiRequestsColor.ignoresSafeArea())
        }
    }

    private var requestsList: some View {
        List(model.requestsRow) { request in
            RequestsRowView(requestRow: request, nameResolver: request.nameResolver, listModel: model)
                .listRowBackground(Color.jamiRequestsColor)
        }
        .listStyle(PlainListStyle())
        .edgesIgnoringSafeArea(.all)
        .background(Color.jamiRequestsColor)
    }
}

struct RequestsRowView: View {
    @ObservedObject var requestRow: RequestRowViewModel
    @ObservedObject var nameResolver: RequestNameResolver
    var listModel: RequestsViewModel

    // Constants
    private let actionIconSize: CGFloat = 20
    private let spacerWidth: CGFloat = 15
    private let spacerHeight: CGFloat = 20
    private let buttonPadding: CGFloat = 10
    private let dividerOpacity: Double = 0.1
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            userInfoView
            Spacer().frame(height: spacerHeight)
            actionButtonsView
            Spacer().frame(height: spacerHeight)
            Divider()
                .background(Color.white.opacity(dividerOpacity))
        }
    }

    private var userInfoView: some View {
        HStack(alignment: .center) {
            avatarView
            Spacer().frame(width: spacerWidth)
            VStack(alignment: .leading, spacing: 5) {
                Text(nameResolver.bestName)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(requestRow.receivedDate)
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            Spacer()
            Text(requestRow.status.toString())
                .font(.footnote)
                .padding(.horizontal, buttonPadding)
                .foregroundColor(requestRow.status.color())
        }
    }

    private var avatarView: some View {
        Group {
            if let avatar = requestRow.avatar {
                Image(uiImage: avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: requestRow.avatarSize, height: requestRow.avatarSize)
                    .clipShape(Circle())
            }
        }
    }

    private var actionButtonsView: some View {
        HStack {
            actionIcon("slash.circle") {
                listModel.block(requestRow: requestRow)
            }
            Spacer().frame(width: spacerWidth)
            actionIcon("xmark") {
                listModel.discard(requestRow: requestRow)
            }
            Spacer().frame(width: spacerWidth)
            actionIcon("checkmark") {
                listModel.accept(requestRow: requestRow)
            }
        }
    }

    private func actionIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: actionIconSize, height: actionIconSize)
            .foregroundColor(.white)
            .padding(.horizontal, buttonPadding)
            .padding(.vertical, buttonPadding)
            .frame(maxWidth: .infinity)
            .background(Color.jamiPrimaryControl)
            .cornerRadius(cornerRadius)
            .onTapGesture(perform: action)
    }
}
