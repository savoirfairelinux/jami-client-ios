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

private protocol MeasuredHeightKey: PreferenceKey where Value == CGFloat {}

extension MeasuredHeightKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TopActionsHeightKey: MeasuredHeightKey {}
private struct BottomControlsHeightKey: MeasuredHeightKey {}

private extension View {
    func measuringHeight<Key: MeasuredHeightKey>(_ key: Key.Type,
                                                 into height: Binding<CGFloat>) -> some View {
        background(GeometryReader { geometry in
            Color.clear.preference(key: key, value: geometry.size.height)
        })
        .onPreferenceChange(key) { measured in
            if height.wrappedValue != measured { height.wrappedValue = measured }
        }
    }
}

struct CallScreenView: View {

    enum Motion {
        static let chromeFadeDuration: TimeInterval = 0.3
    }

    private enum Metrics {
        static let previewChromeGap: CGFloat = 8
    }

    @ObservedObject var model: CallViewModel
    @SwiftUI.State private var topActionsHeight: CGFloat = 0
    @SwiftUI.State private var bottomControlsHeight: CGFloat = 0

    private var chromeAnimation: Animation {
        .easeInOut(duration: Motion.chromeFadeDuration)
    }
    private var previewControlInsets: UIEdgeInsets {
        guard model.showsChrome else { return .zero }
        return UIEdgeInsets(
            top: clearance(for: topActionsHeight),
            left: 0,
            bottom: clearance(for: bottomControlsHeight),
            right: 0)
    }

    private func clearance(for measuredHeight: CGFloat) -> CGFloat {
        measuredHeight > 0 ? measuredHeight + Metrics.previewChromeGap : 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PiPSourceView(model: model)
                .ignoresSafeArea()

            ConferenceCanvasView(model: model,
                                 previewControlInsets: previewControlInsets)
                .ignoresSafeArea()
                .opacity(model.contentHidden ? 0 : 1)
                .allowsHitTesting(!model.contentHidden)
        }
        .overlay(chrome)
        .statusBar(hidden: true)
        .sheet(isPresented: $model.showsDialpad) {
            InCallDialpadView(model: model)
        }
        .sheet(isPresented: $model.showsParticipants,
               onDismiss: model.participantsDismissed) {
            ConferenceParticipantsView(model: model)
                .optionalMediumPresentationDetents()
        }
        .onAppear { model.screenAppeared() }
        .onDisappear { model.screenDisappeared() }
    }

    private var chrome: some View {
        GeometryReader { geometry in
            VStack {
                if model.showsChrome {
                    CallTopActionsView(model: model, availableWidth: geometry.size.width)
                        .measuringHeight(TopActionsHeightKey.self,
                                         into: $topActionsHeight)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if model.showsChrome {
                    CallControlsView(model: model, availableWidth: geometry.size.width)
                        .measuringHeight(BottomControlsHeightKey.self,
                                         into: $bottomControlsHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding()
        .allowsHitTesting(model.showsChrome)
        .animation(chromeAnimation, value: model.showsChrome)
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
