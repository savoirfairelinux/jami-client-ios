/*
 * Copyright (C) 2019-2025 Savoir-faire Linux Inc.
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
    // Touch targets — all interactive controls use this size
    static let touchTargetSize: CGFloat = 44

    // Primary action buttons (record, play/pause)
    static let primaryButtonSize: CGFloat = 72

    // Horizontal margin from screen edges (topBar, playerControlsPanel outer padding)
    static let screenHorizontalPadding: CGFloat = 20

    // Inner horizontal padding inside panels and pill buttons
    static let innerHorizontalPadding: CGFloat = 16

    // Corner radius shared by all card-style panels
    static let panelCornerRadius: CGFloat = 14
}

// MARK: - Icon & Typography Constants

private enum Style {
    // Icon sizes
    static let iconSize: CGFloat = 20        // toolbar icons, secondary controls
    static let largeIconSize: CGFloat = 28   // play/pause glyph inside primary button
    static let heroIconSize: CGFloat = 60    // static waveform illustration

    // Text sizes
    static let primaryTextSize: CGFloat = 17 // labels on pill buttons (cancel, send)
    static let secondaryTextSize: CGFloat = 15 // filename in send row

    // Circle stroke shared by both ring buttons (record outer ring, play/pause outer ring)
    static let ringStrokeWidth: CGFloat = 3
    static let ringStrokeOpacity: Double = 0.6

    // Record button inner shapes
    static let recordDotSize: CGFloat = 48        // red dot when idle
    static let stopSquareSize: CGFloat = 24       // white square when recording
    static let stopSquareCornerRadius: CGFloat = 6
}

// MARK: - Animation Constants

private enum Animation {
    // Spring damping fractions
    static let dampingSnappy: Double = 0.6  // button press, record button shape change
    static let dampingMedium: Double = 0.7  // recording timer badge
    static let dampingSmooth: Double = 0.8  // send row slide-in

    // Spring responses
    static let responseButton: Double = 0.25
    static let responseBadge: Double = 0.3
    static let responseSendRow: Double = 0.35

    // Easing durations
    static let durationFast: Double = 0.25   // player controls panel appear
    static let durationNormal: Double = 0.3  // waveform switch, bar reset

    // Button press scale
    static let pressedScale: CGFloat = 0.92

    // Waveform bar animation
    static let waveformBarMinDuration: Double = 0.5
    static let waveformBarMaxDuration: Double = 0.8
    static let waveformBarStaggerDelay: Double = 0.06

    // Waveform bar heights
    static let waveformBarMinHeight: CGFloat = 8
    static let waveformBarMaxHeight: CGFloat = 60
}

// MARK: - SendFileView

struct SendFileView: View {
    @ObservedObject var viewModel: SendFileViewModel

    var body: some View {
        ZStack {
            // Isolated into its own @ObservedObject child so that per-frame
            // previewImage updates do not cause the rest of the view tree to re-render.
            VideoPreviewLayer(viewModel: viewModel)
                .ignoresSafeArea()
            contentLayer
        }
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if viewModel.audioOnly {
                audioOnlyContent
            }
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
            // First row: cancel | timer (centered) | switch camera
            ZStack {
                HStack {
                    cancelButton
                    Spacer()
                    if viewModel.audioOnly {
                        Color.clear.frame(width: Layout.touchTargetSize, height: Layout.touchTargetSize)
                    } else {
                        switchCameraButton
                    }
                }
                recordingTimerBadge
                    .opacity(viewModel.isRecording ? 1 : 0)
                    .scaleEffect(viewModel.isRecording ? 1 : 0.7)
                    .animation(.spring(response: Animation.responseBadge, dampingFraction: Animation.dampingMedium),
                               value: viewModel.isRecording)
            }

            // Second row: file name + send button, slides in when recording is done
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
        .darkCapsuleBackground()
    }

    private var sendRow: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.audioOnly ? "waveform" : "video.fill")
                .font(.system(size: Style.iconSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            // fileDisplayName is pre-computed in the VM — no URL allocation per render
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
        .darkRoundedBackground(cornerRadius: Layout.panelCornerRadius)
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
        Button { viewModel.cancel() } label: {
            glassLabel(text: L10n.Global.cancel)
        }
    }

    private var switchCameraButton: some View {
        Button { viewModel.switchCamera() } label: {
            glassIcon(systemName: "arrow.triangle.2.circlepath.camera")
        }
    }

    // MARK: - Audio-only Content

    @ViewBuilder
    private var audioOnlyContent: some View {
        VStack(spacing: 24) {
            if !viewModel.hideInfo {
                Text(L10n.DataTransfer.infoMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
            audioWaveformView
        }
        .padding(.vertical, 40)
    }

    private var audioWaveformView: some View {
        ZStack {
            if viewModel.isRecording {
                AudioWaveformView(isAnimating: true)
                    .frame(height: 80)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: Style.heroIconSize, weight: .ultraLight))
                    .foregroundColor(viewModel.isReadyToSend ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Animation.durationNormal), value: viewModel.isRecording)
    }

    // MARK: - Player Controls

    private var playerControlsPanel: some View {
        VStack(spacing: Layout.innerHorizontalPadding) {
            SeekSlider(
                position: viewModel.playerPosition,
                onSeekStart: { viewModel.userStartSeeking() },
                onSeekChange: { viewModel.seek(to: $0) },
                onSeekEnd: { viewModel.userStopSeeking() }
            )
            .padding(.horizontal, 4)

            // Play/pause centered; duration left; mute right
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
        .darkRoundedBackground(cornerRadius: Layout.panelCornerRadius)
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
            .darkCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var muteButton: some View {
        Button { viewModel.muteAudio() } label: {
            Image(systemName: viewModel.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: Style.iconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: Layout.touchTargetSize, height: Layout.touchTargetSize)
                .darkCircleBackground()
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

    // MARK: - Label Helpers

    private func glassLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: Style.primaryTextSize, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, Layout.innerHorizontalPadding)
            .frame(height: Layout.touchTargetSize)
            .darkCapsuleBackground()
    }

    private func glassIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: Style.iconSize, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: Layout.touchTargetSize, height: Layout.touchTargetSize)
            .darkCircleBackground()
    }
}

// MARK: - Video Preview Layer

/// Dedicated view that owns the previewImage subscription.
/// Keeping it separate means per-frame image updates only invalidate this view,
/// not the controls and overlays in SendFileView.
private struct VideoPreviewLayer: View {
    @ObservedObject var viewModel: SendFileViewModel

    var body: some View {
        GeometryReader { geo in
            if viewModel.audioOnly {
                Color(UIColor.systemBackground)
            } else {
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
}

// MARK: - Record Button Label

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
        .darkCircleBackground()
        .animation(.spring(response: Animation.responseBadge, dampingFraction: Animation.dampingSnappy),
                   value: isRecording)
    }
}

// MARK: - Seek Slider

/// `UISlider` wrapper that sets both track colors explicitly, which SwiftUI's
/// `Slider` does not support — the unfilled track needs to be visible on dark backgrounds.
private struct SeekSlider: UIViewRepresentable {
    let position: Float
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        slider.thumbTintColor = .white
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.touchDown(_:)),
                         for: .touchDown)
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.valueChanged(_:)),
                         for: .valueChanged)
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.touchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        context.coordinator.parent = self
        if !context.coordinator.isSeeking {
            uiView.value = position
        }
    }

    final class Coordinator: NSObject {
        var parent: SeekSlider
        var isSeeking = false

        init(parent: SeekSlider) { self.parent = parent }

        @objc func touchDown(_ slider: UISlider) {
            isSeeking = true
            parent.onSeekStart()
        }
        @objc func valueChanged(_ slider: UISlider) {
            parent.onSeekChange(slider.value)
        }
        @objc func touchUp(_ slider: UISlider) {
            parent.onSeekChange(slider.value)
            parent.onSeekEnd()
            isSeeking = false
        }
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Animation.pressedScale : 1.0)
            .animation(.spring(response: Animation.responseButton, dampingFraction: Animation.dampingSnappy),
                       value: configuration.isPressed)
    }
}

// MARK: - Control Background Helpers

// Shared blur effect instance — avoids allocating a new UIBlurEffect on every render.
private let darkBlurEffect = UIBlurEffect(style: .dark)

private func controlBackground<S: Shape>(shape: S) -> some View {
    ZStack {
        VisualEffectView(effect: darkBlurEffect)
        LinearGradient(
            colors: [Color.black.opacity(0.05), Color.black.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(0.5)
    }
    .clipShape(shape)
    .overlay(shape.stroke(Color.white.opacity(0.2), lineWidth: 0.5))
}

private extension View {
    func darkCircleBackground() -> some View {
        background(controlBackground(shape: Circle()))
    }
    func darkRoundedBackground(cornerRadius: CGFloat = Layout.panelCornerRadius) -> some View {
        background(controlBackground(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }
    func darkCapsuleBackground() -> some View {
        background(controlBackground(shape: Capsule()))
    }
}

// MARK: - Duration Formatting

private extension Float {
    /// Converts a duration in microseconds to a human-readable `mm:ss` or `hh:mm:ss` string.
    var durationString: String {
        guard self > 0 else { return "" }
        let total = Int(self / 1_000_000)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Audio Waveform Animation

fileprivate struct AudioWaveformView: View {
    let isAnimating: Bool
    private let barCount = 20

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(index: index, isAnimating: isAnimating)
            }
        }
    }
}

fileprivate struct WaveformBar: View {
    let index: Int
    let isAnimating: Bool

    @SwiftUI.State private var height: CGFloat = Animation.waveformBarMinHeight

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.jamiColor)
            .frame(width: 4, height: height)
            .onAppear {
                if isAnimating { startAnimation() }
            }
            .onChange(of: isAnimating) { animating in
                if animating {
                    startAnimation()
                } else {
                    withAnimation(.easeInOut(duration: Animation.durationNormal)) {
                        height = Animation.waveformBarMinHeight
                    }
                }
            }
    }

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: Double.random(in: Animation.waveformBarMinDuration...Animation.waveformBarMaxDuration))
            .repeatForever(autoreverses: true)
            .delay(Double(index) * Animation.waveformBarStaggerDelay)
        ) {
            height = CGFloat.random(in: Animation.waveformBarMinHeight...Animation.waveformBarMaxHeight)
        }
    }
}
