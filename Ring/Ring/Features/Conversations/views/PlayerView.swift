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
    let text: Color
    let control: Color
    let controlIcon: Color
    let progress: Color
    let time: Color

    func withoutBackground() -> AudioMessageColors {
        AudioMessageColors(background: .clear, text: text, control: control, controlIcon: controlIcon,
                           progress: progress, time: time)
    }
}

enum AudioMessageLayout {
    static let height: CGFloat = 48
    static let controlSize: CGFloat = 34
    static let controlTapSize: CGFloat = 44
    static let progressGap: CGFloat = 5
    static let progressTextInset: CGFloat = 3
    static let trailingInset = MessageContentVM.bubbleTextInset

    static var edgeInset: CGFloat {
        (height - controlSize) / 2
    }

    static var controlTapSlack: CGFloat {
        (controlTapSize - controlSize) / 2
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
                    self.sliderUpdate?(position)
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

struct AudioSeekAreaKey: PreferenceKey {
    static let coordinateSpace = "audioSeekArea"
    static var defaultValue: CGRect = .null

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isNull { value = next }
    }
}

struct PlayerView: View {
    var viewModel: PlayerViewModel
    var sizeMode: PlayerMode
    var withControls: Bool
    var externalControlsVisible: Binding<Bool>?
    var fullScreenActions: AnyView?
    var onVideoTap: ((_ frame: CGRect, _ frameProvider: @escaping () -> CGRect) -> Void)?
    var onVideoLongPress: (() -> Void)?
    var audioColors = AudioMessageColors(background: Color(UIColor.placeholderText),
                                         text: Color.white.opacity(0.85),
                                         control: .white,
                                         controlIcon: Color(UIColor.placeholderText),
                                         progress: Color.white.opacity(0.22),
                                         time: Color.white.opacity(0.8))
    var messageTime: String?

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
                HStack(spacing: 8) {
                    Spacer()
                    if let actions = fullScreenActions {
                        actions
                    }
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

    private func playPauseButton(_ style: PlayButtonStyle) -> some View {
        glassPlayPauseButton(isPaused: coordinator.isPaused, iconSize: style.iconSize, size: style.buttonSize) {
            viewModel.togglePause()
            if style.autoHide { coordinator.scheduleAutoHide() }
        }
    }

    private var playPauseIcon: String {
        coordinator.isPaused ? "play.fill" : "pause.fill"
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
        glassIconButton(systemName: muteIcon, accessibilityLabel: muteAccessibilityLabel) {
            viewModel.muteAudio()
            coordinator.scheduleAutoHide()
        }
    }

    private var fullScreenTray: some View {
        MediaScrubberRow(elapsed: coordinator.elapsedTimeString, duration: coordinator.duration.durationString) {
            seekSlider()
        }
        .mediaTrayStyle()
    }

    private func seekSlider() -> some View {
        MediaSeekSlider(
            onRegister: { sink in coordinator.sliderUpdate = sink },
            onSeekStart: { beginSeek(autoHide: true) },
            onSeekChange: { newValue in changeSeek(to: newValue) },
            onSeekEnd: { endSeek(autoHide: true) }
        )
    }

    private func beginSeek(autoHide: Bool) {
        if autoHide { coordinator.cancelAutoHide() }
        coordinator.isSeeking = true
        viewModel.userStartSeeking()
        viewModel.seekTimeVariable.accept(coordinator.progress)
    }

    private func changeSeek(to newValue: Float) {
        coordinator.progress = newValue
        coordinator.updateElapsedTime()
        if coordinator.isSeeking {
            viewModel.seekTimeVariable.accept(newValue)
        }
    }

    private func endSeek(autoHide: Bool) {
        coordinator.isSeeking = false
        viewModel.seekTimeVariable.accept(coordinator.progress)
        viewModel.userStopSeeking()
        if autoHide { coordinator.scheduleAutoHide() }
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
            videoMessageChrome
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

    private var videoMessageChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(coordinator.elapsedTimeString) / \(coordinator.duration.durationString)")
                    .font(.footnote.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Spacer()
                if let messageTime = messageTime {
                    MessageTimeCapsule(text: messageTime)
                }
            }
            .frame(height: 44)
            Spacer()
            seekSlider()
        }
        .padding(.horizontal, 16)
    }

    // MARK: Audio-Only In-Message Controls

    private var audioMessageControls: some View {
        ZStack {
            if let onVideoLongPress = onVideoLongPress {
                Color.clear
                    .contentShape(Rectangle())
                    .messageGesture(onLongPress: onVideoLongPress)
            }
            HStack(spacing: 0) {
                audioPlayPauseButton
                    .padding(.leading, AudioMessageLayout.edgeInset - AudioMessageLayout.controlTapSlack)
                audioSeekArea
                    .padding(.leading, AudioMessageLayout.progressGap - AudioMessageLayout.controlTapSlack)
                if let messageTime = messageTime {
                    MessageTimeView(text: messageTime, color: audioColors.time)
                        .padding(.leading, AudioMessageLayout.progressGap)
                }
            }
            .padding(.trailing, AudioMessageLayout.trailingInset)
        }
    }

    private var audioSeekArea: some View {
        ZStack(alignment: .leading) {
            MediaSeekFill(color: audioColors.progress,
                          cornerRadius: 8,
                          isEnabled: !coordinator.playbackFailed,
                          onRegister: { sink in coordinator.sliderUpdate = sink },
                          onSeekStart: { beginSeek(autoHide: false) },
                          onSeekChange: { newValue in changeSeek(to: newValue) },
                          onSeekEnd: { endSeek(autoHide: false) },
                          onLongPress: onVideoLongPress)
            Text(coordinator.audioTimeString)
                .font(.footnote.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(audioColors.text)
                .lineLimit(1)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.leading, AudioMessageLayout.progressTextInset)
                .allowsHitTesting(false)
        }
        .frame(maxHeight: .infinity)
        .background(GeometryReader { proxy in
            Color.clear.preference(key: AudioSeekAreaKey.self,
                                   value: messageTime == nil ? .null : proxy.frame(in: .named(AudioSeekAreaKey.coordinateSpace)))
        })
    }

    private var audioPlayPauseButton: some View {
        Image(systemName: audioButtonIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(audioColors.controlIcon)
            .frame(width: AudioMessageLayout.controlSize, height: AudioMessageLayout.controlSize)
            .background(Circle().fill(audioColors.control))
            .frame(width: AudioMessageLayout.controlTapSize, height: AudioMessageLayout.controlTapSize)
            .contentShape(Circle())
            .onTapGesture {
                guard !coordinator.playbackFailed else { return }
                viewModel.togglePause()
            }
    }

    private var audioButtonIcon: String {
        coordinator.playbackFailed ? "exclamationmark" : playPauseIcon
    }

}
