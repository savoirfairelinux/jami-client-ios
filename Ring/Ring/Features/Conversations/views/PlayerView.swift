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
import AVFoundation

enum PlayerMode {
    case fullScreen
    case inConversationMessage
}

// MARK: - Video Layer View

/// Renders video frames via AVSampleBufferDisplayLayer.
struct VideoLayerView: UIViewRepresentable {
    let viewModel: PlayerViewModel

    func makeUIView(context: Context) -> VideoLayerUIView {
        let view = VideoLayerUIView(viewModel: viewModel)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: VideoLayerUIView, context: Context) {
        // If the view model changed (e.g. cell reuse), re-attach the new display layer.
        if uiView.attachedViewModel !== viewModel {
            uiView.attach(viewModel: viewModel)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        viewModel.displayLayer.frame = uiView.bounds
        CATransaction.commit()
    }
}

/// UIView subclass that detects when layout completes and when the view
/// enters a window, so the view model can bind and display the first frame.
final class VideoLayerUIView: UIView {
    private(set) weak var attachedViewModel: PlayerViewModel?
    private var didRedisplay = false

    init(viewModel: PlayerViewModel) {
        super.init(frame: .zero)
        attach(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Attach a (possibly new) view model: swap the display layer and trigger a refresh.
    /// Calling this when already attached to the same view model is a no-op.
    func attach(viewModel: PlayerViewModel) {
        let shortPath = (viewModel.filePath as NSString).lastPathComponent
        print("[VideoLayerUIView] attach [\(shortPath)] inWindow=\(window != nil)")
        // Remove the old display layer if it belongs to a different view model.
        if let old = attachedViewModel, old !== viewModel {
            old.displayLayer.removeFromSuperlayer()
        }
        attachedViewModel = viewModel
        if viewModel.displayLayer.superlayer !== layer {
            layer.addSublayer(viewModel.displayLayer)
        }
        // Only trigger playback setup if already in a window; otherwise
        // didMoveToWindow will handle it when the view is added to the hierarchy.
        if window != nil {
            didRedisplay = false
            viewModel.createPlayer()
            setNeedsLayout()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            let shortPath = (attachedViewModel?.filePath as NSString?)?.lastPathComponent ?? "?"
            print("[VideoLayerUIView] didMoveToWindow [\(shortPath)] bounds=\(bounds)")
            didRedisplay = false
            attachedViewModel?.createPlayer()
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        attachedViewModel?.displayLayer.frame = bounds
        CATransaction.commit()
        if !didRedisplay && bounds.width > 0 && bounds.height > 0 {
            let shortPath = (attachedViewModel?.filePath as NSString?)?.lastPathComponent ?? "?"
            print("[VideoLayerUIView] layoutSubviews [\(shortPath)] bounds=\(bounds) → redisplay")
            didRedisplay = true
            attachedViewModel?.redisplayLastBuffer()
        }
    }
}

// MARK: - PlayerView

struct PlayerView: View {

    @ObservedObject var viewModel: PlayerViewModel
    var sizeMode: PlayerMode
    var withControls: Bool

    var body: some View {
        GeometryReader { _ in
            ZStack {
                backgroundColor
                    .ignoresSafeArea(edges: sizeMode == .fullScreen ? .all : [])

                VideoLayerView(viewModel: viewModel)

                if withControls {
                    controlsOverlay
                }
            }
            .applyFullScreenTapGesture(isFullScreen: sizeMode == .fullScreen, viewModel: viewModel)
        }
        .onAppear {
            if sizeMode == .fullScreen {
                viewModel.scheduleAutoHide()
            }
        }
        .onDisappear {
            viewModel.cancelAutoHide()
        }
    }

    // MARK: - Background

    private var backgroundColor: Color {
        if sizeMode == .fullScreen {
            return Color.black
        }
        return viewModel.hasVideo
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
            .opacity(viewModel.controlsVisible ? 1 : 0)
        } else {
            messageControls
        }
    }

    // MARK: - Center Play Button (Full Screen)

    @ViewBuilder
    private var centerPlayButton: some View {
        Button(action: {
            viewModel.togglePause()
            viewModel.scheduleAutoHide()
        }) {
            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
        }
        .applyGlassButtonBackground()
    }

    // MARK: - Full Screen Bottom Bar

    @ViewBuilder
    private var fullScreenBottomBar: some View {
        HStack(spacing: 12) {
            PlayerSlider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.progress = $0 }
                ),
                trackColor: .white,
                thumbSize: 14,
                viewModel: viewModel,
                onEditingChanged: { editing in
                    if editing {
                        viewModel.cancelAutoHide()
                        viewModel.isSeeking = true
                        viewModel.userStartSeeking()
                        viewModel.seekTimeVariable.accept(viewModel.progress)
                    } else {
                        viewModel.isSeeking = false
                        viewModel.seekTimeVariable.accept(viewModel.progress)
                        viewModel.userStopSeeking()
                        viewModel.scheduleAutoHide()
                    }
                },
                onValueChanged: { newValue in
                    if viewModel.isSeeking {
                        viewModel.seekTimeVariable.accept(newValue)
                    }
                }
            )

            Text(durationString(microsec: viewModel.duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))

            if viewModel.hasVideo {
                Button(action: {
                    viewModel.muteAudio()
                    viewModel.scheduleAutoHide()
                }) {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
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
                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
            }
            .applyGlassButtonBackground()

            // Bottom controls: duration + mute + slider
            VStack(spacing: 2) {
                Spacer()

                HStack(alignment: .center) {
                    Text(durationString(microsec: viewModel.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    if viewModel.hasVideo {
                        Button(action: { viewModel.muteAudio() }) {
                            Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                        }
                    }
                }

                PlayerSlider(
                    value: Binding(
                        get: { viewModel.progress },
                        set: { viewModel.progress = $0 }
                    ),
                    trackColor: .white,
                    thumbSize: 14,
                    viewModel: viewModel,
                    onEditingChanged: { editing in
                        if editing {
                            viewModel.isSeeking = true
                            viewModel.userStartSeeking()
                            viewModel.seekTimeVariable.accept(viewModel.progress)
                        } else {
                            viewModel.isSeeking = false
                            viewModel.seekTimeVariable.accept(viewModel.progress)
                            viewModel.userStopSeeking()
                        }
                    },
                    onValueChanged: { newValue in
                        if viewModel.isSeeking {
                            viewModel.seekTimeVariable.accept(newValue)
                        }
                    }
                )
                .frame(height: 24)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
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
    /// Only attaches a full-area tap gesture in full-screen mode.
    @ViewBuilder
    func applyFullScreenTapGesture(isFullScreen: Bool, viewModel: PlayerViewModel) -> some View {
        if isFullScreen {
            self
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.controlsVisible.toggle()
                    }
                    if viewModel.controlsVisible {
                        viewModel.scheduleAutoHide()
                    }
                }
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
/// tick; the UISlider is updated directly via `sliderUpdate` closure, bypassing
/// SwiftUI's render cycle entirely. Also allows a custom circular thumb image.
struct PlayerSlider: UIViewRepresentable {
    @Binding var value: Float
    var trackColor: Color
    var thumbSize: CGFloat
    var viewModel: PlayerViewModel
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
        viewModel.sliderUpdate = { [weak slider, weak coordinator] newValue in
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
