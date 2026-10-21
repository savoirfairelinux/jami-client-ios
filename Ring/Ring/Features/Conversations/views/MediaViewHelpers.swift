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
    var trackColor: Color = .white.opacity(0.35)
    var fillColor: Color = .white.opacity(0.7)
    var activeFillColor: Color = .white
    var onRegister: (@escaping (Float) -> Void) -> Void
    var onSeekStart: () -> Void
    var onSeekChange: (Float) -> Void
    var onSeekEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ScrubberSlider {
        let slider = ScrubberSlider()
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

        applyColors(to: slider, coordinator: coordinator)
        slider.accessibilityLabel = L10n.Accessibility.audioPlayerSeek
        slider.addTarget(coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        slider.addTarget(coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(coordinator, action: #selector(Coordinator.touchUp(_:)),
                         for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return slider
    }

    func updateUIView(_ slider: ScrubberSlider, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSeekStart = onSeekStart
        coordinator.onSeekChange = onSeekChange
        coordinator.onSeekEnd = onSeekEnd
        applyColors(to: slider, coordinator: coordinator)
    }

    private func applyColors(to slider: ScrubberSlider, coordinator: Coordinator) {
        let colors = [trackColor, fillColor, activeFillColor]
        guard coordinator.appliedColors != colors else { return }
        coordinator.appliedColors = colors
        slider.setColors(track: UIColor(trackColor), fill: UIColor(fillColor), activeFill: UIColor(activeFillColor))
    }

    final class Coordinator: NSObject {
        var isSeeking = false
        var onSeekStart: () -> Void = {}
        var onSeekChange: (Float) -> Void = { _ in }
        var onSeekEnd: () -> Void = {}
        var appliedColors: [Color] = []

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

final class ScrubberSlider: UISlider {
    private static let restingHeight: CGFloat = 4
    private static let activeHeight: CGFloat = 8
    private static let minimumTouchHeight: CGFloat = 44
    private static let accessibilityStep: Float = 0.1

    private var trackColor: UIColor = .white
    private var fillColor: UIColor = .white
    private var activeFillColor: UIColor = .white

    private var isActive = false {
        didSet {
            guard isActive != oldValue else { return }
            updateTrackImages()
            UIView.animate(withDuration: 0.15) { self.layoutIfNeeded() }
        }
    }

    private var trackHeight: CGFloat {
        isActive ? Self.activeHeight : Self.restingHeight
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let clearThumb = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        setThumbImage(clearThumb, for: .normal)
        setThumbImage(clearThumb, for: .highlighted)
        updateTrackImages()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setColors(track: UIColor, fill: UIColor, activeFill: UIColor) {
        trackColor = track
        fillColor = fill
        activeFillColor = activeFill
        updateTrackImages()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.minimumTouchHeight)
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX, y: bounds.midY - trackHeight / 2, width: bounds.width, height: trackHeight)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateTrackImages()
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        isActive = true
        seek(to: touch)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        seek(to: touch)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        isActive = false
    }

    override func cancelTracking(with event: UIEvent?) {
        isActive = false
    }

    override func accessibilityIncrement() {
        adjust(by: Self.accessibilityStep)
    }

    override func accessibilityDecrement() {
        adjust(by: -Self.accessibilityStep)
    }

    private func seek(to touch: UITouch) {
        let track = trackRect(forBounds: bounds)
        guard track.width > 0 else { return }
        let fraction = Float((touch.location(in: self).x - track.minX) / track.width)
        setValue(clamped(fraction), animated: false)
        sendActions(for: .valueChanged)
    }

    private func adjust(by step: Float) {
        sendActions(for: .touchDown)
        setValue(clamped(value + step), animated: false)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }

    private func clamped(_ newValue: Float) -> Float {
        min(maximumValue, max(minimumValue, newValue))
    }

    private func updateTrackImages() {
        let fill = isActive ? activeFillColor : fillColor
        setMinimumTrackImage(Self.capsuleImage(color: fill, height: trackHeight, traits: traitCollection), for: .normal)
        setMaximumTrackImage(Self.capsuleImage(color: trackColor, height: trackHeight, traits: traitCollection), for: .normal)
        setNeedsLayout()
    }

    private static func capsuleImage(color: UIColor, height: CGFloat, traits: UITraitCollection) -> UIImage {
        let size = CGSize(width: height + 1, height: height)
        let resolved = color.resolvedColor(with: traits)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            resolved.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: height / 2).fill()
        }
        let cap = height / 2
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: cap, bottom: 0, right: cap))
    }
}

// MARK: - Media Seek Fill

struct MediaSeekFill: UIViewRepresentable {
    var color: Color
    var isEnabled: Bool
    var onRegister: (@escaping (Float) -> Void) -> Void
    var onSeekStart: () -> Void
    var onSeekChange: (Float) -> Void
    var onSeekEnd: () -> Void
    var onLongPress: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SeekFillView {
        let view = SeekFillView()
        let coordinator = context.coordinator
        update(coordinator)
        view.fillColor = UIColor(color)

        onRegister { [weak view, weak coordinator] newValue in
            guard let view, coordinator?.isSeeking != true else { return }
            view.progress = CGFloat(newValue)
        }

        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)
        let longPress = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.longPress(_:)))
        longPress.minimumPressDuration = 0.2
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ view: SeekFillView, context: Context) {
        update(context.coordinator)
        view.fillColor = UIColor(color)
    }

    private func update(_ coordinator: Coordinator) {
        coordinator.isEnabled = isEnabled
        coordinator.onSeekStart = onSeekStart
        coordinator.onSeekChange = onSeekChange
        coordinator.onSeekEnd = onSeekEnd
        coordinator.onLongPress = onLongPress
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isSeeking = false
        var isEnabled = true
        var onSeekStart: () -> Void = {}
        var onSeekChange: (Float) -> Void = { _ in }
        var onSeekEnd: () -> Void = {}
        var onLongPress: (() -> Void)?

        @objc
        func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view as? SeekFillView else { return }
            switch recognizer.state {
            case .began:
                isSeeking = true
                onSeekStart()
                seek(view, to: recognizer)
            case .changed:
                seek(view, to: recognizer)
            case .ended, .cancelled, .failed:
                guard isSeeking else { return }
                seek(view, to: recognizer)
                onSeekEnd()
                isSeeking = false
            default:
                break
            }
        }

        @objc
        func longPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            onLongPress?()
        }

        private func seek(_ view: SeekFillView, to recognizer: UIPanGestureRecognizer) {
            guard view.bounds.width > 0 else { return }
            var fraction = recognizer.location(in: view).x / view.bounds.width
            if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                fraction = 1 - fraction
            }
            let value = Float(min(max(fraction, 0), 1))
            view.progress = CGFloat(value)
            onSeekChange(value)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let scrollView = otherGestureRecognizer.view as? UIScrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }
    }
}

final class SeekFillView: UIView {
    private let fillLayer = CALayer()

    var fillColor: UIColor = .white {
        didSet { updateFillColor() }
    }

    var progress: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width * min(max(progress, 0), 1)
        let originX = effectiveUserInterfaceLayoutDirection == .rightToLeft ? bounds.width - width : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.frame = CGRect(x: originX, y: 0, width: width, height: bounds.height)
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateFillColor()
    }

    private func updateFillColor() {
        fillLayer.backgroundColor = fillColor.resolvedColor(with: traitCollection).cgColor
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

    @ViewBuilder
    func glassPlayPauseButton(isPaused: Bool, iconSize: CGFloat, size: CGFloat, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .accessibilityLabel(isPaused ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause)
        if #available(iOS 26, *) {
            button.glassEffect(.clear.interactive(), in: .circle)
        } else {
            button
                .glassCircleBackground()
                .buttonStyle(ScaleButtonStyle())
        }
    }

    func trayTextButton(_ title: String, weight: Font.Weight, alignment: Alignment, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(weight))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 44, minHeight: 44, alignment: alignment)
                .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }
}

// MARK: - Media Scrubber Row

struct MediaScrubberRow<Slider: View>: View {
    let elapsed: String
    let duration: String
    @ViewBuilder let slider: () -> Slider

    var body: some View {
        HStack(spacing: 12) {
            timeLabel(elapsed, accessibilityLabel: L10n.Accessibility.audioPlayerElapsedTime)
            slider()
            timeLabel(duration, accessibilityLabel: L10n.Accessibility.audioPlayerDuration)
        }
        .frame(height: 44)
    }

    private func timeLabel(_ time: String, accessibilityLabel: String) -> some View {
        Text(time)
            .font(.subheadline.monospacedDigit())
            .foregroundColor(.white.opacity(0.7))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(time)
    }
}

extension View {
    func mediaTrayStyle() -> some View {
        padding(14)
            .glassRoundedBackground(cornerRadius: 26)
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
