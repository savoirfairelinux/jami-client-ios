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
    @StateObject private var mediaPreviewPresenter = MediaPreviewPresenter()

    private var titleMaxWidth: CGFloat {
        ConversationNavBarLayout.titleMaxWidth(
            barContentWidth: viewModel.navBarContentWidth,
            trailingButtonCount: viewModel.trailingButtons.count,
            reservesWindowControls: viewModel.navBarReservesWindowControls,
            hasBackButton: viewModel.navBarHasBackButton
        )
    }

    private var peerSharingSheet: Binding<PeerSharingViewModel?> {
        Binding(get: { viewModel.peerSharingSheet },
                set: { presented in
                    if presented == nil {
                        viewModel.dismissPeerSharing()
                    }
                })
    }

    var body: some View {
        MessagesListView(model: viewModel.swiftUIModel)
            .onPreferenceChange(MessagePanelTopPreferenceKey.self) { value in
                if let top = value {
                    mediaPreviewPresenter.messagePanelTopY = top
                    viewModel.swiftUIModel.messagePanelTopY = top
                }
            }
            .onAppear {
                let presenter = mediaPreviewPresenter
                viewModel.swiftUIModel.actionHandler.presentMediaPreview = { [weak presenter] model, frame, provider in
                    presenter?.present(model: model, sourceFrame: frame, sourceFrameProvider: provider)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: conversationTitleView)
            .sheet(item: peerSharingSheet) { peerVM in
                PeerSharingSheet(viewModel: peerVM)
            }
    }

    // MARK: - Title View

    @ViewBuilder private var conversationTitleView: some View {
        Button(action: viewModel.showContactInfo) {
            titleViewContent
        }
    }

    private var titleViewContent: some View {
        HStack(spacing: ConversationNavBarLayout.avatarSpacing) {
            AvatarSwiftUIView(source: viewModel.navBarAvatarProvider)
                .frame(width: ConversationNavBarLayout.avatarSize,
                       height: ConversationNavBarLayout.avatarSize)

            VStack(alignment: .leading, spacing: 0) {
                if !viewModel.name.isEmpty {
                    Text(viewModel.name)
                        .bold()
                        .foregroundColor(.jami)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if !viewModel.navUserName.isEmpty,
                   viewModel.navUserName != viewModel.name {
                    Text(viewModel.navUserName)
                        .font(.footnote)
                        .foregroundColor(.jami)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: titleMaxWidth, alignment: .leading)
        }
    }
}

struct ConversationTrailingBarItems: View {
    @ObservedObject var viewModel: ConversationViewModel

    var body: some View {
        let buttons = viewModel.trailingButtons
        NavBarButtonGroup {
            if buttons.contains(.peerSharing) {
                NavBarIconButton(systemName: "network",
                                 accessibilityLabel: L10n.PeerServices.title,
                                 accessibilityIdentifier: ConversationAccessibilityIdentifiers.peerServicesButton) {
                    viewModel.openPeerSharing()
                }
            }
            if buttons.contains(.audioCall) {
                NavBarIconButton(systemName: "phone",
                                 accessibilityLabel: L10n.Accessibility.conversationStartVoiceCall(viewModel.name),
                                 accessibilityIdentifier: ConversationAccessibilityIdentifiers.audioCallButton,
                                 action: viewModel.startAudioCall)
            }
            if buttons.contains(.videoCall) {
                NavBarIconButton(systemName: "video",
                                 accessibilityLabel: L10n.Accessibility.conversationStartVideoCall(viewModel.name),
                                 accessibilityIdentifier: ConversationAccessibilityIdentifiers.videoCallButton,
                                 action: viewModel.startCall)
            }
        }
    }
}
