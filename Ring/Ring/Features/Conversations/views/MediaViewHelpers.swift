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

// MARK: - View Modifier Helpers

extension View {
    func glassCircleBackground() -> some View {
        background(glassBackground(shape: Circle()))
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

    private static func makeCircle(size: CGFloat, color: UIColor) -> UIImage? {
        let cgSize = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(cgSize, false, 0.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(color.cgColor)
        ctx.addEllipse(in: CGRect(origin: .zero, size: cgSize))
        ctx.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    final class Coordinator: NSObject {
        var isSeeking = false
        var onSeekStart: () -> Void = {}
        var onSeekChange: (Float) -> Void = { _ in }
        var onSeekEnd: () -> Void = {}
        var lastColor: UIColor?
        var lastThumbSize: CGFloat = 0

        @objc func touchDown(_ slider: UISlider) {
            isSeeking = true
            onSeekStart()
        }
        @objc func valueChanged(_ slider: UISlider) {
            onSeekChange(slider.value)
        }
        @objc func touchUp(_ slider: UISlider) {
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
    func glassIconButton(systemName: String, size: CGFloat = 20, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .glassCircleBackground()
        }
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

// MARK: - Zoomable Image

/// Reusable zoomable image with pinch-to-zoom, pan, and double-tap toggle.
/// Used by MediaPreviewView for full-screen image preview.
struct ZoomableImageView: View {
    let image: UIImage
    /// Optional single-tap callback (e.g. to toggle controls). Nil disables single-tap.
    var onSingleTap: (() -> Void)?

    private let doubleTapZoomScale: CGFloat = 3
    @SwiftUI.State private var imageScale: CGFloat = 1
    @SwiftUI.State private var lastScale: CGFloat = 1
    @SwiftUI.State private var imageOffset: CGSize = .zero
    @SwiftUI.State private var lastOffset: CGSize = .zero

    /// Whether the image is currently zoomed in (scale > 1).
    var isZoomed: Bool { imageScale > 1 }

    var body: some View {
        imageView
            .scaleEffect(imageScale)
            .offset(imageOffset)
            .gesture(magnificationGesture)
            .gesture(panGesture)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { toggleZoom() }
    }

    func resetZoom() {
        imageScale = 1
        lastScale = 1
        imageOffset = .zero
        lastOffset = .zero
    }

    private var imageView: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                imageScale = max(1, lastScale * value)
            }
            .onEnded { value in
                lastScale = max(1, lastScale * value)
                imageScale = lastScale
                if imageScale <= 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        imageOffset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard imageScale > 1 else { return }
                imageOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard imageScale > 1 else { return }
                lastOffset = imageOffset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if imageScale > 1 {
                imageScale = 1
                lastScale = 1
                imageOffset = .zero
                lastOffset = .zero
            } else {
                imageScale = doubleTapZoomScale
                lastScale = doubleTapZoomScale
            }
        }
    }
}

// MARK: - Preview Tap Overlay

/// Handles both tap-to-preview and long-press-for-context-menu on media views.
/// Both gestures live on the same Color.clear overlay so the overlay does not
/// block touches from reaching the long press handler.
/// A shared flag prevents the tap from firing after a long press is dismissed.
struct PreviewTapOverlay: ViewModifier {
    let onTap: (CGRect) -> Void
    let onLongPress: () -> Void

    @SwiftUI.State private var longPressActive = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !longPressActive else { return }
                            onTap(proxy.frame(in: .global))
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.15)
                                .onEnded { _ in
                                    longPressActive = true
                                    onLongPress()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        longPressActive = false
                                    }
                                }
                        )
                }
            )
    }
}

// MARK: - Duration Formatting

extension Float {
    var durationString: String {
        guard self > 0 else { return "" }
        return String.durationFormatted(seconds: Int(self / 1_000_000))
    }
}
