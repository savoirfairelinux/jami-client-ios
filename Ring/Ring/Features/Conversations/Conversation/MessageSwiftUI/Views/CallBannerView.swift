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

    var body: some View {
        if viewModel.isVisible {
            VStack(spacing: 0) {
                ForEach(viewModel.activeCalls, id: \.id) { call in
                    VStack(spacing: 12) {

                        Text(L10n.Calls.activeCallLabel)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Button(action: {
                                viewModel.acceptVideoCall(for: call)
                            }) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.jamiColor)
                                    .padding(.horizontal)
                            }

                            Button(action: {
                                viewModel.acceptAudioCall(for: call)
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.jamiColor)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(10)
            .shadow(radius: 5)
        }
    }
}
