/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

private enum ExpandableAvatarLayout {
    static let expandedHeightFraction: CGFloat = 0.5
    static let blurRadius: CGFloat = 26
    static let blurStart: CGFloat = 0.5
    static let maxDecodePixels: CGFloat = 2048
}

struct ExpandableAvatar<BottomOverlay: View>: View {
    @ObservedObject var provider: AvatarProvider
    @ObservedObject private var screen = ScreenDimensionsManager.shared

    let isExpanded: Bool
    let isGroup: Bool
    let onToggle: () -> Void
    @ViewBuilder let bottomOverlay: BottomOverlay

    private var collapsedSide: CGFloat { provider.size.points }

    private var expandedSize: CGSize {
        CGSize(width: screen.adaptiveWidth,
               height: min(screen.adaptiveWidth,
                           screen.adaptiveHeight * ExpandableAvatarLayout.expandedHeightFraction))
    }

    private var size: CGSize {
        isExpanded ? expandedSize : CGSize(width: collapsedSide, height: collapsedSide)
    }

    private var cornerRadius: CGFloat { isExpanded ? 0 : collapsedSide / 2 }

    private var decodePixels: CGFloat {
        min(max(expandedSize.width, expandedSize.height) * UIScreen.main.scale,
            ExpandableAvatarLayout.maxDecodePixels)
    }

    private var label: String {
        isGroup ? L10n.Accessibility.swarmPicturePicker : L10n.Accessibility.profilePicturePicker
    }

    var body: some View {
        GeometryReader { proxy in
            avatar(stretchedBy: overscroll(in: proxy), width: proxy.size.width)
        }
        .frame(width: size.width, height: size.height)
        .onAppear(perform: loadExpandedAvatar)
        .onChange(of: isExpanded) { _ in
            loadExpandedAvatar()
        }
        .onChange(of: provider.avatar) { _ in
            loadExpandedAvatar()
        }
    }

    private func loadExpandedAvatar() {
        guard isExpanded else { return }
        provider.loadExpandedAvatar(maxPixels: decodePixels)
    }

    private func overscroll(in proxy: GeometryProxy) -> CGFloat {
        guard isExpanded else { return 0 }
        return max(0, proxy.frame(in: .global).minY)
    }

    private var picture: Image {
        Image(uiImage: provider.expandedAvatar ?? provider.avatar ?? UIImage())
    }

    private func styledPicture(width: CGFloat, height: CGFloat) -> some View {
        picture
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
    }

    private func blurredCopy(width: CGFloat, height: CGFloat) -> some View {
        styledPicture(width: width, height: height)
            .blur(radius: ExpandableAvatarLayout.blurRadius, opaque: true)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: ExpandableAvatarLayout.blurStart),
                        .init(color: .black, location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }

    private func avatar(stretchedBy stretch: CGFloat, width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            avatarButton(width: width, height: size.height + stretch)
            if isExpanded {
                bottomOverlay
            }
        }
        .frame(width: width, height: size.height + stretch)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .offset(y: -stretch)
    }

    private func avatarButton(width: CGFloat, height: CGFloat) -> some View {
        Button(action: onToggle) {
            styledPicture(width: width, height: height)
                .overlay {
                    if isExpanded {
                        blurredCopy(width: width, height: height)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(isExpanded ? L10n.Accessibility.avatarCollapseHint : L10n.Accessibility.avatarExpandHint)
    }
}
