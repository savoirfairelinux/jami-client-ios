/*
 * Copyright (C) 2020-2025 Savoir-faire Linux Inc.
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

// MARK: - Player State Coordinator

/// Manages the AVSampleBufferDisplayLayer and RxSwift subscriptions.
/// Using a class with @StateObject ensures these survive SwiftUI view re-creation.
class PlayerCoordinator: ObservableObject {
    let displayLayer = AVSampleBufferDisplayLayer()
    private var disposeBag = DisposeBag()
    private weak var boundViewModel: PlayerViewModel?
    /// The view model to bind to, set from PlayerView and used by
    /// VideoLayerUIView.didMoveToWindow for reliable binding in lazy containers.
    weak var pendingViewModel: PlayerViewModel?

    @Published var isPaused: Bool = true
    @Published var isMuted: Bool = true
    @Published var duration: Float = 0
    @Published var hasVideo: Bool = true
    @Published var controlsVisible: Bool = true

    /// Auto-hide work item for controls. Lives on the coordinator (class)
    /// so it can be mutated freely from closures.
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

    /// Progress is updated ~10x/sec by the timer. Not @Published to avoid
    /// triggering full SwiftUI body re-evaluation on every tick.
    /// The UISlider is updated directly via `sliderUpdate` closure.
    var progress: Float = 0
    var sliderUpdate: ((Float) -> Void)?

    /// The most recent buffer, kept so we can re-enqueue after layout or error recovery.
    private var lastBuffer: CMSampleBuffer?
    var isSeeking: Bool = false

    init() {
        displayLayer.videoGravity = .resizeAspect
        displayLayer.isOpaque = true
    }

    func configureForFullScreen() {
        displayLayer.videoGravity = .resizeAspectFill
    }

    /// Enqueue a sample buffer on the display layer, handling flush/error recovery.
    func enqueueBuffer(_ buffer: CMSampleBuffer, rotation: Int = 0) {
        lastBuffer = buffer
        applyRotation(rotation)
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    /// Apply rotation degrees to the display layer transform.
    private func applyRotation(_ degrees: Int) {
        guard degrees != currentRotation else { return }
        currentRotation = degrees
        let radians = CGFloat(degrees) * .pi / 180
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.setAffineTransform(CGAffineTransform(rotationAngle: radians))
        CATransaction.commit()
    }

    private var currentRotation: Int = 0

    /// Re-enqueue the last buffer (e.g. after the layer is laid out for the first time).
    func redisplayLastBuffer() {
        guard let buffer = lastBuffer else { return }
        let radians = CGFloat(currentRotation) * .pi / 180
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.setAffineTransform(CGAffineTransform(rotationAngle: radians))
        CATransaction.commit()
        displayLayer.flush()
        displayLayer.enqueue(buffer)
    }

    /// Called from didMoveToWindow — reliable UIKit lifecycle callback that
    /// fires every time the view appears on screen, even in lazy containers.
    func bindIfNeeded() {
        guard let viewModel = pendingViewModel else { return }
        bind(to: viewModel)
    }

    /// Safe to call multiple times — mirrors the old willMove(toWindow:) behavior.
    func bind(to viewModel: PlayerViewModel) {
        if boundViewModel === viewModel {
            // Already bound to this VM — just re-trigger createPlayer
            // which re-emits firstFrame if player already exists (old behavior).
            viewModel.createPlayer()
            return
        }

        // New view model — reset subscriptions
        disposeBag = DisposeBag()
        boundViewModel = viewModel

        viewModel.playBackFrame
            .subscribe(onNext: { [weak self, weak viewModel] buffer in
                guard let self = self, let buffer = buffer else { return }
                let rotation = viewModel?.lastRotation ?? 0  // read before main-queue hop
                DispatchQueue.main.async {
                    self.enqueueBuffer(buffer, rotation: rotation)
                }
            })
            .disposed(by: disposeBag)

        viewModel.playerPosition
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] position in
                guard let self = self else { return }
                if !self.isSeeking {
                    self.progress = position
                    self.sliderUpdate?(position)
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
        // After first meaningful layout, re-enqueue the buffer in case it
        // arrived before the layer had non-zero bounds.
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
    /// When provided, this binding is the single source of truth for controls
    /// visibility. The caller (e.g. MediaPreviewView) owns the state and drives
    /// both its own overlay and the player controls in sync.
    var externalControlsVisible: Binding<Bool>?

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

            VideoLayerView(displayLayer: coordinator.displayLayer, coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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

    // MARK: - Background

    private var backgroundColor: Color {
        if sizeMode == .fullScreen {
            return Color.black
        }
        return coordinator.hasVideo
            ? Color(UIColor.placeholderText)
            : Color(UIColor.secondarySystemBackground)
    }

    // MARK: - Controls Overlay

    @ViewBuilder
    private var controlsOverlay: some View {
        if sizeMode == .fullScreen {
            ZStack {
                centerPlayButton
                VStack {
                    Spacer()
                    fullScreenBottomBar
                }
            }
            .opacity(controlsVisible ? 1 : 0)
        } else {
            messageControls
        }
    }

    // MARK: - Center Play Button (Full Screen)

    @ViewBuilder
    private var centerPlayButton: some View {
        Button(action: {
            viewModel.togglePause()
            coordinator.scheduleAutoHide()
        }) {
            Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
        }
        .applyGlassButtonBackground()
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Full Screen Bottom Bar

    @ViewBuilder
    private var fullScreenBottomBar: some View {
        HStack(spacing: 12) {
            MediaSeekSlider(
                onRegister: { sink in coordinator.sliderUpdate = sink },
                onSeekStart: {
                    coordinator.cancelAutoHide()
                    coordinator.isSeeking = true
                    viewModel.userStartSeeking()
                    viewModel.seekTimeVariable.accept(coordinator.progress)
                },
                onSeekChange: { newValue in
                    coordinator.progress = newValue
                    if coordinator.isSeeking {
                        viewModel.seekTimeVariable.accept(newValue)
                    }
                },
                onSeekEnd: {
                    coordinator.isSeeking = false
                    viewModel.seekTimeVariable.accept(coordinator.progress)
                    viewModel.userStopSeeking()
                    coordinator.scheduleAutoHide()
                }
            )

            Text(coordinator.duration.durationString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))

            if coordinator.hasVideo {
                Button(action: {
                    viewModel.muteAudio()
                    coordinator.scheduleAutoHide()
                }) {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .applyControlsBarBackground(isFullScreen: true)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - In-Message Controls

    @ViewBuilder
    private var messageControls: some View {
        ZStack {
            // Bottom gradient scrim: dark at bottom, fading to clear
            VStack {
                Spacer()
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.75)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }

            // Center play/pause
            Button(action: { viewModel.togglePause() }) {
                Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
            }
            .applyGlassButtonBackground()
            .buttonStyle(ScaleButtonStyle())

            // Bottom controls: duration + mute + slider
            VStack(spacing: 2) {
                Spacer()

                HStack(alignment: .center) {
                    Text(coordinator.duration.durationString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    if coordinator.hasVideo {
                        Button(action: { viewModel.muteAudio() }) {
                            Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                    }
                }

                MediaSeekSlider(
                    onRegister: { sink in coordinator.sliderUpdate = sink },
                    onSeekStart: {
                        coordinator.isSeeking = true
                        viewModel.userStartSeeking()
                        viewModel.seekTimeVariable.accept(coordinator.progress)
                    },
                    onSeekChange: { newValue in
                        coordinator.progress = newValue
                        if coordinator.isSeeking {
                            viewModel.seekTimeVariable.accept(newValue)
                        }
                    },
                    onSeekEnd: {
                        coordinator.isSeeking = false
                        viewModel.seekTimeVariable.accept(coordinator.progress)
                        viewModel.userStopSeeking()
                    }
                )
                .frame(height: 24)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

}

// MARK: - View Helpers

private extension View {
    /// Only attaches a full-area tap gesture in full-screen mode.
    /// In message mode, no gesture is added so buttons remain tappable.
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
}

// MARK: - Controls Background Helpers

private extension View {
    func applyControlsBarBackground(isFullScreen: Bool) -> some View {
        let cornerRadius: CGFloat = isFullScreen ? 20 : 14
        return glassRoundedBackground(cornerRadius: cornerRadius)
    }

    func applyGlassButtonBackground() -> some View {
        glassCircleBackground()
    }
}


