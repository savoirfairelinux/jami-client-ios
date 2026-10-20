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
    static let rowHeight: CGFloat = 44
    static let controlSize: CGFloat = 52
    static let sideWidth: CGFloat = 80
    static let cornerRadius: CGFloat = 26
}

private func formattedDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Recording panel

struct VoiceRecordingPanel: View {
    @ObservedObject var model: VoiceRecordingVM

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if model.state == .recording {
                    recordingRow
                } else {
                    previewRow
                }
            }
            .frame(height: VoiceRecordingLayout.rowHeight)
            HStack {
                sideButton(L10n.Global.cancel, weight: .regular, alignment: .leading, action: model.cancel)
                Spacer(minLength: 0)
                centerControl
                Spacer(minLength: 0)
                sideButton(L10n.DataTransfer.sendMessage, weight: .semibold, alignment: .trailing, action: model.send)
                    .accessibilityLabel(L10n.Accessibility.voiceMessageSend)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .messagePanelGlass(in: RoundedRectangle(cornerRadius: VoiceRecordingLayout.cornerRadius, style: .continuous))
    }

    private var recordingRow: some View {
        HStack(spacing: 10) {
            RecordingDot()
            Text(formattedDuration(model.elapsed))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(Color(UIColor.label))
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
    }

    private var previewRow: some View {
        HStack(spacing: 12) {
            timeLabel(model.previewElapsed)
            VoicePreviewScrubber(model: model)
            timeLabel(model.previewDuration > 0 ? model.previewDuration : model.elapsed)
        }
        .padding(.horizontal, 6)
    }

    private var centerControl: some View {
        Button(action: model.state == .recording ? model.stop : model.togglePreview) {
            Image(systemName: centerIcon)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
                .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(centerAccessibilityLabel)
    }

    private var centerIcon: String {
        if model.state == .recording { return "stop.fill" }
        return model.isPreviewPlaying ? "pause.fill" : "play.fill"
    }

    private var centerAccessibilityLabel: String {
        if model.state == .recording { return L10n.Accessibility.voiceMessageStop }
        return model.isPreviewPlaying ? L10n.Accessibility.audioPlayerPause : L10n.Accessibility.audioPlayerPlay
    }

    private func sideButton(_ title: String, weight: Font.Weight, alignment: Alignment, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(weight))
                .foregroundColor(Color(UIColor.jamiButtonPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: VoiceRecordingLayout.sideWidth, height: VoiceRecordingLayout.rowHeight, alignment: alignment)
                .contentShape(Rectangle())
        }
    }

    private func timeLabel(_ seconds: TimeInterval) -> some View {
        Text(formattedDuration(seconds))
            .font(.subheadline.monospacedDigit())
            .foregroundColor(Color(UIColor.secondaryLabel))
    }
}

// MARK: - Preview scrubber

private struct VoicePreviewScrubber: View {
    @ObservedObject var model: VoiceRecordingVM
    @GestureState private var isDragging = false
    @SwiftUI.State private var isSeeking = false

    private static let restingHeight: CGFloat = 4
    private static let activeHeight: CGFloat = 8
    private static let accessibilityStep: Float = 0.1

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(UIColor.systemFill))
                Capsule()
                    .fill(isSeeking ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                    .frame(width: geometry.size.width * CGFloat(model.previewProgress))
            }
            .frame(height: isSeeking ? Self.activeHeight : Self.restingHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geometry.size.width))
        }
        .animation(.easeOut(duration: 0.15), value: isSeeking)
        .onChange(of: isDragging) { dragging in
            guard !dragging, isSeeking else { return }
            isSeeking = false
            model.endPreviewSeek()
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Accessibility.audioPlayerSeek)
        .accessibilityValue(formattedDuration(model.previewElapsed))
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? Self.accessibilityStep : -Self.accessibilityStep
            model.beginPreviewSeek()
            model.seekPreview(to: min(1, max(0, model.previewProgress + step)))
            model.endPreviewSeek()
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isDragging) { _, dragging, _ in
                dragging = true
            }
            .onChanged { value in
                if !isSeeking {
                    isSeeking = true
                    model.beginPreviewSeek()
                }
                guard width > 0 else { return }
                model.seekPreview(to: Float(min(1, max(0, value.location.x / width))))
            }
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
