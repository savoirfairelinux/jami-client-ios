/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

struct CallScreenView: View {

    @ObservedObject var model: CallViewModel

    private var chromeAnimation: Animation { .easeInOut(duration: 0.3) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PiPSourceView(model: model)
                .ignoresSafeArea()

            ConferenceCanvasView(model: model)
                .ignoresSafeArea()
                .opacity(model.contentHidden ? 0 : 1)
                .allowsHitTesting(!model.contentHidden)
        }
        .overlay(chrome)
        .statusBar(hidden: true)
        .sheet(isPresented: $model.showsDialpad) {
            InCallDialpadView(model: model)
        }
        .sheet(isPresented: $model.showsParticipants) {
            ConferenceParticipantsView(model: model)
                .optionalMediumPresentationDetents()
        }
        .onAppear { model.screenAppeared() }
        .onDisappear { model.screenDisappeared() }
    }

    @ViewBuilder
    private var chrome: some View {
        ZStack {
            if model.moreExpanded {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            model.setMoreExpanded(false)
                        }
                    }
            }

            VStack {
                CallHeaderView(model: model)
                Spacer()
                CallControlsView(model: model)
                    .padding(.bottom, 12)
            }
            .padding()
            .opacity(model.chromeVisible ? 1 : 0)
            .allowsHitTesting(model.chromeVisible)
            .animation(chromeAnimation, value: model.chromeVisible)
        }
        .opacity(model.contentHidden ? 0 : 1)
        .allowsHitTesting(!model.contentHidden)
    }
}

struct InCallDialpadView: View {

    @ObservedObject var model: CallViewModel

    private let keys = [["1", "2", "3"], ["4", "5", "6"],
                        ["7", "8", "9"], ["*", "0", "#"]]

    var body: some View {
        VStack(spacing: 18) {
            Indicator(orientation: .horizontal)
                .padding(.top, 10)
            Spacer()
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            model.playDTMF(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 30, weight: .medium))
                                .frame(width: 72, height: 72)
                                .background(Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            Spacer()
        }
    }
}
