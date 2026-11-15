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
        static let headerPreviewGap: CGFloat = 12
        static let topScrimHeight: CGFloat = 190
        static let scrimOpacity: Double = 0.35
        static let scrimRamp: [Double] = [0, 0.16, 0.5, 0.84, 1]
    }

    private static let scrimGradient = Gradient(stops: Metrics.scrimRamp.enumerated().map { index, level in
        .init(color: .black.opacity(Metrics.scrimOpacity * level),
              location: CGFloat(index) / CGFloat(Metrics.scrimRamp.count - 1))
    })

    @ObservedObject var model: CallViewModel
    @SwiftUI.State private var bottomControlsHeight: CGFloat = 0

    private var chromeAnimation: Animation {
        .easeInOut(duration: Motion.chromeFadeDuration)
    }
    private var previewControlInsets: UIEdgeInsets {
        guard model.showsChrome else { return .zero }
        return UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: clearance(for: bottomControlsHeight),
            right: 0)
    }

    private func clearance(for measuredHeight: CGFloat) -> CGFloat {
        measuredHeight > 0 ? measuredHeight + Metrics.previewChromeGap : 0
    }

    var body: some View {
        ZStack {
            Color.jamiCallBackdrop.ignoresSafeArea()

            PiPSourceView(model: model)
                .ignoresSafeArea()

            ConferenceCanvasView(model: model,
                                 previewControlInsets: previewControlInsets,
                                 previewHeaderClearance: CallHeaderView.Metrics.height
                                    + Metrics.previewChromeGap)
                .ignoresSafeArea()
                .opacity(model.contentHidden ? 0 : 1)
                .allowsHitTesting(!model.contentHidden)

            scrims
        }
        .overlay(chrome)
        .statusBar(hidden: true)
        .sheet(isPresented: $model.showsDialpad) {
            InCallDialpadView(model: model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $model.showsMoreActions,
               onDismiss: model.moreActionsDismissed) {
            CallMoreActionsView(model: model)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $model.showsParticipants,
               onDismiss: model.participantsDismissed) {
            ConferenceParticipantsView(model: model)
                .optionalMediumPresentationDetents()
                .preferredColorScheme(.dark)
        }
        .onAppear { model.screenAppeared() }
        .onDisappear { model.screenDisappeared() }
    }

    private var chrome: some View {
        GeometryReader { geometry in
            VStack {
                if model.showsChrome {
                    HStack(spacing: CallHeaderView.Metrics.spacing) {
                        if let minimize = model.controlsPlan?.pictureInPicture {
                            CallMinimizeButton(action: minimize) {
                                model.perform(minimize.intent)
                            }
                        }
                        CallHeaderView(model: model)
                        if let raiseHand = model.controlsPlan?.raiseHand {
                            CallRaiseHandButton(action: raiseHand) {
                                model.perform(raiseHand.intent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, headerTrailingInset(in: geometry.size))
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

    private func headerTrailingInset(in size: CGSize) -> CGFloat {
        guard model.canvas.showsFloatingPreview else { return 0 }
        return Metrics.headerPreviewGap
            + CanvasLayout.previewSize(for: size).width * CanvasLayout.previewCompactScale
    }

    private var scrims: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if model.showsChrome {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black.opacity(0.42), location: 0),
                            .init(color: .black.opacity(0.18), location: 0.55),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom)
                        .frame(height: Metrics.topScrimHeight)
                        .transition(.opacity)
                    Spacer(minLength: 0)
                    let fade = bottomControlsHeight
                    LinearGradient(gradient: Self.scrimGradient, startPoint: .top, endPoint: .bottom)
                        .frame(height: geometry.safeAreaInsets.bottom + CanvasLayout.previewPadding
                                + clearance(for: bottomControlsHeight) + fade)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
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
