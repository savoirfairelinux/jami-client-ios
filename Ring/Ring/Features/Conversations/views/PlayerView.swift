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

    func enqueueBuffer(_ buffer: CMSampleBuffer) {
        lastBuffer = buffer
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    private var currentRotation: Int = 0

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

        viewModel.playBackFrame
            .subscribe(onNext: { [weak self] buffer in
                guard let self = self, let buffer = buffer else { return }
                DispatchQueue.main.async {
                    self.enqueueBuffer(buffer)
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

    private var backgroundColor: Color {
        if sizeMode == .fullScreen {
            return Color.black
        }
        if coordinator.hasVideo {
            return Color(UIColor.placeholderText)
        }
        return Color(UIColor.placeholderText)
    }

    // MARK: - Controls Overlay

    @ViewBuilder private var controlsOverlay: some View {
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

    @ViewBuilder private var centerPlayButton: some View {
        Button(action: {
            viewModel.togglePause()
            coordinator.scheduleAutoHide()
        }, label: {
            Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
        })
        .applyGlassButtonBackground()
    }

    @ViewBuilder private var fullScreenBottomBar: some View {
        HStack(spacing: 12) {
            PlayerSlider(
                value: Binding(
                    get: { coordinator.progress },
                    set: { coordinator.progress = $0 }
                ),
                trackColor: .white,
                thumbSize: 14,
                playerCoordinator: coordinator,
                onEditingChanged: { editing in
                    if editing {
                        coordinator.cancelAutoHide()
                        coordinator.isSeeking = true
                        viewModel.userStartSeeking()
                        viewModel.seekTimeVariable.accept(coordinator.progress)
                    } else {
                        coordinator.isSeeking = false
                        viewModel.seekTimeVariable.accept(coordinator.progress)
                        viewModel.userStopSeeking()
                        coordinator.scheduleAutoHide()
                    }
                },
                onValueChanged: { newValue in
                    if coordinator.isSeeking {
                        viewModel.seekTimeVariable.accept(newValue)
                    }
                }
            )

            Text(durationString(microsec: coordinator.duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))

            if coordinator.hasVideo {
                Button(action: {
                    viewModel.muteAudio()
                    coordinator.scheduleAutoHide()
                }, label: {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                })
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .applyControlsBarBackground(isFullScreen: true)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - In-Message Controls

    @ViewBuilder private var messageControls: some View {
        if coordinator.hasVideo {
            videoMessageControls
        } else {
            audioMessageControls
        }
    }

    // MARK: - Video In-Message Controls

    private var videoMessageControls: some View {
        ZStack {
            videoMessageGradient
            videoMessagePlayButton
            videoMessageBottomBar
        }
    }

    private var videoMessageGradient: some View {
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
    }

    private var videoMessagePlayButton: some View {
        Button(action: { viewModel.togglePause() }, label: {
            Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
        })
        .applyGlassButtonBackground()
    }

    private var videoMessageBottomBar: some View {
        VStack(spacing: 2) {
            Spacer()
            HStack(alignment: .center) {
                Text(durationString(microsec: coordinator.duration))
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
            videoMessageSlider
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var videoMessageSlider: some View {
        PlayerSlider(
            value: Binding(
                get: { coordinator.progress },
                set: { coordinator.progress = $0 }
            ),
            trackColor: .white,
            thumbSize: 14,
            playerCoordinator: coordinator,
            onEditingChanged: { editing in
                if editing {
                    coordinator.isSeeking = true
                    viewModel.userStartSeeking()
                    viewModel.seekTimeVariable.accept(coordinator.progress)
                } else {
                    coordinator.isSeeking = false
                    viewModel.seekTimeVariable.accept(coordinator.progress)
                    viewModel.userStopSeeking()
                }
            },
            onValueChanged: { newValue in
                if coordinator.isSeeking {
                    viewModel.seekTimeVariable.accept(newValue)
                }
            }
        )
        .frame(height: 24)
    }

    // MARK: - Audio-Only In-Message Controls

    private var audioMessageControls: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            Button(action: { viewModel.togglePause() }, label: {
                Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            })
            .applyGlassButtonBackground()

            VStack(alignment: .leading, spacing: 2) {
                Text(durationString(microsec: coordinator.duration))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                PlayerSlider(
                    value: Binding(
                        get: { coordinator.progress },
                        set: { coordinator.progress = $0 }
                    ),
                    trackColor: .white,
                    thumbSize: 12,
                    playerCoordinator: coordinator,
                    onEditingChanged: { editing in
                        if editing {
                            coordinator.isSeeking = true
                            viewModel.userStartSeeking()
                            viewModel.seekTimeVariable.accept(coordinator.progress)
                        } else {
                            coordinator.isSeeking = false
                            viewModel.seekTimeVariable.accept(coordinator.progress)
                            viewModel.userStopSeeking()
                        }
                    },
                    onValueChanged: { newValue in
                        if coordinator.isSeeking {
                            viewModel.seekTimeVariable.accept(newValue)
                        }
                    }
                )
                .frame(height: 22)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func durationString(microsec: Float) -> String {
        if microsec == 0 { return "" }
        let durationInSec = Int(microsec / 1_000_000)
        let seconds = durationInSec % 60
        let minutes = (durationInSec / 60) % 60
        let hours = durationInSec / 3600
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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
}

// MARK: - Controls Background Helpers

private extension View {
    func applyControlsBarBackground(isFullScreen: Bool) -> some View {
        let cornerRadius: CGFloat = isFullScreen ? 20 : 14
        return self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.55))
        )
    }

    func applyGlassButtonBackground() -> some View {
        self.background(
            Circle()
                .fill(Color.black.opacity(0.55))
        )
    }
}

// MARK: - Custom Slider

/// UISlider wrapper used instead of SwiftUI Slider because the player updates
/// progress ~10x/sec. A SwiftUI Slider binding would re-evaluate `body` on every
/// tick
struct PlayerSlider: UIViewRepresentable {
    @Binding var value: Float
    var trackColor: Color
    var thumbSize: CGFloat
    var playerCoordinator: PlayerCoordinator
    var onEditingChanged: (Bool) -> Void
    var onValueChanged: (Float) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = value

        let coordinator = context.coordinator
        coordinator.onValueChanged = { [self] newValue in
            self.value = newValue
            self.onValueChanged(newValue)
        }
        coordinator.onEditingChanged = onEditingChanged

        playerCoordinator.sliderUpdate = { [weak slider, weak coordinator] newValue in
            guard let slider = slider, coordinator?.isEditing != true else { return }
            slider.value = newValue
        }

        let uiColor = UIColor(trackColor)
        applyStyle(to: slider, color: uiColor)
        slider.addTarget(coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        slider.addTarget(coordinator, action: #selector(Coordinator.touchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        let coordinator = context.coordinator
        coordinator.onValueChanged = { [self] newValue in
            self.value = newValue
            self.onValueChanged(newValue)
        }
        coordinator.onEditingChanged = onEditingChanged

        if !coordinator.isEditing {
            slider.value = value
        }

        let uiColor = UIColor(trackColor)
        guard coordinator.lastColor != uiColor || coordinator.lastThumbSize != thumbSize else { return }
        applyStyle(to: slider, color: uiColor)
        coordinator.lastColor = uiColor
        coordinator.lastThumbSize = thumbSize
    }

    private func applyStyle(to slider: UISlider, color: UIColor) {
        slider.minimumTrackTintColor = color
        slider.maximumTrackTintColor = color
        slider.thumbTintColor = color
        let circleImage = Self.makeCircle(size: thumbSize, color: color)
        slider.setThumbImage(circleImage, for: .normal)
        slider.setThumbImage(circleImage, for: .highlighted)
    }

    private static func makeCircle(size: CGFloat, color: UIColor) -> UIImage? {
        let cgSize = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(cgSize, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.setFillColor(color.cgColor)
        context.addEllipse(in: CGRect(origin: .zero, size: cgSize))
        context.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    class Coordinator: NSObject {
        var isEditing = false
        var onValueChanged: ((Float) -> Void)?
        var onEditingChanged: ((Bool) -> Void)?
        var lastColor: UIColor?
        var lastThumbSize: CGFloat = 0

        @objc
        func valueChanged(_ sender: UISlider) {
            onValueChanged?(sender.value)
        }

        @objc
        func touchDown(_ sender: UISlider) {
            isEditing = true
            onEditingChanged?(true)
        }

        @objc
        func touchUp(_ sender: UISlider) {
            isEditing = false
            onEditingChanged?(false)
        }
    }
}
