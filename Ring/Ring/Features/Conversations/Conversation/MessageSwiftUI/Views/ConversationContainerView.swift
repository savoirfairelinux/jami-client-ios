/*
 *  Copyright (C) 2024-2026 Savoir-faire Linux Inc.
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

    var body: some View {
        MessagesListView(model: viewModel.swiftUIModel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    conversationTitleView
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    trailingButtons
                }
            }
    }

    @ViewBuilder
    private var conversationTitleView: some View {
        if #available(iOS 26.0, *) {
           // GlassEffectContainer {
                Button(action: {
                    viewModel.showContactInfo()
                }) {
                    HStack(spacing: 15) {
                        AvatarSwiftUIView(source: viewModel.navBarAvatarProvider)
                            .frame(width: 30, height: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            if !viewModel.name.isEmpty {
                                Text(viewModel.name)
                                    .font(.body)
                                    .foregroundColor(Color(UIColor.jamiButtonDark))
                                    .lineLimit(1)
                            }
                            if !viewModel.navUserName.isEmpty,
                               viewModel.navUserName != viewModel.name {
                                Text(viewModel.navUserName)
                                    .font(.callout)
                                    .foregroundColor(Color(UIColor.jamiButtonDark))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding()
                    .glassEffect(in: .capsule)
                }
                //.glassEffect()
            //}
        } else {
            Button(action: {
                viewModel.showContactInfo()
            }) {
                HStack(spacing: 8) {
                    AvatarSwiftUIView(source: viewModel.avatarProvider)
                        .frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        if !viewModel.name.isEmpty {
                            Text(viewModel.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(UIColor.jamiButtonDark))
                                .lineLimit(1)
                        }
                        if !viewModel.navUserName.isEmpty,
                           viewModel.navUserName != viewModel.name {
                            Text(viewModel.navUserName)
                                .font(.system(size: 12))
                                .foregroundColor(Color(UIColor.jamiButtonDark))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        if !viewModel.navIsBlocked {
            Button {
                viewModel.startAudioCall()
            } label: {
                Asset.callButton.swiftUIImage
            }
            .accessibilityLabel(L10n.Accessibility.conversationStartVoiceCall(viewModel.name))

            if !viewModel.isAccountSip {
                Button {
                    viewModel.startCall()
                } label: {
                    Asset.videoRunning.swiftUIImage
                }
                .accessibilityLabel(L10n.Accessibility.conversationStartVideoCall(viewModel.name))
            }
        }
    }
}
