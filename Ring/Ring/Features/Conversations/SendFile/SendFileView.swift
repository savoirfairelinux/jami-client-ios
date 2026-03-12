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
import RxSwift

// MARK: - Observable Model

final class SendFileObservableModel: ObservableObject {
    let viewModel: SendFileViewModel

    @Published var previewImage: UIImage?
    @Published var isRecording: Bool = false
    @Published var isReadyToSend: Bool = false
    @Published var showPlayerControls: Bool = false
    @Published var recordDuration: String = ""
    @Published var playerPosition: Float = 0
    @Published var playerDuration: Float = 0
    @Published var isPaused: Bool = true
    @Published var isAudioMuted: Bool = true
    @Published var hideInfo: Bool = false
    @Published var isDismissed: Bool = false

    private var disposeBag = DisposeBag()

    init(viewModel: SendFileViewModel) {
        self.viewModel = viewModel
        bindViewModel()
    }

    private func bindViewModel() {
        viewModel.playBackFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.previewImage = image
            })
            .disposed(by: disposeBag)

        viewModel.recording
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] recording in
                self?.isRecording = recording
            })
            .disposed(by: disposeBag)

        viewModel.readyToSend
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] ready in
                self?.isReadyToSend = ready
            })
            .disposed(by: disposeBag)

        viewModel.showPlayerControls
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] show in
                self?.showPlayerControls = show
            })
            .disposed(by: disposeBag)

        viewModel.recordDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                self?.recordDuration = duration
            })
            .disposed(by: disposeBag)

        viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                self?.playerPosition = position
            })
            .disposed(by: disposeBag)

        viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] duration in
                self?.playerDuration = duration
            })
            .disposed(by: disposeBag)

        viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] paused in
                self?.isPaused = paused
            })
            .disposed(by: disposeBag)

        viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] muted in
                self?.isAudioMuted = muted
            })
            .disposed(by: disposeBag)

        viewModel.hideInfo
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] hide in
                self?.hideInfo = hide
            })
            .disposed(by: disposeBag)

        viewModel.finished
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] finished in
                if finished {
                    self?.isDismissed = true
                }
            })
            .disposed(by: disposeBag)
    }

    func durationString(microseconds: Float) -> String {
        guard microseconds > 0 else { return "" }
        let totalSeconds = Int(microseconds / 1_000_000)
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Main View

struct SendFileView: View {
    @ObservedObject var model: SendFileObservableModel
    @SwiftUI.State private var isSeeking: Bool = false

    var body: some View {
        ZStack {
            // Background: clipped so scaledToFill image can't overflow layout
            backgroundLayer
                .ignoresSafeArea()
            // Content: lives in the safe area by default, no ignoresSafeArea here
            contentLayer
        }
    }

    // MARK: Background

    private var backgroundLayer: some View {
        GeometryReader { geo in
            if model.viewModel.audioOnly {
                Color(UIColor.systemBackground)
            } else {
                Color.black
                if let image = model.previewImage {
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
            if model.viewModel.audioOnly {
                audioOnlyContent
            }
            bottomBar
            if model.showPlayerControls {
                playerControlsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.showPlayerControls)
    }

    // MARK: Top Bar

    private var topBar: some View {
        VStack(spacing: 8) {
            // First row: cancel / timer / switch camera
            ZStack {
                HStack {
                    cancelButton
                    Spacer()
                    if !model.viewModel.audioOnly {
                        switchCameraButton
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                recordingTimerBadge
                    .opacity(model.isRecording ? 1 : 0)
                    .scaleEffect(model.isRecording ? 1 : 0.7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.isRecording)
            }

            // Second row: file name + send button — slides in when ready to send
            if model.isReadyToSend {
                sendRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.isReadyToSend)
    }

    private var sendRow: some View {
        HStack(spacing: 12) {
            Image(systemName: model.viewModel.audioOnly ? "waveform" : "video.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Text(URL(fileURLWithPath: model.viewModel.fileName).lastPathComponent)
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
            model.viewModel.sendFile()
        } label: {
            HStack(spacing: 6) {
                Text(L10n.DataTransfer.sendMessage)
                    .font(.system(size: 15, weight: .semibold))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
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
            model.viewModel.cancel()
        } label: {
            glassLabel(text: L10n.Global.cancel)
        }
    }

    private var switchCameraButton: some View {
        Button {
            model.viewModel.switchCamera()
        } label: {
            glassIcon(systemName: "arrow.triangle.2.circlepath.camera")
        }
    }

    private var recordingTimerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            // Fixed min-width prevents the capsule from resizing as digits change
            Text(model.recordDuration.isEmpty ? "00:00" : model.recordDuration)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
                .frame(minWidth: 44, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .darkCapsuleBackground()
    }

    // MARK: Audio-only Content

    @ViewBuilder
    private var audioOnlyContent: some View {
        VStack(spacing: 24) {
            if !model.hideInfo {
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
            if model.isRecording {
                AudioWaveformView(isAnimating: model.isRecording)
                    .frame(height: 80)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundColor(model.isReadyToSend ? .green : .secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.isRecording)
    }

    // MARK: Player Controls

    private var playerControlsPanel: some View {
        VStack(spacing: 16) {
            // Seek slider — full width, white track
            SeekSlider(
                position: model.playerPosition,
                onSeekStart: { [weak model] in
                    model?.viewModel.userStartSeeking()
                },
                onSeekChange: { [weak model] value in
                    model?.viewModel.seekTimeVariable.accept(value)
                },
                onSeekEnd: { [weak model] in
                    model?.viewModel.userStopSeeking()
                }
            )
            .padding(.horizontal, 4)

            // Controls row: duration | play/pause | mute
            ZStack {
                // Play/pause centered
                playPauseButton

                HStack {
                    // Duration on the left
                    durationText
                    Spacer()
                    // Mute on the right
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
            model.viewModel.togglePause()
        } label: {
            Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .darkCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var muteButton: some View {
        Button {
            model.viewModel.muteAudio()
        } label: {
            Image(systemName: model.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .darkCircleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var durationText: some View {
        Text(model.durationString(microseconds: model.playerDuration))
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
            model.viewModel.triggerRecording()
        } label: {
            RecordButtonLabel(isRecording: model.isRecording)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Glass Helpers

    private func glassLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .darkCapsuleBackground()
    }

    private func glassIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .darkCircleBackground()
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

/// UISlider wrapper so we can set both track colors explicitly.
/// The filled track is solid white; the unfilled track is white at 35% opacity —
/// clearly visible on the dark panel background.
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

// MARK: - Dark Background Helpers

private extension View {
    /// Dark semi-transparent background for icon/round buttons.
    func darkCircleBackground() -> some View {
        self.background(Circle().fill(Color.black.opacity(0.55)))
    }

    /// Dark semi-transparent rounded background for panels and bars.
    func darkRoundedBackground(cornerRadius: CGFloat = 20) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    /// Dark semi-transparent capsule background for label/pill buttons.
    func darkCapsuleBackground(tint: Color = .clear) -> some View {
        self.background(
            Capsule().fill(tint == .clear ? Color.black.opacity(0.55) : tint.opacity(0.7))
        )
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
