/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

private enum VoiceRecordingLayout {
    static let controlSize: CGFloat = 44
    static let holdingScale: CGFloat = 1.45
    static let cancelDistance: CGFloat = 110
    static let lockDistance: CGFloat = 70
    static let tapDuration: TimeInterval = 0.25
    static let tapMovement: CGFloat = 6
    static let panelCornerRadius: CGFloat = 22
    static let previewHeight: CGFloat = 56
}

private func formattedDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}

private func impact() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
}

// MARK: - Record button and holding row

struct VoiceRecordControls: View {
    @ObservedObject var model: VoiceRecordingVM
    let accentColor: Color
    let idleColor: Color
    let size: CGFloat

    @Environment(\.layoutDirection)
    private var layoutDirection
    @SwiftUI.State private var pressStart: Date?
    @SwiftUI.State private var translation: CGSize = .zero

    private var isHolding: Bool {
        model.state == .holding
    }

    private var cancelOffset: CGFloat {
        layoutDirection == .leftToRight ? min(0, translation.width) : max(0, translation.width)
    }

    private var lockOffset: CGFloat {
        max(-VoiceRecordingLayout.lockDistance, min(0, translation.height))
    }

    private var cancelProgress: CGFloat {
        min(1, abs(cancelOffset) / VoiceRecordingLayout.cancelDistance)
    }

    var body: some View {
        HStack(spacing: 10) {
            if isHolding {
                holdingRow
            }
            ZStack(alignment: .bottom) {
                if isHolding {
                    lockIndicator
                        .offset(y: -(size + 16) + lockOffset * 0.5)
                }
                recordButton
            }
        }
    }

    private var holdingRow: some View {
        HStack(spacing: 10) {
            RecordingDot()
            Text(formattedDuration(model.elapsed))
                .font(.body.monospacedDigit())
                .fontWeight(.semibold)
            Spacer(minLength: 0)
            Label(L10n.Conversation.voiceMessageSlideToCancel, systemImage: "chevron.backward")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(1)
                .opacity(Double(1 - cancelProgress))
                .offset(x: cancelOffset * 0.6)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, minHeight: VoiceRecordingLayout.controlSize)
    }

    private var lockIndicator: some View {
        let armed = lockOffset <= -VoiceRecordingLayout.lockDistance * 0.6
        return VStack(spacing: 4) {
            Image(systemName: "lock")
            Image(systemName: "chevron.up")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(armed ? .white : Color(UIColor.secondaryLabel))
        .frame(width: 36, height: 76)
        .background(Capsule().fill(armed ? accentColor : Color(UIColor.secondarySystemBackground)))
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
        .accessibilityHidden(true)
    }

    private var recordButton: some View {
        let cancelArmed = cancelProgress >= 0.6
        return Image(systemName: "mic")
            .font(.system(size: 22, weight: isHolding ? .regular : .light))
            .foregroundColor(isHolding ? .white : idleColor)
            .frame(width: size, height: size)
            .background(Circle().fill(isHolding ? (cancelArmed ? Color(UIColor.systemRed) : accentColor) : Color.clear))
            .messagePanelControlBackground(size: size)
            .scaleEffect(isHolding ? VoiceRecordingLayout.holdingScale : 1)
            .offset(x: isHolding ? cancelOffset : 0, y: isHolding ? lockOffset : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHolding)
            .contentShape(Circle())
            .gesture(holdGesture)
            .accessibilityElement()
            .accessibilityLabel(L10n.Accessibility.voiceMessageRecord)
            .accessibilityHint(L10n.Accessibility.voiceMessageRecordHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.startHandsFree() }
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    pressStart = Date()
                    model.beginHold()
                    if isHolding { impact() }
                }
                guard isHolding else { return }
                translation = value.translation
                if lockOffset <= -VoiceRecordingLayout.lockDistance {
                    translation = .zero
                    model.lock()
                    impact()
                } else if abs(cancelOffset) >= VoiceRecordingLayout.cancelDistance {
                    translation = .zero
                    model.cancel()
                    impact()
                }
            }
            .onEnded { value in
                defer {
                    pressStart = nil
                    translation = .zero
                }
                guard isHolding, let start = pressStart else { return }
                let isTap = Date().timeIntervalSince(start) < VoiceRecordingLayout.tapDuration
                    && hypot(value.translation.width, value.translation.height) < VoiceRecordingLayout.tapMovement
                if isTap {
                    model.lock()
                } else {
                    model.releaseHold()
                }
            }
    }
}

// MARK: - Locked and preview panel

struct VoiceRecordingPanel: View {
    @ObservedObject var model: VoiceRecordingVM
    let accentColor: Color

    var body: some View {
        VStack(spacing: 10) {
            if model.state == .preview, let player = model.previewPlayer {
                PlayerView(viewModel: player,
                           sizeMode: .inConversationMessage,
                           withControls: true,
                           audioColors: AudioMessageColors(background: accentColor,
                                                           foreground: .white,
                                                           control: .white,
                                                           controlBackground: Color.white.opacity(0.22)))
                    .frame(height: VoiceRecordingLayout.previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: VoiceRecordingLayout.panelCornerRadius, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    if model.state == .locked {
                        RecordingDot()
                    }
                    Text(formattedDuration(model.elapsed))
                        .font(.body.monospacedDigit())
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
                .frame(height: VoiceRecordingLayout.controlSize)
            }
            HStack {
                deleteButton
                Spacer()
                if model.state == .locked {
                    stopButton
                }
                Spacer()
                sendButton
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: VoiceRecordingLayout.panelCornerRadius, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground)))
    }

    private var deleteButton: some View {
        Button(action: model.cancel) {
            Image(systemName: "trash")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(Color(UIColor.systemRed))
                .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Accessibility.voiceMessageDelete)
    }

    private var stopButton: some View {
        Button(action: model.stop) {
            Image(systemName: "stop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(UIColor.systemRed))
                .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
                .overlay(Circle().stroke(Color(UIColor.systemRed), lineWidth: 2))
                .contentShape(Circle())
        }
        .accessibilityLabel(L10n.Accessibility.voiceMessageStop)
    }

    private var sendButton: some View {
        Button(action: model.send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
                .background(Circle().fill(accentColor))
        }
        .accessibilityLabel(L10n.Accessibility.voiceMessageSend)
    }
}

// MARK: - Hint

struct VoiceRecordingHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundColor(Color(UIColor.systemBackground))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(UIColor.label)))
            .accessibilityHidden(true)
    }
}

// MARK: - Shared pieces

private struct RecordingDot: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @SwiftUI.State private var dimmed = false

    var body: some View {
        Circle()
            .fill(Color(UIColor.systemRed))
            .frame(width: 10, height: 10)
            .opacity(dimmed ? 0.25 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}
