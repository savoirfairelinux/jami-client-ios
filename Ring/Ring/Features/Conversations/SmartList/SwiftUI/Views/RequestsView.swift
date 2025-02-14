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
    private let badgeCornerRadius: CGFloat = 5
    private let verticalPaddingForBadge: CGFloat = 20
    private let horizontalPaddingForBody: CGFloat = 20
    private let verticalTextPadding: CGFloat = 5
    private let foregroundColor: Color = Color(UIColor.systemBackground)

    var body: some View {
        HStack(spacing: horizontalPaddingForBody) {
            icon
            description
            Spacer()
            unreadCounter
        }
        .frame(maxWidth: .infinity)
        .background(Color.jamiRequestsColor)
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: /*@START_MENU_TOKEN@*/.ignore/*@END_MENU_TOKEN@*/)
        .accessibilityLabel(L10n.Accessibility.pendingRequestsRow(model.unreadRequests))
        .accessibilityHint(L10n.Accessibility.pendingRequestsRowHint)
    }

    private var icon: some View {
        Image(systemName: "envelope.badge")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .foregroundColor(foregroundColor)
            .padding(.leading, horizontalPaddingForBody)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: verticalTextPadding) {
            Text(model.title)
                .lineLimit(1)
                .foregroundColor(foregroundColor)
            Text(model.requestNames)
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(foregroundColor)
        }
    }

    private var unreadCounter: some View {
        Text("\(model.unreadRequests)")
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(Color.requestBadgeForeground)
            .padding(.horizontal, badgePadding)
            .padding(.vertical, 4)
            .background(Color.requestsBadgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: badgeCornerRadius))
            .padding(.vertical, verticalPaddingForBadge)
            .padding(.trailing, horizontalPaddingForBody)
    }
}

struct RequestsView: View {
    @ObservedObject var model: RequestsViewModel
    @Environment(\.presentationMode)
    var presentation

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    HStack {
                        Spacer() // Push the close button to the right

                        CloseButton(
                            action: { presentation.wrappedValue.dismiss() },
                            accessibilityIdentifier: SmartListAccessibilityIdentifiers.requestsCloseButton
                        )
                    }

                    Text(model.title)
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .frame(maxWidth: .infinity, alignment: .center) // This will center the image horizontally
                }

                requestsList
            }
            .background(Color.jamiRequestsColor.ignoresSafeArea())
        }
    }

    private var requestsList: some View {
        ScrollView {
            ForEach(model.requestsRow) { request in
                RequestsRowView(requestRow: request, nameResolver: request.nameResolver, listModel: model)
                    .hideRowSeparator()
                    .transition(.slide)
            }
            .hideRowSeparator()
            .edgesIgnoringSafeArea(.all)
            .background(Color.jamiRequestsColor)
        }
    }
}

struct RequestsRowView: View {
    @ObservedObject var requestRow: RequestRowViewModel
    @ObservedObject var nameResolver: RequestNameResolver
    var listModel: RequestsViewModel
    @SwiftUI.State private var rotationDegrees: Double = 0
    private var scaleFactor: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 1.05 : 1.1
    }

    // Constants
    private let actionIconSize: CGFloat = 20
    private let spacerWidth: CGFloat = 15
    private let spacerHeight: CGFloat = 20
    private let buttonPadding: CGFloat = 10
    private let dividerOpacity: Double = 0.2
    private let cornerRadius: CGFloat = 12
    private let foregroundColor: Color = Color(UIColor.systemBackground)

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: requestRow.markedToRemove ? 30 : spacerHeight)
            userInfoView
            Spacer().frame(height: spacerHeight)
            actionButtonsView
            Spacer().frame(height: requestRow.markedToRemove ? 30 : spacerHeight)
            Divider()
                .background(Color(UIColor.systemBackground).opacity(requestRow.markedToRemove ? 0 : dividerOpacity))
        }
        .padding(.horizontal, spacerWidth)
        .background(backgroundView)
        .scaleEffect(requestRow.markedToRemove ? scaleFactor : 1)
        .zIndex(requestRow.markedToRemove ? 1 : 0)
        .rotationEffect(.degrees(rotationDegrees))
        .padding(.horizontal, requestRow.markedToRemove ? 22 : 0)
        .onChange(of: requestRow.markedToRemove) { newValue in
            self.handleMarkedToRemoveChange(newValue)
        }
    }

    private func handleMarkedToRemoveChange(_ newValue: Bool) {
        if newValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                bounceAnimation()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.5)) {
                rotationDegrees = 0
            }
        }
    }

    private var backgroundView: some View {
        Color.jamiRequestsColor
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(requestRow.markedToRemove ? 0.9 : 0), radius: requestRow.markedToRemove ? 2 : 0)
    }

    private func bounceAnimation() {
        let animationDuration = 0.1
        let springAnimation = Animation.interpolatingSpring(stiffness: 120, damping: 35)

        let rotations: [CGFloat] = [5, -5, 5, -5, 0]

        func animateRotation(index: Int) {
            guard index < rotations.count else { return }

            withAnimation(springAnimation) {
                rotationDegrees = rotations[index]
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                animateRotation(index: index + 1)
            }
        }

        animateRotation(index: 0)
    }

    private var userInfoView: some View {
        HStack(alignment: .center) {
            avatarView
            Spacer().frame(width: spacerWidth)
            VStack(alignment: .leading, spacing: 5) {
                Text(nameResolver.bestName)
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)
                Text(requestRow.receivedDate)
                    .font(.footnote)
                    .foregroundColor(foregroundColor)
            }
            Spacer()
            Text(requestRow.status.toString())
                .padding(.horizontal, buttonPadding)
                .foregroundColor(requestRow.status.color())
        }
        .accessibilityElement(children: .combine)
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
            actionIcon("slash.circle", L10n.Accessibility.pendingRequestsListBlockUser) {
                listModel.block(requestRow: requestRow)
            }
            Spacer().frame(width: spacerWidth)
            actionIcon("xmark", L10n.Accessibility.pendingRequestsListRejectInvitation) {
                listModel.discard(requestRow: requestRow)
            }
            Spacer().frame(width: spacerWidth)
            actionIcon("checkmark", L10n.Accessibility.pendingRequestsListAcceptInvitation) {
                listModel.accept(requestRow: requestRow)
            }
        }
    }

    private func actionIcon(_ systemName: String, _ accessibilityLabelValue: String, action: @escaping () -> Void) -> some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: actionIconSize, height: actionIconSize)
            .foregroundColor(Color.requestBadgeForeground)
            .padding(.horizontal, buttonPadding)
            .padding(.vertical, buttonPadding)
            .frame(maxWidth: .infinity)
            .background(Color.requestsBadgeBackground)
            .cornerRadius(cornerRadius)
            .onTapGesture(perform: action)
            .accessibilityLabel(accessibilityLabelValue)
            .accessibilityRemoveTraits(.isImage)
            .accessibilityAddTraits(.isButton)
    }
}
