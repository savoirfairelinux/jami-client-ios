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

// MARK: - Shared Glass Background

/// Shared across SendFileView, PlayerView, and MediaPreviewView.
let sharedDarkBlurEffect = UIBlurEffect(style: .dark)

func glassBackground<S: Shape>(shape: S) -> some View {
    ZStack {
        VisualEffectView(effect: sharedDarkBlurEffect)
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

/// A clear, adaptive glass background that uses the system thin material.
/// Suitable for use on light or tinted surfaces (e.g. audio player controls).
func clearGlassBackground<S: Shape>(shape: S) -> some View {
    ZStack {
        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }
    .clipShape(shape)
    .overlay(shape.stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
}

/// A clear glass background with a subtle top-edge highlight for a modern
/// floating-glass feel. On iOS 26+ this is unused in favor of the native
/// `.glassEffect()` API — see `liquidGlassCircleBackground()`.
func clearGlassHighlightBackground<S: Shape>(shape: S) -> some View {
    ZStack {
        VisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        // Subtle top-edge inner glow for depth
        LinearGradient(
            colors: [Color.white.opacity(0.25), Color.white.opacity(0.0)],
            startPoint: .top,
            endPoint: .center
        )
    }
    .clipShape(shape)
    .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
}

// MARK: - View Modifier Helpers

extension View {
    func glassCircleBackground() -> some View {
        background(glassBackground(shape: Circle()))
    }

    func clearGlassCircleBackground() -> some View {
        background(clearGlassBackground(shape: Circle()))
    }

    /// Applies a liquid glass effect using the given shape on iOS 26+ with a
    /// polished clear-glass fallback on older versions.
    /// Use this for floating controls over content.
    @ViewBuilder
    func jamiGlassEffect(
        in shape: some Shape = Circle(),
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            let glass: Glass = interactive ? Glass.clear.interactive() : .clear
            self.glassEffect(glass, in: shape)
        } else {
            self.background(clearGlassHighlightBackground(shape: shape))
        }
    }

    /// Convenience for a circular liquid glass background.
    @ViewBuilder
    func liquidGlassCircleBackground() -> some View {
        self.jamiGlassEffect(in: Circle(), interactive: true)
    }

    func glassCapsuleBackground() -> some View {
        background(glassBackground(shape: Capsule()))
    }

    func glassRoundedBackground(cornerRadius: CGFloat = 14) -> some View {
        background(glassBackground(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }
}

// MARK: - Shared Media Seek Slider

struct MediaSeekSlider: UIViewRepresentable {
    var trackColor: Color = .white
    var thumbSize: CGFloat = 14
    var onRegister: (@escaping (Float) -> Void) -> Void
    var onSeekStart: () -> Void
    var onSeekChange: (Float) -> Void
    var onSeekEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1

        let coordinator = context.coordinator
        coordinator.onSeekStart = onSeekStart
        coordinator.onSeekChange = onSeekChange
        coordinator.onSeekEnd = onSeekEnd

        // Register the direct-update sink so the caller can push position
        // values at ~10x/sec without triggering SwiftUI body re-evaluation.
        onRegister { [weak slider, weak coordinator] newValue in
            guard let slider, coordinator?.isSeeking != true else { return }
            slider.value = newValue
        }

        applyStyle(to: slider, color: UIColor(trackColor), thumbSize: thumbSize)
        slider.accessibilityLabel = NSLocalizedString("accessibility.audioPlayerSeek", comment: "")
        slider.addTarget(coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        slider.addTarget(coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(coordinator, action: #selector(Coordinator.touchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSeekStart = onSeekStart
        coordinator.onSeekChange = onSeekChange
        coordinator.onSeekEnd = onSeekEnd

        let uiColor = UIColor(trackColor)
        guard coordinator.lastColor != uiColor || coordinator.lastThumbSize != thumbSize else { return }
        applyStyle(to: slider, color: uiColor, thumbSize: thumbSize)
        coordinator.lastColor = uiColor
        coordinator.lastThumbSize = thumbSize
    }

    private func applyStyle(to slider: UISlider, color: UIColor, thumbSize: CGFloat) {
        slider.minimumTrackTintColor = color
        slider.maximumTrackTintColor = color.withAlphaComponent(0.35)
        slider.thumbTintColor = color
        let thumb = Self.makeCircle(size: thumbSize, color: color)
        slider.setThumbImage(thumb, for: .normal)
        slider.setThumbImage(thumb, for: .highlighted)
    }

    private static func makeCircle(size: CGFloat, color: UIColor) -> UIImage {
        let cgSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: cgSize)
        return renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: cgSize))
        }
    }

    final class Coordinator: NSObject {
        var isSeeking = false
        var onSeekStart: () -> Void = {}
        var onSeekChange: (Float) -> Void = { _ in }
        var onSeekEnd: () -> Void = {}
        var lastColor: UIColor?
        var lastThumbSize: CGFloat = 0

        @objc
        func touchDown(_ slider: UISlider) {
            isSeeking = true
            onSeekStart()
        }
        @objc
        func valueChanged(_ slider: UISlider) {
            onSeekChange(slider.value)
        }
        @objc
        func touchUp(_ slider: UISlider) {
            onSeekChange(slider.value)
            onSeekEnd()
            isSeeking = false
        }
    }
}

// MARK: - Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shared Button Helpers

extension View {
    /// A 44×44 icon button with a circular glass background.
    func glassIconButton(systemName: String, accessibilityLabel: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassCircleBackground()
        }
        .accessibilityLabel(accessibilityLabel)
        .buttonStyle(ScaleButtonStyle())
    }

    func glassLabelButton(text: String, size: CGFloat = 17, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: size, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassCapsuleBackground()
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Duration Formatting

extension Float {
    var durationString: String {
        guard self > 0 else { return "00:00" }
        return String.durationFormatted(seconds: Int(self / 1_000_000))
    }

    /// Returns the elapsed time string for a given progress (0..1) and total duration (microseconds).
    static func elapsedString(progress: Float, duration: Float) -> String {
        guard duration > 0 else { return "00:00" }
        let totalSeconds = Int(duration / 1_000_000)
        let elapsed = Int(Float(totalSeconds) * min(max(progress, 0), 1))
        return String.durationFormatted(seconds: elapsed)
    }
}

final class MessageActionHandler {
    var presentMediaPreview: ((MediaPreviewModel, CGRect, (() -> CGRect)?) -> Void)?
    let injectionBag: InjectionBag
    var forwardMessage: ((MessageContentVM, [String]) -> Void)?

    init(injectionBag: InjectionBag) {
        self.injectionBag = injectionBag
    }

    /// Builds a MediaPreviewModel from the message's state and presents it.
    /// Handles async image loading for image files; video files are presented synchronously.
    func handleMediaPreview(for message: MessageContentVM, sourceFrame: CGRect, sourceFrameProvider: (() -> CGRect)?) {
        guard let url = message.url else { return }
        let allowDelete = !message.isIncoming
        if let player = message.player, player.hasVideo.value {
            let content = MediaPreviewContent.player(player)
            let model = makePreviewModel(content: content, fileURL: url, canDelete: allowDelete, delegate: message)
            presentMediaPreview?(model, sourceFrame, sourceFrameProvider)
        } else if url.pathExtension.isImageExtension() {
            let isGif = message.isGifImage()
            DispatchQueue.global(qos: .userInitiated).async { [weak self, weak message] in
                let image = isGif
                    ? UIImage.gifImageWithUrl(url, maxSize: 0)
                    : UIImage.getImagefromURL(fileURL: url, maxSize: 0)
                guard let self = self, let message = message, let image = image else { return }
                DispatchQueue.main.async { [weak self, weak message] in
                    guard let self = self, let message = message else { return }
                    let currentFrame = sourceFrameProvider?() ?? sourceFrame
                    let content = MediaPreviewContent.image(image)
                    let model = self.makePreviewModel(content: content, fileURL: url, canDelete: allowDelete, delegate: message)
                    self.presentMediaPreview?(model, currentFrame, sourceFrameProvider)
                }
            }
        }
    }

    private func makePreviewModel(content: MediaPreviewContent, fileURL: URL, canDelete: Bool, delegate: MediaPreviewActionsDelegate) -> MediaPreviewModel {
        let model = MediaPreviewModel(content: content, delegate: delegate, fileURL: fileURL, canDelete: canDelete)
        model.injectionBag = injectionBag
        if let forwardMessage = forwardMessage {
            model.forwardCallback = { [weak delegate] conversations in
                guard let delegate = delegate as? MessageContentVM else { return }
                forwardMessage(delegate, conversations)
            }
        }
        return model
    }
}
