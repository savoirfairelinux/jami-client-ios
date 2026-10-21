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

// MARK: - Media Scrubber

struct MediaScrubber: View {
    let progress: Float
    let accessibilityValue: String
    var trackColor: Color = .white.opacity(0.35)
    var fillColor: Color = .white.opacity(0.7)
    var activeFillColor: Color = .white
    var requiresHorizontalDrag = false
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    @GestureState private var isDragging = false
    @SwiftUI.State private var isSeeking = false
    @SwiftUI.State private var isDragIgnored = false

    private static let restingHeight: CGFloat = 4
    private static let activeHeight: CGFloat = 8
    private static let accessibilityStep: Float = 0.1
    private static let horizontalDragDistance: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                Capsule()
                    .fill(isSeeking ? activeFillColor : fillColor)
                    .frame(width: geometry.size.width * CGFloat(min(1, max(0, progress))))
            }
            .frame(height: isSeeking ? Self.activeHeight : Self.restingHeight)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .if(requiresHorizontalDrag) { $0.simultaneousGesture(dragGesture(width: geometry.size.width)) }
            .if(!requiresHorizontalDrag) { $0.gesture(dragGesture(width: geometry.size.width)) }
        }
        .animation(.easeOut(duration: 0.15), value: isSeeking)
        .onChange(of: isDragging) { dragging in
            guard !dragging else { return }
            isDragIgnored = false
            guard isSeeking else { return }
            isSeeking = false
            onSeekEnd()
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.Accessibility.audioPlayerSeek)
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? Self.accessibilityStep : -Self.accessibilityStep
            onSeekStart()
            onSeekChange(min(1, max(0, progress + step)))
            onSeekEnd()
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: requiresHorizontalDrag ? Self.horizontalDragDistance : 0)
            .updating($isDragging) { _, dragging, _ in
                dragging = true
            }
            .onChanged { value in
                if !isSeeking {
                    guard !isDragIgnored else { return }
                    if requiresHorizontalDrag, abs(value.translation.height) > abs(value.translation.width) {
                        isDragIgnored = true
                        return
                    }
                    isSeeking = true
                    onSeekStart()
                }
                guard width > 0 else { return }
                onSeekChange(Float(min(1, max(0, value.location.x / width))))
            }
    }
}

struct MediaScrubberRow: View {
    let progress: Float
    let elapsed: TimeInterval
    let duration: TimeInterval
    let onSeekStart: () -> Void
    let onSeekChange: (Float) -> Void
    let onSeekEnd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            timeLabel(elapsed)
            MediaScrubber(progress: progress,
                          accessibilityValue: String.compactDurationFormatted(seconds: elapsed),
                          onSeekStart: onSeekStart,
                          onSeekChange: onSeekChange,
                          onSeekEnd: onSeekEnd)
            timeLabel(duration)
        }
        .frame(height: 44)
    }

    private func timeLabel(_ seconds: TimeInterval) -> some View {
        Text(String.compactDurationFormatted(seconds: seconds))
            .font(.subheadline.monospacedDigit())
            .foregroundColor(.white.opacity(0.7))
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
        String.compactDurationFormatted(seconds: TimeInterval(max(self, 0) / 1_000_000))
    }

    /// Returns the elapsed time string for a given progress (0..1) and total duration (microseconds).
    static func elapsedString(progress: Float, duration: Float) -> String {
        guard duration > 0 else { return String.compactDurationFormatted(seconds: 0) }
        let totalSeconds = Int(duration / 1_000_000)
        let elapsed = Int(Float(totalSeconds) * min(max(progress, 0), 1))
        return String.compactDurationFormatted(seconds: TimeInterval(elapsed))
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
