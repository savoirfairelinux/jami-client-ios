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
    var media: MessageMedia
    let onLongGesture: () -> Void
    var ratio: CGFloat = 1
    var withControls: Bool
    var customCornerRadius: CGFloat = 0
    var messageTime: String?
    @Environment(\.colorScheme)
    var colorScheme
    @Environment(\.drawsMessageBubble)
    private var drawsMessageBubble

    var body: some View {
        ZStack(alignment: .center) {
            if colorScheme == .dark && media.item.preview.hasVideo {
                model.borderColor
                    .frame(width: model.playerWidth * ratio + 2, height: model.playerHeight * ratio + 2)
                    .conditionalModifier(MessageCornerRadius(model: model), apply: customCornerRadius == 0)
                    .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
            }
            PlayerView(media: media, poster: model.posterImage, sizeMode: .inConversationMessage, withControls: withControls,
                       onVideoTap: { frame, frameProvider in model.presentMediaPreview(sourceFrame: frame, sourceFrameProvider: frameProvider) },
                       onVideoLongPress: onLongGesture,
                       audioColors: drawsMessageBubble ? model.audioPlayerColors : model.audioPlayerColors.withoutBackground(),
                       messageTime: messageTime)
                .frame(height: model.playerHeight * ratio)
                .frame(width: model.playerWidth * ratio)
                .conditionalModifier(MessageCornerRadius(model: model), apply: customCornerRadius == 0)
                .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? L10n.Accessibility.audioPlayerPause : L10n.Accessibility.audioPlayerPlay)
        .accessibilityAddTraits(.isButton)
        .conditionalModifier(AccessibilityGestureModifier(action: togglePauseWithVoiceOver), apply: UIAccessibility.isVoiceOverRunning)
    }

    private var activePlayer: PlayerViewModel? {
        media.playback?.player(for: media.item.id)
    }

    private var isPlaying: Bool {
        activePlayer.map { !$0.isPaused.value } ?? false
    }

    private func togglePauseWithVoiceOver() {
        guard media.item.preview.isPlayable, activePlayer?.playbackFailed.value != true else {
            UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.audioPlayerUnavailable)
            return
        }
        media.playback?.togglePlay(media.item)
    }
}

struct ImageOrGifView: View {
    @ObservedObject var message: MessageContentVM

    var image: UIImage
    let onLongGesture: () -> Void
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var customCornerRadius: CGFloat = 0

    var body: some View {
        mediaContent
            .conditionalModifier(MessageCornerRadius(model: message), apply: customCornerRadius == 0)
            .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
            .messageGesture(
                onLongPress: onLongGesture,
                onTap: { frame, frameProvider in message.presentMediaPreview(sourceFrame: frame, sourceFrameProvider: frameProvider) }
            )
    }

    @ViewBuilder
    private var mediaContent: some View {
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
    var body: some View {
        if let media = self.message.media {
            PlayerSwiftUI(model: message, media: media, onLongGesture: onLongGesture, withControls: withPlayerControls, customCornerRadius: cornerRadius, messageTime: messageTime)
        } else if let image = message.finalImage {
            ImageOrGifView(message: message, image: image, onLongGesture: onLongGesture, minHeight: minHeight, maxHeight: maxHeight, customCornerRadius: cornerRadius)

        } else if let thumbnailSize = message.thumbnailSize {
            Color(UIColor.secondarySystemFill)
                .frame(idealWidth: thumbnailSize.width, idealHeight: thumbnailSize.height)
                .aspectRatio(thumbnailSize, contentMode: .fit)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .conditionalModifier(MessageCornerRadius(model: message), apply: cornerRadius == 0)
                .conditionalCornerRadius(cornerRadius, apply: cornerRadius != 0)
                .messageGesture(onLongPress: onLongGesture)
        } else {
            DefaultTransferView(model: message, time: messageTime, onLongGesture: onLongGesture)
                .conditionalModifier(MessageCornerRadius(model: message), apply: cornerRadius == 0)
                .conditionalCornerRadius(cornerRadius, apply: cornerRadius != 0)
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
