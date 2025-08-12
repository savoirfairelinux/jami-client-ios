/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import RxSwift

struct ActiveCallsView: View {
    @ObservedObject var viewModel: ActiveCallsViewModel
    @Environment(\.presentationMode)
    var presentationMode
    @SwiftUI.State private var isContentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if !(Array(viewModel.callsByAccount.keys).isEmpty) {
                ForEach(Array(viewModel.callsByAccount.keys), id: \.self) { accountId in
                    if let calls = viewModel.callsByAccount[accountId] {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(calls, id: \.call.id) { callViewModel in
                                CallRowView(viewModel: callViewModel)
                                    .transition(.move(edge: .top))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical)
                .background(
                    ZStack {
                        Color(UIColor.systemBackground)
                        VisualEffect(style: .systemChromeMaterial, withVibrancy: true)
                        Color(UIColor.systemGroupedBackground)
                    }
                )
                .cornerRadius(10)
                .shadow(radius: 5)
                .padding(.horizontal)
                .padding(.bottom)
                .offset(y: -40)
                .scaleEffect(isContentVisible ? 1 : 0.8)
            }
            Spacer()
        }
        .ignoresSafeArea()
        .background(Color.black.opacity(isContentVisible ? 0.5 : 0))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isContentVisible)
        .ignoresSafeArea()
        .onAppear {
            isContentVisible = true
        }
        .onChange(of: viewModel.callsByAccount) { accounts in
            if accounts.isEmpty || accounts.allSatisfy({ $0.value.isEmpty }) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct CallRowView: View {
    @ObservedObject var viewModel: ActiveCallRowViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let data = viewModel.avatarData {
                    // Leverage ProfilesService via a lightweight provider for proper sizing and cache reuse
                    AvatarSwiftUIView(
                        source: {
                            // Default to common size for active call rows
                            let provider = AvatarProvider(profileService: viewModel.profileService, size: 50)
                            provider.subscribeAvatar(observable: Observable.just(data))
                            provider.subscribeProfileName(observable: Observable.just(viewModel.title))
                            return provider
                        }()
                    )
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.title)
                        .font(.headline)
                    Text(L10n.Calls.activeCallLabel)
                }
            }
            .padding(.horizontal)

            HStack {
                Spacer()
                Button(action: {
                    viewModel.acceptCall()
                }, label: {
                    Image(systemName: "video")
                        .font(.system(size: 25))
                        .foregroundColor(.jamiColor)
                        .padding(10)
                })
                Spacer()
                Button(action: {
                    viewModel.acceptAudioCall()
                }, label: {
                    Image(systemName: "phone")
                        .font(.system(size: 25))
                        .foregroundColor(.jamiColor)
                        .padding(10)
                })
                Spacer()

                Button(action: {
                    viewModel.rejectCall()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 25))
                        .foregroundColor(.jamiColor)
                        .padding(10)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
