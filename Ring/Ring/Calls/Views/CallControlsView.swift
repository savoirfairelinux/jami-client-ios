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
    let horizontalPadding: CGFloat
    private let slotCount: CGFloat
    var contentInset: CGFloat { (button - icon) / 2 }

    static let compactSlotCount: CGFloat = 5
    static let minimumButton: CGFloat = 46
    static let maximumButton: CGFloat = 54
    static let minimumGap: CGFloat = 7
    static let maximumGap: CGFloat = 12
    static let iconRatio: CGFloat = 0.38

    init(availableWidth: CGFloat, slots: CGFloat = BarMetrics.compactSlotCount) {
        let slots = max(1, slots)
        self.slotCount = slots
        guard availableWidth > 0 else {
            let icon = (Self.minimumButton * Self.iconRatio).rounded()
            self.button = Self.minimumButton
            self.gap = Self.minimumGap
            self.icon = icon
            self.horizontalPadding = (Self.minimumButton - icon) / 2
            return
        }
        let interButtonSlots = max(0, slots - 1)
        let reservedGaps = interButtonSlots * Self.minimumGap
        let outerInsetShare = 1 - Self.iconRatio
        let fittingButton = (availableWidth - reservedGaps) / (slots + outerInsetShare)
        let preferred = max(
            Self.minimumButton,
            min(Self.maximumButton, fittingButton))
        let button = min(preferred, availableWidth / slots)
        self.button = button
        let icon = (button * Self.iconRatio).rounded()
        self.icon = icon
        let desiredHorizontalPadding = (button - icon) / 2
        let availableHorizontalPadding = max(0, (availableWidth - slots * button) / 2)
        let horizontalPadding = min(desiredHorizontalPadding, availableHorizontalPadding)
        self.horizontalPadding = horizontalPadding
        let availableGap = interButtonSlots > 0
            ? max(0, (availableWidth - slots * button - 2 * horizontalPadding)
                    / interButtonSlots)
            : 0
        self.gap = min(Self.maximumGap, availableGap)
    }

    init(availableWidth: CGFloat, plan: CallControlsLayout.Plan?) {
        self.init(availableWidth: availableWidth,
                  slots: plan.map { CGFloat($0.primary.count) }
                    ?? BarMetrics.compactSlotCount)
    }

    var totalWidth: CGFloat {
        slotCount * button + max(0, slotCount - 1) * gap + 2 * horizontalPadding
    }
}

struct CallControlIcon: View {
    let action: ControlAction
    let metrics: BarMetrics

    var body: some View {
        Image(systemName: action.systemImage)
            .font(.system(size: metrics.icon, weight: .medium))
            .foregroundColor(foreground)
            .frame(width: metrics.button, height: metrics.button)
            .onVideoGlass(Circle(), tint: background)
    }

    private var foreground: Color {
        guard action.isEnabled else { return .white.opacity(0.46) }
        switch action.style {
        case .active: return Color(white: 0.09)
        case .destructive, .normal: return .white
        }
    }

    private var background: Color {
        guard action.isEnabled else { return Color.jamiOnVideoGlass.opacity(0.75) }
        switch action.style {
        case .destructive: return .red
        case .active: return .white.opacity(0.92)
        case .normal: return Color.jamiOnVideoGlass
        }
    }
}

private struct ControlButton: View {
    let action: ControlAction
    let metrics: BarMetrics
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CallControlIcon(action: action, metrics: metrics)
        }
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
    }
}

struct CallControlsView: View {

    @ObservedObject var model: CallViewModel
    let availableWidth: CGFloat

    var body: some View {
        let plan = model.controlsPlan
        let metrics = BarMetrics(availableWidth: availableWidth, plan: plan)
        Group {
            if let plan = plan {
                VStack(spacing: metrics.gap) {
                    if !plan.supplemental.isEmpty {
                        controlBar(plan.supplemental, metrics: metrics)
                    }
                    controlBar(plan.primary, metrics: metrics)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlBar(_ actions: [ControlAction],
                            metrics: BarMetrics) -> some View {
        HStack(spacing: metrics.gap) {
            ForEach(actions) { action in
                ControlButton(action: action, metrics: metrics) {
                    model.perform(action.intent)
                }
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
    }
}
