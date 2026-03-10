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

    /// Enqueue a sample buffer on the display layer, handling flush/error recovery.
    func enqueueBuffer(_ buffer: CMSampleBuffer) {
        lastBuffer = buffer
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(buffer)
    }

    /// Re-enqueue the last buffer (e.g. after the layer is laid out for the first time).
    func redisplayLastBuffer() {
        guard let buffer = lastBuffer else { return }
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

    enum Layout {
        static let maxPadding: CGFloat = 30
        static let minPadding: CGFloat = 10
        static let maxButtonSize: CGFloat = 60
        static let minButtonSize: CGFloat = 40
        static let maxTopGradient: CGFloat = 100
        static let minTopGradient: CGFloat = 50
        static let maxBottomGradient: CGFloat = 160
        static let minBottomGradient: CGFloat = 80
    }

    var viewModel: PlayerViewModel
    var sizeMode: PlayerMode
    var withControls: Bool

    @StateObject private var coordinator = PlayerCoordinator()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor
                    .ignoresSafeArea(edges: sizeMode == .fullScreen ? .all : [])

                VideoLayerView(displayLayer: coordinator.displayLayer, coordinator: coordinator)

                if withControls {
                    controlsOverlay(in: geometry)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if sizeMode == .fullScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        coordinator.controlsVisible.toggle()
                    }
                }
            }
        }
        .onAppear {
            coordinator.pendingViewModel = viewModel
            coordinator.bind(to: viewModel)
        }
    }

    // MARK: - Background

    private var backgroundColor: Color {
        if sizeMode == .fullScreen {
            return Color.black
        }
        return coordinator.hasVideo ? Color(UIColor.placeholderText) : Color(UIColor.secondarySystemBackground)
    }

    // MARK: - Controls Overlay

    @ViewBuilder
    private func controlsOverlay(in geometry: GeometryProxy) -> some View {
        let isFullScreen = sizeMode == .fullScreen
        ZStack(alignment: .bottom) {
            VStack {
                topGradient(isFullScreen: isFullScreen)
                Spacer()
            }
            .opacity(coordinator.controlsVisible ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()
                bottomGradient(isFullScreen: isFullScreen)
            }
            .opacity(coordinator.controlsVisible ? 1 : 0)

            controlsContent(isFullScreen: isFullScreen)
                .opacity(coordinator.controlsVisible ? 1 : 0)
        }
    }

    @ViewBuilder
    private func controlsContent(isFullScreen: Bool) -> some View {
        let padding = isFullScreen ? Layout.maxPadding : Layout.minPadding
        let buttonSize = isFullScreen ? Layout.maxButtonSize : Layout.minButtonSize
        let controlColor = coordinator.hasVideo ? Color.white : Color(UIColor.label.lighten(by: 50) ?? UIColor.label)

        if isFullScreen {
            fullScreenControls(padding: padding, buttonSize: buttonSize, controlColor: controlColor)
        } else {
            messageControls(padding: padding, buttonSize: buttonSize, controlColor: controlColor)
        }
    }

    // MARK: - Full Screen Controls

    @ViewBuilder
    private func fullScreenControls(padding: CGFloat, buttonSize: CGFloat, controlColor: Color) -> some View {
        VStack(spacing: 8) {
            Spacer()

            Button(action: { viewModel.togglePause() }) {
                Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: buttonSize * 0.5, height: buttonSize * 0.5)
                    .foregroundColor(controlColor)
            }
            .frame(width: buttonSize, height: buttonSize)

            Spacer()

            HStack(spacing: 12) {
                if coordinator.hasVideo {
                    Button(action: { viewModel.muteAudio() }) {
                        Image(uiImage: coordinator.isMuted ? UIImage(asset: Asset.audioOff) ?? UIImage() : UIImage(asset: Asset.audioOn) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: buttonSize * 0.4, height: buttonSize * 0.4)
                            .foregroundColor(controlColor)
                    }
                }

                PlayerSlider(
                    value: Binding(
                        get: { coordinator.progress },
                        set: { coordinator.progress = $0 }
                    ),
                    trackColor: controlColor,
                    thumbSize: 15,
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

                Text(durationString(microsec: coordinator.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(controlColor)
            }
            .padding(.horizontal, padding)
            .padding(.bottom, padding)
        }
    }

    // MARK: - In-Message Controls

    @ViewBuilder
    private func messageControls(padding: CGFloat, buttonSize: CGFloat, controlColor: Color) -> some View {
        VStack(spacing: 4) {
            Spacer()

            HStack(spacing: 8) {
                Button(action: { viewModel.togglePause() }) {
                    Image(systemName: coordinator.isPaused ? "play.fill" : "pause.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: buttonSize * 0.4, height: buttonSize * 0.4)
                        .foregroundColor(controlColor)
                }
                .frame(width: buttonSize, height: buttonSize)

                PlayerSlider(
                    value: Binding(
                        get: { coordinator.progress },
                        set: { coordinator.progress = $0 }
                    ),
                    trackColor: controlColor,
                    thumbSize: 10,
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

                Text(durationString(microsec: coordinator.duration))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(controlColor)

                if coordinator.hasVideo {
                    Button(action: { viewModel.muteAudio() }) {
                        Image(uiImage: coordinator.isMuted ? UIImage(asset: Asset.audioOff) ?? UIImage() : UIImage(asset: Asset.audioOn) ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: buttonSize * 0.3, height: buttonSize * 0.3)
                            .foregroundColor(controlColor)
                    }
                }
            }
            .padding(.horizontal, padding)
            .padding(.bottom, padding)
        }
    }

    // MARK: - Gradients

    @ViewBuilder
    private func topGradient(isFullScreen: Bool) -> some View {
        let height = isFullScreen ? Layout.maxTopGradient : Layout.minTopGradient
        let opacity = isFullScreen ? 1.0 : 0.2
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(opacity),
                Color.black.opacity(0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
    }

    @ViewBuilder
    private func bottomGradient(isFullScreen: Bool) -> some View {
        let height = isFullScreen ? Layout.maxBottomGradient : Layout.minBottomGradient
        let opacity = isFullScreen ? 1.0 : 0.2
        LinearGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0),
                Color.black.opacity(opacity)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
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

// MARK: - Custom Slider

/// A custom slider that matches the original PlayerView's circle-thumb style.
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

        // Register for direct progress updates, bypassing SwiftUI re-renders
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

        @objc func valueChanged(_ sender: UISlider) {
            onValueChanged?(sender.value)
        }

        @objc func touchDown(_ sender: UISlider) {
            isEditing = true
            onEditingChanged?(true)
        }

        @objc func touchUp(_ sender: UISlider) {
            isEditing = false
            onEditingChanged?(false)
        }
    }
}
