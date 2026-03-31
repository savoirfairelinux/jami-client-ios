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
#if DEBUG_TOOLS_ENABLED
import DebugTools
#endif

struct ConversationContainerView: View {
    @ObservedObject var viewModel: ConversationViewModel
    @StateObject private var mediaPreviewPresenter = MediaPreviewPresenter()
    @SwiftUI.State private var containerWidth: CGFloat = UIScreen.main.bounds.width

    #if DEBUG_TOOLS_ENABLED
    @SwiftUI.State private var showDebugTools: Bool = false
    #endif

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
            .onPreferenceChange(MessagePanelTopPreferenceKey.self) { value in
                if let top = value {
                    mediaPreviewPresenter.messagePanelTopY = top
                }
            }
            .onAppear {
                let presenter = mediaPreviewPresenter
                viewModel.swiftUIModel.actionHandler.presentMediaPreview = { [weak presenter] model, frame, provider in
                    presenter?.present(model: model, sourceFrame: frame, sourceFrameProvider: provider)
                }
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
            #if DEBUG_TOOLS_ENABLED
            .sheet(isPresented: $showDebugTools) {
                debugToolsSheet
            }
            #endif
    }

    // MARK: - Title View

    @ViewBuilder private var conversationTitleView: some View {
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

    @ViewBuilder private var trailingButtons: some View {
        if !viewModel.isBlocked {
            #if DEBUG_TOOLS_ENABLED
            debugToolsButton
            #endif
            audioCallButton
            if !viewModel.isAccountSip {
                videoCallButton
            }
        }
    }

    #if DEBUG_TOOLS_ENABLED
    private var debugToolsButton: some View {
        Button(action: { showDebugTools = true }) {
            Image(systemName: "ladybug.fill")
        }
        .foregroundColor(.purple)
    }

    @ViewBuilder private var debugToolsSheet: some View {
        if let conversation = viewModel.conversation {
            NotificationTestingConfigView(
                conversationId: conversation.id,
                accountId: conversation.accountId,
                send: viewModel.makeDebugToolsSendClosure()
            )
        }
    }
    #endif

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
