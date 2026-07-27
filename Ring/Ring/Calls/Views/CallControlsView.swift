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
    let slots: CGFloat
    var pad: CGFloat { gap }

    static let compactSlotCount: CGFloat = 5
    static let minimumButton: CGFloat = 46
    static let minimumGap: CGFloat = 7

    init(availableWidth: CGFloat, slots: CGFloat = BarMetrics.compactSlotCount) {
        let slots = max(1, slots)
        self.slots = slots
        guard availableWidth > 0 else {
            self.button = Self.minimumButton
            self.gap = Self.minimumGap
            self.icon = (Self.minimumButton * 0.42).rounded()
            return
        }
        let spacing = max(Self.minimumGap, min(14, availableWidth * 0.033))
        let usable = availableWidth - (slots + 1) * spacing
        let preferred = max(Self.minimumButton, min(60, usable / slots))
        let button = min(preferred, availableWidth / slots)
        self.button = button
        self.gap = min(spacing, max(0, (availableWidth - slots * button) / (slots + 1)))
        self.icon = (button * 0.42).rounded()
    }

    var totalWidth: CGFloat {
        slots * button + (slots + 1) * gap
    }
}

private struct ControlsWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ControlIcon: View {
    let systemName: String
    var style: ControlAction.Style = .normal
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
    }

    private var foreground: Color {
        switch style {
        case .active: return Color(white: 0.09)
        case .destructive, .normal: return .white
        }
    }

    private var background: Color {
        switch style {
        case .destructive: return .red
        case .active: return .white.opacity(0.92)
        case .normal: return .white.opacity(0.16)
        }
    }
}

private struct ControlButton: View {
    let action: ControlAction
    let metrics: BarMetrics
    var overrideSystemName: String?
    var isHighlighted = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ControlIcon(systemName: overrideSystemName ?? action.systemImage,
                        style: isHighlighted ? .active : action.style,
                        size: metrics.button, iconSize: metrics.icon)
        }
        .disabled(!action.isEnabled)
        .opacity(action.isEnabled ? 1 : 0.4)
        .accessibilityLabel(action.accessibilityLabel)
    }
}

struct CallControlsView: View {

    @ObservedObject var model: CallViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.State private var availableWidth: CGFloat = 0

    private var plan: CallControlsLayout.Plan? {
        guard let controls = model.controls else { return nil }
        return CallControlsLayout.plan(.init(
                                        model: controls,
                                        speakerActive: model.speakerActive,
                                        canAddParticipant: model.canAddParticipant,
                                        canStartPictureInPicture: model.canStartPictureInPicture,
                                        isRegularWidth: horizontalSizeClass == .regular))
    }

    var body: some View {
        let plan = self.plan
        let metrics = BarMetrics(availableWidth: availableWidth,
                                 slots: CGFloat(plan?.primary.count
                                                    ?? Int(BarMetrics.compactSlotCount)))
        Group {
            if let plan = plan {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: metrics.gap) {
                        if model.moreExpanded, !plan.overflow.isEmpty {
                            overflowColumn(plan.overflow, metrics: metrics)
                                .transition(.scale(scale: 0.7, anchor: .bottomTrailing)
                                                .combined(with: .opacity))
                        }
                        primaryBar(plan.primary, metrics: metrics)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(GeometryReader { geo in
            Color.clear.preference(key: ControlsWidthKey.self, value: geo.size.width)
        })
        .onPreferenceChange(ControlsWidthKey.self) { availableWidth = $0 }
        .onChange(of: horizontalSizeClass) { newValue in
            if newValue == .regular { model.setMoreExpanded(false) }
        }
    }

    private func primaryBar(_ actions: [ControlAction], metrics: BarMetrics) -> some View {
        HStack(spacing: metrics.gap) {
            ForEach(actions) { action in
                if action.intent == .more {
                    ControlButton(action: action, metrics: metrics,
                                  overrideSystemName: model.moreExpanded ? "xmark" : action.systemImage,
                                  isHighlighted: model.moreExpanded) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.74)) {
                            model.toggleMoreExpanded()
                        }
                    }
                } else {
                    ControlButton(action: action, metrics: metrics) { dispatch(action.intent) }
                }
            }
        }
        .padding(metrics.pad)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }

    private func overflowColumn(_ actions: [ControlAction], metrics: BarMetrics) -> some View {
        VStack(spacing: metrics.gap) {
            ForEach(actions.reversed()) { action in
                ControlButton(action: action, metrics: metrics) {
                    dispatch(action.intent)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        model.setMoreExpanded(false)
                    }
                }
            }
        }
        .padding(metrics.pad)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }

    private func dispatch(_ intent: CallControlIntent) {
        model.registerChromeInteraction()
        switch intent {
        case .toggleMic: model.toggleMuteAudio()
        case .toggleCamera: model.toggleMuteVideo()
        case .toggleAudioOutput: model.toggleSpeaker()
        case .hangUp: model.hangUp()
        case .flipCamera: model.switchCamera()
        case .toggleHold: model.toggleHold()
        case .addParticipant: model.addParticipantTapped()
        case .startPictureInPicture: model.minimizeToPictureInPicture()
        case .showDialpad: model.showsDialpad = true
        case .more: break
        }
    }
}
