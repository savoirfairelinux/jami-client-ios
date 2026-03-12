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

// MARK: - Shared Glass Background

/// Shared across SendFileView, PlayerView, and MediaPreviewView.
/// A single instance is reused to avoid allocating a new UIBlurEffect per render.
let sharedDarkBlurEffect = UIBlurEffect(style: .dark)

/// Produces a frosted-glass panel: dark blur + subtle gradient + thin border.
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

/// A `UISlider`-backed seek bar shared by `SendFileView` and `PlayerView`.
///
/// Position updates at playback rate (~10x/sec) are pushed directly to `UISlider.value`
/// via the `onRegister` callback, bypassing SwiftUI's render cycle entirely.
/// The caller receives a sink closure from `onRegister` and calls it whenever the
/// position changes, e.g. `playerCoordinator.sliderUpdate = receivedSink`.
///
/// - Parameters:
///   - trackColor: Color applied to both track segments and the thumb.
///   - thumbSize: Diameter of the custom circular thumb image (default 14 pt).
///   - onRegister: Called once in `makeUIView`; the caller stores the returned sink
///                 and calls it to push position values directly without SwiftUI involvement.
///   - onSeekStart: Called when the user begins dragging.
///   - onSeekChange: Called while dragging with the current slider value.
///   - onSeekEnd:   Called when the user lifts the finger.
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

/// Press-to-scale spring animation shared by all media control buttons.
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

    /// A pill-shaped text button with a capsule glass background.
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
    /// Converts a duration in microseconds to a human-readable `mm:ss` or `hh:mm:ss` string.
    var durationString: String {
        guard self > 0 else { return "" }
        let total = Int(self / 1_000_000)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        return h > 0
            ? String(format: "%02d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
