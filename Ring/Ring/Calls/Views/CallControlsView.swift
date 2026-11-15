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

struct BarMetrics {
    let button: CGFloat
    let icon: CGFloat
    let gap: CGFloat

    static let minimumButton: CGFloat = 44
    static let maximumButton: CGFloat = 64
    static let widthRatio: CGFloat = 0.142
    static let gapRatio: CGFloat = 0.26
    static let iconRatio: CGFloat = 0.35

    init(availableWidth: CGFloat) {
        let button = availableWidth > 0
            ? min(Self.maximumButton,
                  max(Self.minimumButton, (availableWidth * Self.widthRatio).rounded(.down)))
            : Self.minimumButton
        self.button = button
        self.gap = (button * Self.gapRatio).rounded()
        self.icon = (button * Self.iconRatio).rounded()
    }

    func rowWidth(for actions: [ControlAction]) -> CGFloat {
        CGFloat(actions.count) * button + CGFloat(max(0, actions.count - 1)) * gap
    }
}

struct CallControlIcon: View {
    let systemImage: String
    let style: ControlAction.Style
    let isEnabled: Bool
    let metrics: BarMetrics

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: metrics.icon, weight: .medium))
            .foregroundColor(foreground)
            .frame(width: metrics.button, height: metrics.button)
            .onVideoFill(Circle(), color: background)
    }

    private var foreground: Color {
        guard isEnabled else { return .white.opacity(0.46) }
        switch style {
        case .active: return Color(white: 0.09)
        case .destructive, .normal: return .white
        }
    }

    private var background: Color {
        guard isEnabled else { return .jamiCallControl }
        switch style {
        case .destructive: return .red
        case .active: return .white.opacity(0.92)
        case .normal: return .jamiCallControl
        }
    }
}

private struct ControlButton: View {
    let action: ControlAction
    let metrics: BarMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CallControlIcon(systemImage: action.systemImage, style: action.style,
                            isEnabled: action.isEnabled, metrics: metrics)
        }
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
    }
}

private struct MoreActionsButton: View {
    let metrics: BarMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CallControlIcon(systemImage: "ellipsis", style: .normal, isEnabled: true,
                            metrics: metrics)
        }
        .accessibilityLabel(L10n.Calls.moreOptions)
    }
}

struct CallControlsView: View {

    @ObservedObject var model: CallViewModel
    let availableWidth: CGFloat

    var body: some View {
        let metrics = BarMetrics(availableWidth: availableWidth)
        Group {
            if let plan = model.controlsPlan {
                HStack(spacing: metrics.gap) {
                    MoreActionsButton(metrics: metrics) {
                        model.showsMoreActions = true
                    }
                    ForEach(plan.primary) { action in
                        ControlButton(action: action, metrics: metrics) {
                            model.perform(action.intent)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
