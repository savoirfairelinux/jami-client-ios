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
        static let glyph: CGFloat = 24
        static let glyphSpacing: CGFloat = 14
        static let topPadding: CGFloat = 20
        static let bottomPadding: CGFloat = 8

        static let textLeading = margin + glyph + glyphSpacing
    }

    @ObservedObject var model: CallViewModel

    var body: some View {
        let actions = model.controlsPlan?.more ?? []
        VStack(spacing: 0) {
            ForEach(actions) { action in
                row(action)
                if action.id != actions.last?.id {
                    Divider()
                        .padding(.leading, Metrics.textLeading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Metrics.topPadding)
        .fittedSheetHeight(Metrics.topPadding + Metrics.bottomPadding
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
            .accessibilityLabel(action.title)
        } else {
            rowInsets(Button {
                model.selectMoreAction(action.intent)
            } label: {
                label(action)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle()))
            .disabled(!action.isEnabled)
            .accessibilityLabel(action.title)
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
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .accessibilityHidden(true)
            Text(action.title)
                .font(.body)
        }
        .foregroundColor(.primary)
    }
}

private extension View {
    @ViewBuilder
    func fittedSheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(UIColor.jamiCallCanvas))
        } else if #available(iOS 16.0, *) {
            presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .background(Color(UIColor.jamiCallCanvas).ignoresSafeArea())
        } else {
            background(Color(UIColor.jamiCallCanvas).ignoresSafeArea())
        }
    }
}
