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
    @ObservedObject var peerSharing: PeerSharingTracker
    @StateObject private var mediaPreviewPresenter = MediaPreviewPresenter()

    private var titleMaxWidth: CGFloat {
        ConversationNavBarLayout.titleMaxWidth(
            barContentWidth: viewModel.navBarContentWidth,
            trailingButtonCount: ConversationTrailingButton.visible(viewModel: viewModel,
                                                                    peerSharing: peerSharing).count,
            reservesWindowControls: viewModel.navBarReservesWindowControls,
            hasBackButton: viewModel.navBarHasBackButton
        )
    }

    private var peerSharingSheet: Binding<PeerSharingViewModel?> {
        Binding(get: { viewModel.peerSharingSheet },
                set: { presented in
                    if presented == nil {
                        viewModel.peerSharingSheet?.closePeerSession()
                    }
                    viewModel.peerSharingSheet = presented
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

enum ConversationTrailingButton: Hashable {
    case peerSharing
    case audioCall
    case videoCall

    static func visible(isBlocked: Bool,
                        canStartCalls: Bool,
                        hasPeerSharing: Bool,
                        isAccountSip: Bool) -> [ConversationTrailingButton] {
        guard !isBlocked else { return [] }
        var buttons: [ConversationTrailingButton] = []
        if hasPeerSharing { buttons.append(.peerSharing) }
        guard canStartCalls else { return buttons }
        buttons.append(.audioCall)
        if !isAccountSip { buttons.append(.videoCall) }
        return buttons
    }

    static func visible(viewModel: ConversationViewModel,
                        peerSharing: PeerSharingTracker) -> [ConversationTrailingButton] {
        return visible(isBlocked: viewModel.isBlocked,
                       canStartCalls: viewModel.canStartCalls,
                       hasPeerSharing: peerSharing.hasPeerSharing,
                       isAccountSip: viewModel.isAccountSip)
    }
}

struct ConversationTrailingBarItems: View {
    @ObservedObject var viewModel: ConversationViewModel
    @ObservedObject var peerSharing: PeerSharingTracker

    var body: some View {
        let buttons = ConversationTrailingButton.visible(viewModel: viewModel, peerSharing: peerSharing)
        NavBarButtonGroup {
            if buttons.contains(.peerSharing) {
                NavBarIconButton(systemName: "network",
                                 accessibilityLabel: L10n.PeerServices.title,
                                 accessibilityIdentifier: ConversationAccessibilityIdentifiers.peerServicesButton) {
                    viewModel.peerSharingSheet = peerSharing.makePeerSharingViewModel()
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
