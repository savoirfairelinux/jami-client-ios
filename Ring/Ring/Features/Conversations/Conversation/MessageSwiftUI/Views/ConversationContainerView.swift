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

struct ConversationContainerView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @StateObject private var mediaPreviewOverlayState = MediaPreviewState()
    @SwiftUI.State private var containerWidth: CGFloat = 0

    var body: some View {
        MessagesListView(model: viewModel.swiftUIModel)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { containerWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { newWidth in
                            containerWidth = newWidth
                        }
                }
            )
            .onAppear {
                viewModel.swiftUIModel.mediaPreviewOverlayState = mediaPreviewOverlayState
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    conversationTitleView
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    trailingButtons
                }
            }
    }

    // MARK: - Title View

    @ViewBuilder
    private var conversationTitleView: some View {
        Button(action: viewModel.showContactInfo) {
            titleViewContent
        }
    }

    private var titleViewContent: some View {
        HStack(spacing: 8) {
            AvatarSwiftUIView(source: viewModel.navBarAvatarProvider)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                if !viewModel.name.isEmpty {
                    Text(viewModel.name)
                        .bold()
                        .foregroundColor(Color(UIColor.jamiButtonDark))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if !viewModel.navUserName.isEmpty,
                   viewModel.navUserName != viewModel.name {
                    Text(viewModel.navUserName)
                        .font(.footnote)
                        .foregroundColor(Color(UIColor.jamiButtonDark))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: titleMaxWidth, alignment: .leading)
        }
    }

    // MARK: - Trailing Buttons

    @ViewBuilder
    private var trailingButtons: some View {
        if !viewModel.isBlocked {
            audioCallButton
            if !viewModel.isAccountSip {
                videoCallButton
            }
        }
    }

    private var audioCallButton: some View {
        Button(action: viewModel.startAudioCall) {
            Asset.callButton.swiftUIImage
        }
        .foregroundColor(Color(UIColor.jamiButtonDark))
        .accessibilityLabel(L10n.Accessibility.conversationStartVoiceCall(viewModel.name))
    }

    private var videoCallButton: some View {
        Button(action: viewModel.startCall) {
            Asset.videoRunning.swiftUIImage
        }
        .foregroundColor(Color(UIColor.jamiButtonDark))
        .accessibilityLabel(L10n.Accessibility.conversationStartVideoCall(viewModel.name))
    }

    // MARK: - Helpers

    private var titleMaxWidth: CGFloat {
        let backButtonReserve: CGFloat = 60
        let sidePaddingReserve: CGFloat = 30
        let trailingButtonReserve: CGFloat = 60
        let avatarWidthReserve: CGFloat = 30 + 8
        let trailingCount = viewModel.isBlocked ? 0 : (viewModel.isAccountSip ? 1 : 2)

        let totalReserved = backButtonReserve + (sidePaddingReserve * 2) +
            (trailingButtonReserve * CGFloat(trailingCount)) + avatarWidthReserve

        return max(0, containerWidth - totalReserved)
    }
}
