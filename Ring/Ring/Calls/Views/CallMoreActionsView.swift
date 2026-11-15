/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

struct CallMoreActionsView: View {

    private enum Metrics {
        static let margin: CGFloat = 20
        static let rowHeight: CGFloat = 52
        static let glyphSpacing: CGFloat = 14
        static let grabberClearance: CGFloat = 10
        static let verticalInset: CGFloat = 8

        static let topPadding = grabberClearance + verticalInset
        static let bottomPadding = verticalInset
    }

    @ObservedObject var model: CallViewModel
    @SwiftUI.State private var contentHeight: CGFloat?
    @ScaledMetric(relativeTo: .body)
    private var glyph: CGFloat = 24

    private var textLeading: CGFloat { Metrics.margin + glyph + Metrics.glyphSpacing }

    var body: some View {
        let actions = model.controlsPlan?.more ?? []
        ScrollView {
            VStack(spacing: 0) {
                ForEach(actions) { action in
                    row(action)
                    if action.id != actions.last?.id {
                        Divider()
                            .padding(.leading, textLeading)
                    }
                }
            }
            .padding(.top, Metrics.topPadding)
            .padding(.bottom, Metrics.bottomPadding)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
            })
        }
        .onPreferenceChange(ContentHeightKey.self) { height in
            if height > 0, height != contentHeight { contentHeight = height }
        }
        .fittedSheetHeight(contentHeight ?? Metrics.topPadding + Metrics.bottomPadding
                            + CGFloat(actions.count) * Metrics.rowHeight)
    }

    @ViewBuilder
    private func row(_ action: ControlAction) -> some View {
        if let isOn = action.isOn {
            rowInsets(Toggle(isOn: Binding(get: { isOn },
                                           set: { _ in model.perform(action.intent) })) {
                label(action)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.jami)))
            .disabled(!action.isEnabled)
        } else {
            Button {
                model.selectMoreAction(action.intent)
            } label: {
                rowInsets(label(action)
                            .frame(maxWidth: .infinity, alignment: .leading))
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!action.isEnabled)
        }
    }

    private func rowInsets<Content: View>(_ content: Content) -> some View {
        content
            .padding(.horizontal, Metrics.margin)
            .frame(minHeight: Metrics.rowHeight)
    }

    private func label(_ action: ControlAction) -> some View {
        HStack(spacing: Metrics.glyphSpacing) {
            Image(systemName: action.systemImage)
                .font(.body)
                .frame(width: glyph, height: glyph)
                .accessibilityHidden(true)
            Text(action.accessibilityLabel)
                .font(.body)
        }
        .foregroundColor(.primary)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    @ViewBuilder
    func fittedSheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(UIColor.jamiCallCanvas))
                .scrollBounceBehavior(.basedOnSize)
        } else if #available(iOS 16.0, *) {
            presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .background(Color(UIColor.jamiCallCanvas).ignoresSafeArea())
        } else {
            background(Color(UIColor.jamiCallCanvas).ignoresSafeArea())
        }
    }
}
