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

// MARK: - Layout Constants

private enum Layout {
    static let primaryButtonSize: CGFloat = 72
    static let controlSize: CGFloat = 52
    static let screenPadding: CGFloat = 16
    static let timerHeight: CGFloat = 32
}

// MARK: - Icon Constants

private enum Style {
    static let iconSize: CGFloat = 21
    static let ringStrokeWidth: CGFloat = 3
    static let ringStrokeOpacity: Double = 0.6
    static let recordDotSize: CGFloat = 48
    static let stopSquareSize: CGFloat = 24
    static let stopSquareCornerRadius: CGFloat = 6
}

// MARK: - Animation Constants

private enum Animation {
    static let dampingSnappy: Double = 0.6
    static let dampingMedium: Double = 0.7
    static let dampingSmooth: Double = 0.8

    static let responseBadge: Double = 0.3
    static let responseTray: Double = 0.35
}

// MARK: - MediaRecordView

struct MediaRecordView: View {
    @ObservedObject var viewModel: MediaRecordViewModel

    var body: some View {
        ZStack {
            VideoPreviewLayer(viewModel: viewModel)
                .ignoresSafeArea()
            contentLayer
        }
        .onAppear { viewModel.previewAppeared() }
        .onDisappear { viewModel.previewDisappeared() }
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if viewModel.isReadyToSend {
                previewTray
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                recordButton
            }
        }
        .padding(.horizontal, Layout.screenPadding)
        .animation(.spring(response: Animation.responseTray, dampingFraction: Animation.dampingSmooth),
                   value: viewModel.isReadyToSend)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            HStack {
                cancelButton
                Spacer()
                if viewModel.isReadyToSend {
                    muteButton
                } else {
                    switchCameraButton
                }
            }
            if viewModel.isRecording {
                recordingTimerBadge
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .animation(.spring(response: Animation.responseBadge, dampingFraction: Animation.dampingMedium),
                   value: viewModel.isRecording)
    }

    private var recordingTimerBadge: some View {
        HStack(spacing: 8) {
            RecordingDot()
            Text(viewModel.recordDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .frame(height: Layout.timerHeight)
        .glassCapsuleBackground()
    }

    private var cancelButton: some View {
        glassLabelButton(text: L10n.Global.cancel) { viewModel.cancel() }
    }

    private var switchCameraButton: some View {
        glassIconButton(systemName: "arrow.triangle.2.circlepath.camera", accessibilityLabel: L10n.Accessibility.Calls.Default.switchCamera) { viewModel.switchCamera() }
    }

    private var muteButton: some View {
        glassIconButton(systemName: viewModel.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        accessibilityLabel: viewModel.isAudioMuted ? L10n.Accessibility.audioPlayerUnmute : L10n.Accessibility.audioPlayerMute) {
            viewModel.muteAudio()
        }
    }

    // MARK: - Preview Tray

    private var previewTray: some View {
        VStack(spacing: 12) {
            MediaScrubberRow(elapsed: viewModel.previewElapsed,
                             duration: viewModel.previewDuration) {
                MediaSeekSlider(onRegister: viewModel.registerPreviewSlider,
                                onSeekStart: viewModel.userStartSeeking,
                                onSeekChange: viewModel.seek(to:),
                                onSeekEnd: viewModel.userStopSeeking)
            }
            HStack(spacing: 12) {
                sideButton(L10n.DataTransfer.retake, weight: .regular, alignment: .leading, action: viewModel.retake)
                playPauseButton
                sideButton(L10n.DataTransfer.sendMessage, weight: .semibold, alignment: .trailing, action: viewModel.sendFile)
            }
        }
        .mediaTrayStyle()
        .padding(.bottom, Layout.screenPadding)
    }

    @ViewBuilder private var playPauseButton: some View {
        let button = Button { viewModel.togglePause() } label: {
            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: Style.iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: Layout.controlSize, height: Layout.controlSize)
                .contentShape(Circle())
        }
        .accessibilityLabel(viewModel.isPaused ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause)
        if #available(iOS 26, *) {
            button.glassEffect(.clear.interactive(), in: .circle)
        } else {
            button
                .glassCircleBackground()
                .buttonStyle(ScaleButtonStyle())
        }
    }

    private func sideButton(_ title: String, weight: Font.Weight, alignment: Alignment, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(weight))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 44, minHeight: 44, alignment: alignment)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button { viewModel.triggerRecording() } label: {
            RecordButtonLabel(isRecording: viewModel.isRecording)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(viewModel.isRecording ? L10n.Accessibility.voiceMessageStop : L10n.Alerts.recordVideoMessage)
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, Layout.screenPadding)
    }
}

// MARK: - Video Preview Layer

private struct VideoPreviewLayer: View {
    @ObservedObject var viewModel: MediaRecordViewModel

    var body: some View {
        GeometryReader { geo in
            Color.black
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        }
    }
}

private struct RecordButtonLabel: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(Style.ringStrokeOpacity), lineWidth: Style.ringStrokeWidth)
                .frame(width: Layout.primaryButtonSize, height: Layout.primaryButtonSize)
            if isRecording {
                RoundedRectangle(cornerRadius: Style.stopSquareCornerRadius, style: .continuous)
                    .fill(Color.red)
                    .frame(width: Style.stopSquareSize, height: Style.stopSquareSize)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: Style.recordDotSize, height: Style.recordDotSize)
            }
        }
        .frame(width: Layout.primaryButtonSize, height: Layout.primaryButtonSize)
        .glassCircleBackground()
        .animation(.spring(response: Animation.responseBadge, dampingFraction: Animation.dampingSnappy),
                   value: isRecording)
    }
}
