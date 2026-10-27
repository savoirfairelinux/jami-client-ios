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
    static let cornerRadius: CGFloat = 26
}

// MARK: - Recording panel

struct VoiceRecordingPanel: View {
    @ObservedObject var model: VoiceRecordingVM

    var body: some View {
        VoiceRecordingControls(model: model)
            .messagePanelGlass(in: RoundedRectangle(cornerRadius: VoiceRecordingLayout.cornerRadius, style: .continuous))
    }
}

struct VoiceRecordingControls: View {
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
            HStack(spacing: 12) {
                trayTextButton(L10n.Global.cancel, weight: .regular, alignment: .leading, color: Color(UIColor.jamiButtonPrimary), action: model.cancel)
                centerControl
                trayTextButton(L10n.DataTransfer.sendMessage, weight: .semibold, alignment: .trailing, color: Color(UIColor.jamiButtonPrimary), action: model.send)
                    .accessibilityLabel(L10n.Accessibility.voiceMessageSend)
            }
        }
        .padding(14)
    }

    private var recordingRow: some View {
        HStack(spacing: 8) {
            RecordingDot()
            Text(String.durationFormatted(seconds: Int(model.elapsed)))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(Color(UIColor.label))
            Spacer(minLength: 0)
        }
    }

    private var previewRow: some View {
        HStack(spacing: 12) {
            previewPlayButton
            timeLabel(model.previewElapsed)
            MediaSeekSlider(trackColor: Color(UIColor.systemFill),
                            fillColor: Color(UIColor.secondaryLabel),
                            activeFillColor: Color(UIColor.label),
                            onRegister: model.registerPreviewSlider,
                            onSeekStart: model.beginPreviewSeek,
                            onSeekChange: model.seekPreview(to:),
                            onSeekEnd: model.endPreviewSeek)
            timeLabel(model.previewDuration > 0 ? model.previewDuration : model.elapsed)
        }
    }

    private var previewPlayButton: some View {
        Button(action: model.togglePreview) {
            Image(systemName: model.isPreviewPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .frame(width: VoiceRecordingLayout.rowHeight, height: VoiceRecordingLayout.rowHeight)
                .background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(model.isPreviewPlaying ? L10n.Accessibility.audioPlayerPause : L10n.Accessibility.audioPlayerPlay)
    }

    @ViewBuilder private var centerControl: some View {
        if model.state == .recording {
            Button(action: model.stop) {
                stopIcon
                    .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(L10n.Accessibility.voiceMessageStop)
        } else {
            Button(action: model.retake) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2.weight(.medium))
                    .foregroundColor(Color(UIColor.jamiButtonPrimary))
                    .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(L10n.DataTransfer.retake)
        }
    }

    private var stopIcon: some View {
        ZStack {
            Circle()
                .strokeBorder(Color(UIColor.tertiaryLabel), lineWidth: 2)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(UIColor.systemRed))
                .frame(width: 17, height: 17)
        }
        .frame(width: VoiceRecordingLayout.controlSize, height: VoiceRecordingLayout.controlSize)
    }

    private func timeLabel(_ seconds: TimeInterval) -> some View {
        Text(String.durationFormatted(seconds: Int(seconds)))
            .font(.subheadline.monospacedDigit())
            .foregroundColor(Color(UIColor.secondaryLabel))
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

struct RecordingDot: View {
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
