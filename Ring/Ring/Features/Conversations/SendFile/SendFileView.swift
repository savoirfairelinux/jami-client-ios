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

// MARK: - Main View

struct SendFileView: View {
    @ObservedObject var viewModel: SendFileViewModel

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()
            contentLayer
        }
    }

    // MARK: Background

    private var backgroundLayer: some View {
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

    // MARK: Content

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
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPlayerControls)
    }

    // MARK: Top Bar

    private var topBar: some View {
        VStack(spacing: 8) {
            ZStack {
                HStack {
                    cancelButton
                    Spacer()
                    if !viewModel.audioOnly {
                        switchCameraButton
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                recordingTimerBadge
                    .opacity(viewModel.isRecording ? 1 : 0)
                    .scaleEffect(viewModel.isRecording ? 1 : 0.7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isRecording)
            }

            if viewModel.isReadyToSend {
                sendRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isReadyToSend)
    }

    private var sendRow: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.audioOnly ? "waveform" : "video.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            Text(URL(fileURLWithPath: viewModel.fileName).lastPathComponent)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .darkRoundedBackground(cornerRadius: 14)
    }

    private var sendButton: some View {
        Button {
            viewModel.sendFile()
        } label: {
            HStack(spacing: 6) {
                Text(L10n.DataTransfer.sendMessage)
                    .font(.system(size: 17, weight: .regular))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.9))
            .clipShape(Capsule())
        }
    }

    private var cancelButton: some View {
        Button {
            viewModel.cancel()
        } label: {
            glassLabel(text: L10n.Global.cancel)
        }
    }

    private var switchCameraButton: some View {
        Button {
            viewModel.switchCamera()
        } label: {
            glassIcon(systemName: "arrow.triangle.2.circlepath.camera")
        }
    }

    private var recordingTimerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.recordDuration.isEmpty ? "00:00" : viewModel.recordDuration)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
                .frame(minWidth: 44, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .darkCapsuleBackground()
    }

    // MARK: Audio-only Content

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
                AudioWaveformView(isAnimating: viewModel.isRecording)
                    .frame(height: 80)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundColor(viewModel.isReadyToSend ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
    }

    // MARK: Player Controls

    private var playerControlsPanel: some View {
        VStack(spacing: 16) {
            SeekSlider(
                position: viewModel.playerPosition,
                onSeekStart: { [weak viewModel] in viewModel?.userStartSeeking() },
                onSeekChange: { [weak viewModel] value in viewModel?.seek(to: value) },
                onSeekEnd: { [weak viewModel] in viewModel?.userStopSeeking() }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .darkRoundedBackground(cornerRadius: 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var playPauseButton: some View {
        Button {
            viewModel.togglePause()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 3)
                    .frame(width: 72, height: 72)
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(width: 72, height: 72)
            .darkCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var muteButton: some View {
        Button {
            viewModel.muteAudio()
        } label: {
            Image(systemName: viewModel.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .darkCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var durationText: some View {
        Text(durationString(microseconds: viewModel.playerDuration))
            .font(.system(.subheadline, design: .monospaced))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(minWidth: 56, alignment: .leading)
            .padding(.leading, 4)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        recordButton
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.bottom, 16)
    }

    private var recordButton: some View {
        Button {
            viewModel.triggerRecording()
        } label: {
            RecordButtonLabel(isRecording: viewModel.isRecording)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Helpers

    private func glassLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .darkCapsuleBackground()
    }

    private func glassIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .darkCircleBackground()
    }

    private func durationString(microseconds: Float) -> String {
        guard microseconds > 0 else { return "" }
        let totalSeconds = Int(microseconds / 1_000_000)
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Record Button Label

private struct RecordButtonLabel: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: 72, height: 72)
            if isRecording {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 48, height: 48)
            }
        }
        .frame(width: 72, height: 72)
        .darkCircleBackground()
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
    }
}

// MARK: - Seek Slider

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
        slider.value = position
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        slider.thumbTintColor = .white
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.sliderChanged(_:)),
                         for: .valueChanged)
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.sliderTouchDown(_:)),
                         for: .touchDown)
        slider.addTarget(context.coordinator,
                         action: #selector(Coordinator.sliderTouchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        if !context.coordinator.isSeeking {
            uiView.value = position
        }
    }

    final class Coordinator: NSObject {
        var parent: SeekSlider
        var isSeeking = false
        init(parent: SeekSlider) { self.parent = parent }

        @objc func sliderTouchDown(_ slider: UISlider) {
            isSeeking = true
            parent.onSeekStart()
        }
        @objc func sliderChanged(_ slider: UISlider) {
            parent.onSeekChange(slider.value)
        }
        @objc func sliderTouchUp(_ slider: UISlider) {
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
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Control Background Helpers

private func controlBackground<S: Shape>(shape: S) -> some View {
    ZStack {
        VisualEffectView(effect: UIBlurEffect(style: .dark))
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
        self.background(controlBackground(shape: Circle()))
    }
    func darkRoundedBackground(cornerRadius: CGFloat = 14) -> some View {
        self.background(controlBackground(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }
    func darkCapsuleBackground() -> some View {
        self.background(controlBackground(shape: Capsule()))
    }
}

// MARK: - Audio Waveform Animation

struct AudioWaveformView: View {
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

struct WaveformBar: View {
    let index: Int
    let isAnimating: Bool

    @SwiftUI.State private var height: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.jamiColor)
            .frame(width: 4, height: height)
            .onAppear {
                guard isAnimating else { return }
                startAnimation()
            }
            .onChange(of: isAnimating) { animating in
                if animating {
                    startAnimation()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        height = 8
                    }
                }
            }
    }

    private func startAnimation() {
        let delay = Double(index) * 0.06
        withAnimation(
            Animation
                .easeInOut(duration: 0.5 + Double.random(in: 0...0.3))
                .repeatForever(autoreverses: true)
                .delay(delay)
        ) {
            height = CGFloat.random(in: 20...60)
        }
    }
}
