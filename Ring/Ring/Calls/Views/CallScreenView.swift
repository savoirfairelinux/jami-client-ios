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

            Group {
                ConferenceCanvasView(model: model)
                    .ignoresSafeArea()

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

}

struct CallHeaderView: View {

    @ObservedObject var model: CallViewModel

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(model.title)
                    .font(.headline)
                    .foregroundColor(.white)
                if model.peerIsRecording {
                    Image(systemName: "record.circle")
                        .foregroundColor(.red)
                }
                if model.hasParticipantList {
                    Image(systemName: "person.2.fill")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(model.participantCount)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            Text(model.statusText.isEmpty ? model.durationText : model.statusText)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            if model.hasParticipantList { model.showsParticipants = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(model.hasParticipantList ? .isButton : [])
        .accessibilityHint(model.hasParticipantList ? L10n.Accessibility.Conference.showParticipants : "")
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
