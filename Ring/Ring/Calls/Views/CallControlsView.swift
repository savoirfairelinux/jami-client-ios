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
    static let preferredButton: CGFloat = 50
    static let gapRatio: CGFloat = 0.26
    static let iconRatio: CGFloat = 0.35

    init(availableWidth: CGFloat, buttonCount: Int) {
        let rowUnits = CGFloat(buttonCount) + CGFloat(max(0, buttonCount - 1)) * Self.gapRatio
        let fitting = availableWidth > 0 && rowUnits > 0
            ? (availableWidth / rowUnits).rounded(.down)
            : Self.preferredButton
        let button = max(Self.minimumButton, min(Self.preferredButton, fitting))
        self.button = button
        self.gap = (button * Self.gapRatio).rounded(.down)
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
    var restingFill: Color = .jamiCallControl

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
        guard isEnabled else { return restingFill }
        switch style {
        case .destructive: return .red
        case .active: return .white.opacity(0.92)
        case .normal: return restingFill
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
                            metrics: metrics, restingFill: .clear)
                .callGlass(Circle())
        }
        .accessibilityLabel(L10n.Calls.moreOptions)
    }
}

struct CallControlsView: View {

    @ObservedObject var model: CallViewModel
    let availableWidth: CGFloat

    var body: some View {
        Group {
            if let plan = model.controlsPlan {
                let metrics = BarMetrics(availableWidth: availableWidth,
                                         buttonCount: plan.primary.count + 1)
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
