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
    @SwiftUI.State private var showPeerServices = false
    @SwiftUI.State private var peerSharingVM: PeerSharingViewModel?

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
            .navigationBarItems(leading: conversationTitleView, trailing: trailingButtons)
            .sheet(isPresented: $showPeerServices, onDismiss: {
                peerSharingVM?.closePeerSession()
                peerSharingVM = nil
            }) {
                if let peerVM = peerSharingVM {
                    PeerSharingSheet(viewModel: peerVM)
                }
            }
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
                //.frame(width: 30, height: 30)

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
            .frame(maxWidth: 120, alignment: .leading)
        }
    }

    // MARK: - Trailing Buttons

    @ViewBuilder private var trailingButtons: some View {
        HStack {
            if !viewModel.isBlocked {
                if viewModel.hasPeerSharing {
                    peerServicesButton
                }
                audioCallButton
                if !viewModel.isAccountSip {
                    videoCallButton
                }
            }
        }
    }

    private var peerServicesButton: some View {
        Button(action: {
            guard let peerVM = viewModel.makePeerSharingViewModel() else { return }
            peerSharingVM = peerVM
            showPeerServices = true
        }, label: {
            Image(systemName: "network")
                .navBarIconStyle()
        })
        .accessibilityLabel(L10n.PeerServices.title)
    }

    private var audioCallButton: some View {
        Button(action: viewModel.startAudioCall, label: {
            Image(systemName: "phone")
                .navBarIconStyle()
        })
        .accessibilityLabel(L10n.Accessibility.conversationStartVoiceCall(viewModel.name))
    }

    private var videoCallButton: some View {
        Button(action: viewModel.startCall, label: {
            Image(systemName: "video")
                .navBarIconStyle()
        })
        .accessibilityLabel(L10n.Accessibility.conversationStartVideoCall(viewModel.name))
    }
}
