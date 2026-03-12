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
            if model.showPlayerControls {
                playerControlsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
            bottomBar
        }
        .animation(.easeInOut(duration: 0.25), value: model.showPlayerControls)
        .animation(.easeInOut(duration: 0.25), value: model.isReadyToSend)
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            cancelButton
            Spacer()
            if model.isRecording {
                recordingTimerBadge
            }
            Spacer()
            // Always reserve space on the trailing side to keep cancel button left-aligned
            // and the timer centred; hide switch button when not applicable
            if !model.viewModel.audioOnly && !model.isReadyToSend {
                switchCameraButton
            } else {
                // Invisible placeholder matching switch button size
                Color.clear
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
            Text(model.recordDuration)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassBackground(shape: Capsule())
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
        VStack(spacing: 12) {
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
            HStack(spacing: 32) {
                muteButton
                playPauseButton
                durationText
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .glassBackground(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var playPauseButton: some View {
        Button {
            model.viewModel.togglePause()
        } label: {
            Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .glassBackground(shape: Circle())
        }
    }

    private var muteButton: some View {
        Button {
            model.viewModel.muteAudio()
        } label: {
            Image(systemName: model.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassBackground(shape: Circle())
        }
    }

    private var durationText: some View {
        Text(model.durationString(microseconds: model.playerDuration))
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(minWidth: 60, alignment: .leading)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack {
            Spacer()
            recordButton
            Spacer()
        }
        .overlay(
            Group {
                if model.isReadyToSend {
                    sendButton
                        .transition(.scale.combined(with: .opacity))
                }
            },
            alignment: .trailing
        )
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: model.isReadyToSend)
    }

    private var recordButton: some View {
        Button {
            model.viewModel.triggerRecording()
        } label: {
            RecordButtonLabel(isRecording: model.isRecording, isReadyToSend: model.isReadyToSend)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var sendButton: some View {
        Button {
            model.viewModel.sendFile()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text(L10n.DataTransfer.sendMessage)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glassBackground(shape: Capsule(), tint: Color.jamiColor.opacity(0.4))
        }
    }

    // MARK: Glass Helpers

    private func glassLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassBackground(shape: Capsule())
    }

    private func glassIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .glassBackground(shape: Circle())
    }
}

// MARK: - Record Button Label

private struct RecordButtonLabel: View {
    let isRecording: Bool
    let isReadyToSend: Bool

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
                    .frame(width: isReadyToSend ? 32 : 48, height: isReadyToSend ? 32 : 48)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isReadyToSend)
            }
        }
        .frame(width: 72, height: 72)
        .glassBackground(shape: Circle())
    }
}

// MARK: - Seek Slider

private struct SeekSlider: View {
    let position: Float
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    @SwiftUI.State private var isSeeking: Bool = false

    var body: some View {
        Slider(
            value: Binding(
                get: { position },
                set: { newValue in
                    if !isSeeking {
                        isSeeking = true
                        onSeekStart()
                    }
                    onSeekChange(newValue)
                }
            ),
            in: 0...1
        )
        .accentColor(.white)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isSeeking {
                        isSeeking = false
                        onSeekEnd()
                    }
                }
        )
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

// MARK: - Glass Background ViewModifier

private struct GlassBackgroundModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color = .clear

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(
                    ZStack {
                        VisualEffect(style: .systemUltraThinMaterialDark, withVibrancy: false)
                        tint.blendMode(.normal)
                        Color.white.opacity(0.06)
                    }
                    .clipShape(shape)
                )
                .overlay(
                    shape.stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .clipShape(shape)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
}

private extension View {
    func glassBackground<S: Shape>(shape: S, tint: Color = .clear) -> some View {
        modifier(GlassBackgroundModifier(shape: shape, tint: tint))
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
