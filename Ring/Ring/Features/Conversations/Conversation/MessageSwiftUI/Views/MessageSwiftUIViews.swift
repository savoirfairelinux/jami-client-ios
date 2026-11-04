/*
 * Copyright (C) 2022-2025 Savoir-faire Linux Inc.
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

struct PlayerSwiftUI: View {
    @ObservedObject var model: MessageContentVM
    var player: PlayerViewModel
    let onLongGesture: () -> Void
    var ratio: CGFloat = 1
    var withControls: Bool
    var customCornerRadius: CGFloat = 0
    private var mediaCornerRadius: CGFloat? {
        customCornerRadius == 0 ? nil : customCornerRadius
    }
    var messageTime: String?
    @Environment(\.colorScheme)
    var colorScheme
    @Environment(\.drawsMessageBubble)
    private var drawsMessageBubble

    var body: some View {
        ZStack(alignment: .center) {
            if colorScheme == .dark && player.hasVideo.value {
                model.borderColor
                    .frame(width: model.playerWidth * ratio + 2, height: model.playerHeight * ratio + 2)
                    .modifier(MessageCornerRadius(model: model, radius: mediaCornerRadius))
            }
            PlayerView(viewModel: player, sizeMode: .inConversationMessage, withControls: withControls,
                       onVideoTap: { frame, frameProvider in model.presentMediaPreview(sourceFrame: frame, sourceFrameProvider: frameProvider) },
                       onVideoLongPress: onLongGesture,
                       audioColors: drawsMessageBubble ? model.audioPlayerColors : model.audioPlayerColors.withoutBackground(),
                       messageTime: messageTime)
                .frame(height: model.playerHeight * ratio)
                .frame(width: model.playerWidth * ratio)
                .modifier(MessageCornerRadius(model: model, radius: mediaCornerRadius))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(player.pause.value ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause)
        .accessibilityAddTraits(.isButton)
        .conditionalModifier(AccessibilityGestureModifier(action: togglePauseWithVoiceOver), apply: UIAccessibility.isVoiceOverRunning)
    }

    private func togglePauseWithVoiceOver() {
        if player.playbackFailed.value {
            UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.audioPlayerUnavailable)
        }
        player.togglePause()
    }
}

struct ImageOrGifView: View {
    @ObservedObject var message: MessageContentVM

    var image: UIImage
    let onLongGesture: () -> Void
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var customCornerRadius: CGFloat = 0
    private var mediaCornerRadius: CGFloat? {
        customCornerRadius == 0 ? nil : customCornerRadius
    }

    @Environment(\.messageBubbleNotch)
    private var notch
    @SwiftUI.State private var displaySize: CGSize = .zero

    private var cornerRadius: CGFloat { mediaCornerRadius ?? message.cornerRadius }
    private var corners: UIRectCorner { mediaCornerRadius == nil ? message.corners : .allCorners }

    private var preRounded: UIImage? {
        guard notch == nil else { return nil }
        return message.preRoundedImage(size: displaySize, radius: cornerRadius, corners: corners)
    }

    var body: some View {
        let rounded = preRounded
        mediaContent(image: rounded ?? image)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { updateDisplaySize(proxy.size) }
                    .onChange(of: proxy.size) { updateDisplaySize($0) }
            })
            .conditionalModifier(MessageCornerRadius(model: message, radius: mediaCornerRadius), apply: rounded == nil)
            .messageGesture(
                onLongPress: onLongGesture,
                onTap: { frame, frameProvider in message.presentMediaPreview(sourceFrame: frame, sourceFrameProvider: frameProvider) }
            )
            .onChange(of: message.corners) { _ in prepareRoundedImage() }
    }

    private func updateDisplaySize(_ size: CGSize) {
        displaySize = size
        prepareRoundedImage()
    }

    private func prepareRoundedImage() {
        guard notch == nil else { return }
        message.prepareRoundedImage(size: displaySize, radius: cornerRadius, corners: corners)
    }

    @ViewBuilder
    private func mediaContent(image: UIImage) -> some View {
        if !message.isGifImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minHeight: minHeight, maxHeight: maxHeight)
        } else {
            ScaledImageViewWrapper(imageToShow: image, maxHeight: maxHeight, maxWidth: maxHeight)
                .scaledToFit()
                .frame(maxHeight: maxHeight)
        }
    }
}

struct MediaView: View {
    @ObservedObject var message: MessageContentVM
    let onLongGesture: () -> Void
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let withPlayerControls: Bool
    let cornerRadius: CGFloat
    var messageTime: String?
    @Environment(\.messageBubbleNotch)
    private var notch

    var body: some View {
        if let player = self.message.player {
            PlayerSwiftUI(model: message, player: player, onLongGesture: onLongGesture, withControls: withPlayerControls, customCornerRadius: cornerRadius, messageTime: messageTime)
        } else if let image = message.finalImage {
            ImageOrGifView(message: message, image: image, onLongGesture: onLongGesture, minHeight: minHeight, maxHeight: maxHeight, customCornerRadius: cornerRadius)

        } else if let thumbnailSize = message.thumbnailSize {
            thumbnailPlaceholder
                .frame(idealWidth: thumbnailSize.width, idealHeight: thumbnailSize.height)
                .aspectRatio(thumbnailSize, contentMode: .fit)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .if(cornerRadius != 0) { $0.modifier(MessageCornerRadius(model: message, radius: cornerRadius)) }
                .messageGesture(onLongPress: onLongGesture)
        } else {
            DefaultTransferView(model: message, time: messageTime, onLongGesture: onLongGesture)
        }
    }

    @ViewBuilder private var thumbnailPlaceholder: some View {
        let fill = Color(UIColor.secondarySystemFill)
        if cornerRadius != 0 {
            fill
        } else if let notch = notch {
            GeometryReader { proxy in
                MessageBubbleShape(radius: message.cornerRadius, corners: message.corners,
                                   notch: MessageBubbleNotch.local(notch, in: proxy))
                    .fill(fill)
            }
        } else {
            MessageBubbleShape(radius: message.cornerRadius, corners: message.corners).fill(fill)
        }
    }
}

struct AccessibilityGestureModifier: ViewModifier {
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onTapGesture {
            action() // Call the action when the gesture is detected
        }
    }
}
