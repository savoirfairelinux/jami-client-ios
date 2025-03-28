/*
 *  Copyright (C) 2025 - 2025 Savoir-faire Linux Inc.
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

struct CallBannerView: View {
    @ObservedObject var viewModel: CallBannerViewModel
    @SwiftUI.State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.activeCalls, id: \.id) { call in
                VStack(spacing: 12) {
                    Text(L10n.Calls.activeCallInConversation)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.acceptVideoCall(for: call)
                        }, label: {
                            Image(systemName: "video")
                                .font(.system(size: 25))
                                .foregroundColor(.jamiColor)
                                .padding(.horizontal)
                        })

                        Button(action: {
                            viewModel.acceptAudioCall(for: call)
                        }, label: {
                            Image(systemName: "phone")
                                .font(.system(size: 25))
                                .foregroundColor(.jamiColor)
                                .padding(.horizontal)
                        })
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            ZStack {
                Color(UIColor.systemBackground)
                VisualEffect(style: .systemChromeMaterial, withVibrancy: true)
                Color(UIColor.secondarySystemBackground)
                    .opacity(isAnimating ? 0.1 : 1.0)
            }
        )
        .shadow(color: Color(UIColor.tertiarySystemBackground).opacity(0.8), radius: 1, y: 2)
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
    }
}
