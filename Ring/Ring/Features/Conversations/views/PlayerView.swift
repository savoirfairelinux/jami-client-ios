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

    var iconSize: CGFloat {
        switch self {
        case .fullScreen: return 34
        case .videoMessage: return 21
        }
    }

    var buttonSize: CGFloat {
        switch self {
        case .fullScreen: return 84
        case .videoMessage: return 52
        }
    }

    var autoHide: Bool {
        self == .fullScreen
    }
}

struct AudioMessageColors {
    let background: Color
    let foreground: Color
    let control: Color
    let controlBackground: Color
}

// MARK: - Player State Coordinator

final class PlaybackProgress: ObservableObject {
    @Published var value: Float = 0
}

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
    @Published var playbackFailed: Bool = false

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

    let playback = PlaybackProgress()
    var progress: Float = 0 {
        didSet { playback.value = progress }
    }
    @Published var elapsedTimeString: String = String.compactDurationFormatted(seconds: 0)

    private var lastBuffer: CMSampleBuffer?
    var isSeeking: Bool = false

    init() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.isOpaque = true
    }

    func configureForFullScreen() {
        displayLayer.videoGravity = .resizeAspectFill
    }

    func updateElapsedTime() {
        let newString = Float.elapsedString(progress: progress, duration: duration)
        if newString != elapsedTimeString {
            elapsedTimeString = newString
        }
    }

    var audioTimeString: String {
        guard duration > 0 else { return "--:--" }
        return isPaused && progress == 0 ? duration.durationString : elapsedTimeString
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
        playbackFailed = viewModel.playbackFailed.value

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
                    self.updateElapsedTime()
                }
            })
            .disposed(by: disposeBag)

        viewModel.playerDuration
            .asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in
                self?.duration = value
            })
            .disposed(by: disposeBag)

        viewModel.pause
            .asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in
                self?.isPaused = value
            })
            .disposed(by: disposeBag)

        viewModel.audioMuted
            .asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in
                self?.isMuted = value
            })
            .disposed(by: disposeBag)

        viewModel.hasVideo
            .asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in
                self?.hasVideo = value
            })
            .disposed(by: disposeBag)

        viewModel.playbackFailed
            .asObservable()
            .observe(on: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] value in
                self?.playbackFailed = value
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
    var fullScreenActions: AnyView?
    var onVideoTap: ((_ frame: CGRect, _ frameProvider: @escaping () -> CGRect) -> Void)?
    var onVideoLongPress: (() -> Void)?
    var audioColors = AudioMessageColors(background: Color(UIColor.placeholderText),
                                         foreground: .white,
                                         control: .white,
                                         controlBackground: Color.white.opacity(0.22))

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

            if coordinator.hasVideo {
                VideoLayerView(displayLayer: coordinator.displayLayer, coordinator: coordinator)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            videoTapLayer

            // Full-screen tap layer sits below the controls so buttons remain tappable.
            if sizeMode == .fullScreen {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { toggleControls() }
            }

            if withControls {
                controlsOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        return coordinator.hasVideo ? Color(UIColor.placeholderText) : audioColors.background
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
                .allowsHitTesting(controlsVisible)
                .animation(.easeInOut(duration: 0.3), value: controlsVisible)
        } else {
            messageControls
        }
    }

    private var fullScreenControls: some View {
        let insets = UIWindow.currentSafeAreaInsets
        return ZStack {
            centerPlayButton
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    fullScreenMuteButton
                }
                .padding(.top, insets.top)
                Spacer()
                fullScreenTray
                    .padding(.bottom, insets.bottom + 16)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Unified Play/Pause Button

    @ViewBuilder
    private func playPauseButton(_ style: PlayButtonStyle) -> some View {
        let button = Button(action: {
            viewModel.togglePause()
            if style.autoHide { coordinator.scheduleAutoHide() }
        }, label: {
            Image(systemName: playPauseIcon)
                .font(.system(size: style.iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: style.buttonSize, height: style.buttonSize)
                .contentShape(Circle())
        })
        .accessibilityLabel(playPauseAccessibilityLabel)
        if #available(iOS 26, *) {
            button.glassEffect(.clear.interactive(), in: .circle)
        } else {
            button
                .glassCircleBackground()
                .buttonStyle(ScaleButtonStyle())
        }
    }

    private var playPauseIcon: String {
        coordinator.isPaused ? "play.fill" : "pause.fill"
    }

    private var playPauseAccessibilityLabel: String {
        coordinator.isPaused ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause
    }

    private var muteIcon: String {
        coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }

    private var muteAccessibilityLabel: String {
        coordinator.isMuted ? L10n.Accessibility.audioPlayerUnmute : L10n.Accessibility.audioPlayerMute
    }

    private var centerPlayButton: some View {
        playPauseButton(.fullScreen)
    }

    private var fullScreenMuteButton: some View {
        Button(action: {
            viewModel.muteAudio()
            coordinator.scheduleAutoHide()
        }, label: {
            Image(systemName: muteIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassCircleBackground()
        })
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(muteAccessibilityLabel)
    }

    private var fullScreenTray: some View {
        VStack(spacing: 12) {
            FullScreenScrubberRow(
                playback: coordinator.playback,
                duration: coordinator.duration,
                onSeekStart: { startSeeking(autoHide: true) },
                onSeekChange: seek(to:),
                onSeekEnd: { stopSeeking(autoHide: true) }
            )
            if let actions = fullScreenActions {
                actions
            }
        }
        .mediaTrayStyle()
    }

    private func seekScrubber(autoHide: Bool, color: Color = .white) -> some View {
        PlaybackScrubber(
            playback: coordinator.playback,
            duration: coordinator.duration,
            color: color,
            onSeekStart: { startSeeking(autoHide: autoHide) },
            onSeekChange: seek(to:),
            onSeekEnd: { stopSeeking(autoHide: autoHide) }
        )
    }

    private func startSeeking(autoHide: Bool) {
        if autoHide { coordinator.cancelAutoHide() }
        coordinator.isSeeking = true
        viewModel.userStartSeeking()
        viewModel.seekTimeVariable.accept(coordinator.progress)
    }

    private func seek(to value: Float) {
        coordinator.progress = value
        coordinator.updateElapsedTime()
        viewModel.seekTimeVariable.accept(value)
    }

    private func stopSeeking(autoHide: Bool) {
        coordinator.isSeeking = false
        viewModel.seekTimeVariable.accept(coordinator.progress)
        viewModel.userStopSeeking()
        if autoHide { coordinator.scheduleAutoHide() }
    }

}

private struct FullScreenScrubberRow: View {
    @ObservedObject var playback: PlaybackProgress
    let duration: Float
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    var body: some View {
        let seconds = TimeInterval(duration / 1_000_000)
        MediaScrubberRow(progress: playback.value,
                         elapsed: seconds * TimeInterval(playback.value),
                         duration: seconds,
                         onSeekStart: onSeekStart,
                         onSeekChange: onSeekChange,
                         onSeekEnd: onSeekEnd)
    }
}

private struct PlaybackScrubber: View {
    @ObservedObject var playback: PlaybackProgress
    let duration: Float
    let color: Color
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    var body: some View {
        let elapsed = TimeInterval(duration / 1_000_000) * TimeInterval(playback.value)
        MediaScrubber(progress: playback.value,
                      accessibilityValue: String.compactDurationFormatted(seconds: elapsed),
                      trackColor: color.opacity(0.35),
                      fillColor: color.opacity(0.7),
                      activeFillColor: color,
                      requiresHorizontalDrag: true,
                      onSeekStart: onSeekStart,
                      onSeekChange: onSeekChange,
                      onSeekEnd: onSeekEnd)
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

    private var videoMessageControls: some View {
        ZStack {
            videoMessageGradient
            videoMessagePlayButton
            videoMessageTopBar
            videoMessageBottomBar
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
                    Image(systemName: muteIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                })
                .accessibilityLabel(muteAccessibilityLabel)
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
            Spacer()
        }
    }

    private var videoMessageBottomBar: some View {
        VStack {
            Spacer()
            seekScrubber(autoHide: true)
                .frame(height: 44)
                .padding(.horizontal, 10)
        }
    }

    // MARK: Audio-Only In-Message Controls

    private var audioMessageControls: some View {
        ZStack {
            if let onVideoLongPress = onVideoLongPress {
                Color.clear
                    .contentShape(Rectangle())
                    .messageGesture(onLongPress: onVideoLongPress)
            }
            HStack(spacing: 10) {
                audioPlayPauseButton
                seekScrubber(autoHide: false, color: audioColors.control)
                    .frame(height: 44)
                    .disabled(coordinator.playbackFailed)
                Text(coordinator.audioTimeString)
                    .font(.footnote.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(audioColors.foreground.opacity(0.85))
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(minWidth: 34, alignment: .trailing)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
        }
    }

    private var audioPlayPauseButton: some View {
        Button(action: { viewModel.togglePause() }, label: {
            Image(systemName: audioButtonIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(audioColors.control)
                .frame(width: 44, height: 44)
                .background(Circle().fill(audioColors.controlBackground))
                .contentShape(Circle())
        })
        .buttonStyle(ScaleButtonStyle())
        .disabled(coordinator.playbackFailed)
    }

    private var audioButtonIcon: String {
        coordinator.playbackFailed ? "exclamationmark" : playPauseIcon
    }

}
