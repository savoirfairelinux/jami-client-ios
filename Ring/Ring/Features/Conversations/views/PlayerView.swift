/*
 * Copyright (C) 2020-2026 Savoir-faire Linux Inc.
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
import AVFoundation

enum PlayerMode {
    case fullScreen
    case inConversationMessage
}

enum PlayButtonStyle {
    case fullScreen
    case videoMessage
    case audioMessage

    var iconSize: CGFloat {
        switch self {
        case .fullScreen: return 48
        case .videoMessage: return 28
        case .audioMessage: return 18
        }
    }

    var buttonSize: CGFloat {
        switch self {
        case .fullScreen: return 84
        case .videoMessage: return 52
        case .audioMessage: return 44
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .fullScreen, .videoMessage: return .medium
        case .audioMessage: return .semibold
        }
    }

    var autoHide: Bool {
        self == .fullScreen
    }
}

// MARK: - Player State Coordinator

/// Manages the AVSampleBufferDisplayLayer and RxSwift subscriptions.
class PlayerCoordinator: ObservableObject {
    let displayLayer = AVSampleBufferDisplayLayer()
    private var disposeBag = DisposeBag()
    private weak var boundViewModel: PlayerViewModel?
    weak var pendingViewModel: PlayerViewModel?

    @Published var isPaused: Bool = true
    @Published var isMuted: Bool = true
    @Published var duration: Float = 0
    @Published var hasVideo: Bool = true
    @Published var controlsVisible: Bool = true
    @Published var fileName: String = ""

    private var autoHideTask: DispatchWorkItem?

    func scheduleAutoHide() {
        autoHideTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.controlsVisible = false
            }
        }
        autoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
    }

    func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    var progress: Float = 0
    @Published var elapsedTimeString: String = "00:00"
    var sliderUpdate: ((Float) -> Void)?

    private var lastBuffer: CMSampleBuffer?
    var isSeeking: Bool = false

    init() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.isOpaque = true
    }

    func configureForFullScreen() {
        displayLayer.videoGravity = .resizeAspectFill
    }

    private var lastElapsedString: String = "00:00"

    func updateElapsedTime() {
        let newString = Float.elapsedString(progress: progress, duration: duration)
        if newString != lastElapsedString {
            lastElapsedString = newString
            elapsedTimeString = newString
        }
    }

    func enqueueBuffer(_ buffer: CMSampleBuffer) {
        lastBuffer = buffer
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    func redisplayLastBuffer() {
        guard let buffer = lastBuffer else { return }
        displayLayer.flush()
        displayLayer.enqueue(buffer)
    }

    func bindIfNeeded() {
        guard let viewModel = pendingViewModel else { return }
        bind(to: viewModel)
    }

    func bind(to viewModel: PlayerViewModel) {
        if boundViewModel === viewModel {
            viewModel.createPlayer()
            return
        }

        disposeBag = DisposeBag()
        boundViewModel = viewModel

        // Seed coordinator state from the view model's current values
        // so the UI shows the correct layout immediately.
        hasVideo = viewModel.hasVideo.value
        isPaused = viewModel.pause.value
        isMuted = viewModel.audioMuted.value
        fileName = viewModel.fileName

        viewModel.playBackFrame
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self, let buffer = buffer else { return }
                self.enqueueBuffer(buffer)
            })
            .disposed(by: disposeBag)

        viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                guard let self = self else { return }
                if !self.isSeeking {
                    self.progress = position
                    self.sliderUpdate?(position)
                    self.updateElapsedTime()
                }
            })
            .disposed(by: disposeBag)

        viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                self?.duration = value
            })
            .disposed(by: disposeBag)

        viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                self?.isPaused = value
            })
            .disposed(by: disposeBag)

        viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                self?.isMuted = value
            })
            .disposed(by: disposeBag)

        viewModel.hasVideo
            .asObservable()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] value in
                self?.hasVideo = value
            })
            .disposed(by: disposeBag)

        viewModel.createPlayer()
    }
}

// MARK: - Video Layer View

/// Renders video frames via AVSampleBufferDisplayLayer.
struct VideoLayerView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer
    let coordinator: PlayerCoordinator

    func makeUIView(context: Context) -> UIView {
        let view = VideoLayerUIView(displayLayer: displayLayer, coordinator: coordinator)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.layer.addSublayer(displayLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = uiView.bounds
        CATransaction.commit()
    }
}

/// UIView subclass that detects when layout completes and when the view
/// enters a window, so the coordinator can bind and display the first frame.
final class VideoLayerUIView: UIView {
    private let displayLayer: AVSampleBufferDisplayLayer
    private weak var coordinator: PlayerCoordinator?
    private var didRedisplay = false

    init(displayLayer: AVSampleBufferDisplayLayer, coordinator: PlayerCoordinator) {
        self.displayLayer = displayLayer
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            coordinator?.bindIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
        if !didRedisplay && bounds.width > 0 && bounds.height > 0 {
            didRedisplay = true
            coordinator?.redisplayLastBuffer()
        }
    }
}

// MARK: - PlayerView

struct PlayerView: View {

    var viewModel: PlayerViewModel
    var sizeMode: PlayerMode
    var withControls: Bool
    var externalControlsVisible: Binding<Bool>?

    /// Called when the video area (not a control) is tapped in message mode.
    /// Receives the view's global frame for the expand animation.
    var onVideoTap: ((CGRect) -> Void)?
    /// Called on long press in the video area (e.g. to show context menu).
    var onVideoLongPress: (() -> Void)?

    @StateObject private var coordinator = PlayerCoordinator()

    private var controlsVisible: Bool {
        externalControlsVisible?.wrappedValue ?? coordinator.controlsVisible
    }

    private func toggleControls() {
        if let binding = externalControlsVisible {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                binding.wrappedValue.toggle()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                coordinator.controlsVisible.toggle()
            }
            if coordinator.controlsVisible {
                coordinator.scheduleAutoHide()
            }
        }
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea(edges: sizeMode == .fullScreen ? .all : [])
            depthOverlay
                .allowsHitTesting(false)

            if coordinator.hasVideo {
                VideoLayerView(displayLayer: coordinator.displayLayer, coordinator: coordinator)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            videoTapLayer

            if withControls {
                controlsOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .applyFullScreenTapGesture(
            isFullScreen: sizeMode == .fullScreen,
            onTap: toggleControls
        )
        .onAppear {
            if sizeMode == .fullScreen {
                coordinator.configureForFullScreen()
            }
            coordinator.pendingViewModel = viewModel
            coordinator.bind(to: viewModel)
            if sizeMode == .fullScreen && externalControlsVisible == nil {
                coordinator.scheduleAutoHide()
            }
        }
        .onDisappear {
            coordinator.cancelAutoHide()
        }
        .onChange(of: externalControlsVisible?.wrappedValue) { newValue in
            guard let newValue else { return }
            coordinator.controlsVisible = newValue
        }
    }

    private var backgroundColor: Color {
        if sizeMode == .fullScreen { return .black }
        return Color(red: 0.22, green: 0.23, blue: 0.25)
    }

    @ViewBuilder
    private var depthOverlay: some View {
        if sizeMode != .fullScreen, !coordinator.hasVideo {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06),
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.clear
        }
    }

    @ViewBuilder private var videoTapLayer: some View {
        if let onVideoTap = onVideoTap, coordinator.hasVideo {
            Color.clear
                .contentShape(Rectangle())
                .messageGesture(
                    onLongPress: { onVideoLongPress?() },
                    onTap: onVideoTap
                )
        }
    }

    // MARK: - Controls Overlay

    @ViewBuilder private var controlsOverlay: some View {
        if sizeMode == .fullScreen {
            fullScreenControls
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: controlsVisible)
        } else {
            messageControls
        }
    }

    @ViewBuilder private var fullScreenControls: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                ZStack {
                    centerPlayButton
                    VStack {
                        Spacer()
                        fullScreenBottomBar
                    }
                }
            }
        } else {
            ZStack {
                centerPlayButton
                VStack {
                    Spacer()
                    fullScreenBottomBar
                }
            }
        }
    }

    // MARK: - Unified Play/Pause Button

    @ViewBuilder
    private func playPauseButton(_ style: PlayButtonStyle) -> some View {
        if #available(iOS 26, *) {
            Button(action: {
                viewModel.togglePause()
                if style.autoHide { coordinator.scheduleAutoHide() }
            }, label: {
                Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: style.iconSize, weight: style.fontWeight))
                    .foregroundColor(.white)
            })
            .frame(width: style.buttonSize, height: style.buttonSize)
            .glassEffect(.clear.interactive(), in: .circle)
        } else {
            Button(action: {
                viewModel.togglePause()
                if style.autoHide { coordinator.scheduleAutoHide() }
            }, label: {
                Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: style.iconSize, weight: style.fontWeight))
                    .foregroundColor(.white)
                    .frame(width: style.buttonSize, height: style.buttonSize)
                    .contentShape(Rectangle())
            })
            .background(clearGlassHighlightBackground(shape: Circle()))
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var centerPlayButton: some View {
        playPauseButton(.fullScreen)
    }

    @ViewBuilder private var fullScreenBottomBar: some View {
        VStack(spacing: 10) {
            // Row 1: Time capsule + audio circle button
            HStack(spacing: 10) {
                Text("\(coordinator.elapsedTimeString) / \(coordinator.duration.durationString)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glassCapsuleBackground()

                Spacer()

                Button(action: {
                    viewModel.muteAudio()
                    coordinator.scheduleAutoHide()
                }, label: {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                })
                .glassCircleBackground()
            }

            // Row 2: Slider in capsule
            seekSlider(autoHide: true, thumbSize: 18)
                .padding(.horizontal, 16)
                .frame(height: 60)
                .glassCapsuleBackground()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func seekSlider(autoHide: Bool, trackColor: Color = .white, thumbSize: CGFloat = 14) -> some View {
        MediaSeekSlider(
            trackColor: trackColor,
            thumbSize: thumbSize,
            onRegister: { sink in coordinator.sliderUpdate = sink },
            onSeekStart: {
                if autoHide { coordinator.cancelAutoHide() }
                coordinator.isSeeking = true
                viewModel.userStartSeeking()
                viewModel.seekTimeVariable.accept(coordinator.progress)
            },
            onSeekChange: { newValue in
                coordinator.progress = newValue
                coordinator.updateElapsedTime()
                if coordinator.isSeeking {
                    viewModel.seekTimeVariable.accept(newValue)
                }
            },
            onSeekEnd: {
                coordinator.isSeeking = false
                viewModel.seekTimeVariable.accept(coordinator.progress)
                viewModel.userStopSeeking()
                if autoHide { coordinator.scheduleAutoHide() }
            }
        )
    }

}

// MARK: - In-Message Controls

extension PlayerView {
    @ViewBuilder var messageControls: some View {
        if coordinator.hasVideo {
            videoMessageControls
        } else {
            audioMessageControls
        }
    }

    // MARK: Video In-Message Controls

    @ViewBuilder private var videoMessageControls: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                ZStack {
                    videoMessageGradient
                    videoMessagePlayButton
                    videoMessageTopBar
                    videoMessageBottomBar
                }
            }
        } else {
            ZStack {
                videoMessageGradient
                videoMessagePlayButton
                videoMessageTopBar
                videoMessageBottomBar
            }
        }
    }

    private var videoMessageGradient: some View {
        VStack {
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 48)
            Spacer()
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private var videoMessagePlayButton: some View {
        playPauseButton(.videoMessage)
    }

    private var videoMessageTopBar: some View {
        VStack {
            HStack(alignment: .center) {
                Text("\(coordinator.elapsedTimeString) / \(coordinator.duration.durationString)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { viewModel.muteAudio() }, label: {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                })
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            Spacer()
        }
    }

    private var videoMessageBottomBar: some View {
        VStack {
            Spacer()
            seekSlider(autoHide: true)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
    }

    // MARK: Audio-Only In-Message Controls

    @ViewBuilder private var audioMessageControls: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer {
                audioMessageControlsContent
            }
        } else {
            audioMessageControlsContent
        }
    }

    private var audioMessageControlsContent: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Row 1: Audio icon + file name
            if !coordinator.fileName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(coordinator.fileName)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            // Row 2: Time labels + Row 3: Play button + slider
            // Grouped with tight spacing so the time feels connected to the slider.
                HStack(alignment: .bottom, spacing: 8) {
                    audioPlayPauseButton
                    VStack (alignment: .trailing, spacing: 4) {
                        Text("\(coordinator.elapsedTimeString) / \(coordinator.duration.durationString)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        seekSlider(autoHide: false, trackColor: .white)
                            .frame(maxWidth: .infinity)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .applyAudioLongPress(onVideoLongPress)
    }

    private var audioPlayPauseButton: some View {
        playPauseButton(.audioMessage)
            .accessibilityLabel(coordinator.isPaused
                                ? L10n.Accessibility.audioPlayerPlay
                                : L10n.Accessibility.audioPlayerPause)
    }

}

// MARK: - View Helpers

private extension View {
    @ViewBuilder
    func applyFullScreenTapGesture(isFullScreen: Bool, onTap: @escaping () -> Void) -> some View {
        if isFullScreen {
            self
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        } else {
            self
        }
    }

    /// Conditionally attaches the long-press gesture used by audio message
    /// cells. Uses `messageGesture` (which respects `suppressLongPress` and
    /// `contextMenuActive` guards) but applies it on the container so it
    /// doesn't compete with child Button tap gestures.
    @ViewBuilder
    func applyAudioLongPress(_ onLongPress: (() -> Void)?) -> some View {
        if let onLongPress = onLongPress {
            self.messageGesture(onLongPress: onLongPress)
        } else {
            self
        }
    }
}

