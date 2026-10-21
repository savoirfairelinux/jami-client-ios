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
    static let touchTargetSize: CGFloat = 44
    static let primaryButtonSize: CGFloat = 72
    static let screenHorizontalPadding: CGFloat = 20
    static let innerHorizontalPadding: CGFloat = 16
    static let panelCornerRadius: CGFloat = 14
}

// MARK: - Icon & Typography Constants

private enum Style {
    static let iconSize: CGFloat = 20
    static let largeIconSize: CGFloat = 28
    static let primaryTextSize: CGFloat = 17
    static let secondaryTextSize: CGFloat = 15
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
    static let responseSendRow: Double = 0.35

    static let durationFast: Double = 0.25
}

// MARK: - SendFileView

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
            bottomBar
            if viewModel.showPlayerControls {
                playerControlsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: Animation.durationFast), value: viewModel.showPlayerControls)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 8) {
            ZStack {
                HStack {
                    cancelButton
                    Spacer()
                    switchCameraButton
                }
                recordingTimerBadge
                    .opacity(viewModel.isRecording ? 1 : 0)
                    .scaleEffect(viewModel.isRecording ? 1 : 0.7)
                    .animation(.spring(response: Animation.responseBadge, dampingFraction: Animation.dampingMedium),
                               value: viewModel.isRecording)
            }

            if viewModel.isReadyToSend {
                sendRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Layout.screenHorizontalPadding)
        .padding(.top, Layout.innerHorizontalPadding)
        .padding(.bottom, 8)
        .animation(.spring(response: Animation.responseSendRow, dampingFraction: Animation.dampingSmooth),
                   value: viewModel.isReadyToSend)
    }

    private var recordingTimerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.recordDuration)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
                .frame(minWidth: Layout.touchTargetSize, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: Layout.touchTargetSize)
        .glassCapsuleBackground()
    }

    private var sendRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.system(size: Style.iconSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Text(viewModel.fileDisplayName)
                .font(.system(size: Style.secondaryTextSize, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            sendButton
        }
        .padding(.horizontal, Layout.innerHorizontalPadding)
        .padding(.vertical, 10)
        .glassRoundedBackground(cornerRadius: Layout.panelCornerRadius)
    }

    private var sendButton: some View {
        Button { viewModel.sendFile() } label: {
            HStack(spacing: 6) {
                Text(L10n.DataTransfer.sendMessage)
                    .font(.system(size: Style.primaryTextSize, weight: .regular))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: Style.primaryTextSize, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, Layout.innerHorizontalPadding)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
        }
    }

    private var cancelButton: some View {
        glassLabelButton(text: L10n.Global.cancel) { viewModel.cancel() }
    }

    private var switchCameraButton: some View {
        glassIconButton(systemName: "arrow.triangle.2.circlepath.camera", accessibilityLabel: L10n.Accessibility.Calls.Default.switchCamera) { viewModel.switchCamera() }
    }

    // MARK: - Player Controls

    private var playerControlsPanel: some View {
        VStack(spacing: Layout.innerHorizontalPadding) {
            MediaSeekSlider(
                onRegister: { viewModel.registerSlider($0) },
                onSeekStart: { viewModel.userStartSeeking() },
                onSeekChange: { viewModel.seek(to: $0) },
                onSeekEnd: { viewModel.userStopSeeking() }
            )
            .padding(.horizontal, 4)

            ZStack {
                playPauseButton
                HStack {
                    durationText
                    Spacer()
                    muteButton
                }
            }
        }
        .padding(.horizontal, Layout.innerHorizontalPadding)
        .padding(.vertical, 12)
        .glassRoundedBackground(cornerRadius: Layout.panelCornerRadius)
        .padding(.horizontal, Layout.screenHorizontalPadding)
        .padding(.bottom, Layout.innerHorizontalPadding)
    }

    private var playPauseButton: some View {
        Button { viewModel.togglePause() } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(Style.ringStrokeOpacity), lineWidth: Style.ringStrokeWidth)
                    .frame(width: Layout.primaryButtonSize, height: Layout.primaryButtonSize)
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: Style.largeIconSize, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: Layout.primaryButtonSize, height: Layout.primaryButtonSize)
            .glassCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var muteButton: some View {
        Button { viewModel.muteAudio() } label: {
            Image(systemName: viewModel.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: Style.iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: Layout.touchTargetSize, height: Layout.touchTargetSize)
                .glassCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var durationText: some View {
        Text(viewModel.playerDuration.durationString)
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(minWidth: 56, alignment: .leading)
            .padding(.leading, 4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        Button { viewModel.triggerRecording() } label: {
            RecordButtonLabel(isRecording: viewModel.isRecording)
        }
        .buttonStyle(ScaleButtonStyle())
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.bottom, Layout.innerHorizontalPadding)
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
                    .fill(Color.white)
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
