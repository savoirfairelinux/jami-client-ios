/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import SwiftUI

struct ConversationProfileEditorAvatar: View {
    @ObservedObject var model: ConversationProfileEditorVM
    @Binding var showingOptions: Bool

    private enum Layout {
        static let avatarSize = Constants.AvatarSize.conversationInfo120.points
        static let badgeSize: CGFloat = 34
        static let badgeIconSize: CGFloat = 15
        static let badgeRingWidth: CGFloat = 2
        static let badgeInset: CGFloat = 2
        static let placeholderIconRatio: CGFloat = 0.5
    }

    var body: some View {
        Button(action: showOptions) {
            avatar
                .overlay(alignment: .bottomTrailing) {
                    badge
                }
        }
        .buttonStyle(AvatarPickerButtonStyle())
        .accessibilityLabel(L10n.ProfileEditor.changePicture)
        .accessibilityValue(model.avatar == nil ? L10n.ProfileEditor.noPicture
                                : L10n.ProfileEditor.pictureSelected)
        .accessibilityHint(L10n.ProfileEditor.changePictureHint)
    }

    private var avatar: some View {
        ZStack {
            if let image = model.avatar {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                noPicture
            }
        }
        .frame(width: Layout.avatarSize, height: Layout.avatarSize)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var noPicture: some View {
        ZStack {
            Color(UIColor.secondarySystemFill)
            Circle()
                .strokeBorder(Color(UIColor.separator), lineWidth: AvatarMetrics.borderWidth)
            Image(systemName: model.isSwarm ? "person.2.fill" : "person.fill")
                .font(.system(size: Layout.avatarSize * Layout.placeholderIconRatio, weight: .semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    private var badge: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: Layout.badgeIconSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: Layout.badgeSize, height: Layout.badgeSize)
            .background(Circle().fill(Color.jami))
            .overlay(
                Circle().strokeBorder(Color(UIColor.systemGroupedBackground),
                                      lineWidth: Layout.badgeRingWidth)
            )
            .padding(.trailing, Layout.badgeInset)
            .padding(.bottom, Layout.badgeInset)
            .accessibilityHidden(true)
    }

    private func showOptions() {
        hideKeyboard()
        showingOptions = true
    }
}

private struct AvatarPickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
