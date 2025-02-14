/*
 *  Copyright (C) 2022 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI
import RxSwift

struct PlayerViewWrapper: UIViewRepresentable {
    typealias UIViewType = PlayerView

    var viewModel: PlayerViewModel
    var width: CGFloat
    var height: CGFloat
    let onLongGesture: () -> Void
    var withControls: Bool
    let disposeBag = DisposeBag()
    let longGestureRecognizer = UILongPressGestureRecognizer()

    func makeUIView(context: Context) -> PlayerView {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        let player = PlayerView(frame: frame)
        player.withControls = withControls
        player.viewModel = viewModel
        longGestureRecognizer.rx
            .event
            .filter({ event in
                event.state == UIGestureRecognizer.State.began
            })
            .bind(onNext: { _ in
                self.onLongGesture()
            })
            .disposed(by: self.disposeBag)
        longGestureRecognizer.minimumPressDuration = 0.2
        player.addGestureRecognizer(longGestureRecognizer)
        return player
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        let newFrame = CGRect(x: 0, y: 0, width: width, height: height)
        uiView.frame = newFrame
        uiView.frameUpdated()
    }
}

struct PlayerSwiftUI: View {
    @StateObject var model: MessageContentVM
    var player: PlayerViewModel
    let onLongGesture: () -> Void
    var ratio: CGFloat = 1
    var withControls: Bool
    var customCornerRadius: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .center) {
            if colorScheme == .dark {
                model.borderColor
                    .frame(width: model.playerWidth * ratio + 2, height: model.playerHeight * ratio + 2)
                    .conditionalModifier(MessageCornerRadius(model: model), apply: customCornerRadius == 0)
                    .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
            }
            PlayerViewWrapper(viewModel: player, width: model.playerWidth * ratio, height: model.playerHeight * ratio, onLongGesture: onLongGesture, withControls: withControls)
                .frame(height: model.playerHeight * ratio)
                .frame(width: model.playerWidth * ratio)
                .conditionalModifier(MessageCornerRadius(model: model), apply: customCornerRadius == 0)
                .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
        }
        .accessibilityElement(children: .ignore) // Make it one element
        .accessibilityLabel(player.pause.value ? L10n.Accessibility.audioPlayerPlay : L10n.Accessibility.audioPlayerPause)
        .accessibilityAddTraits(.isButton)
        .conditionalModifier(AccessibilityGestureModifier(action: player.toglePause), apply: UIAccessibility.isVoiceOverRunning)
    }
}

struct ImageOrGifView: View {
    @StateObject var message: MessageContentVM

    var image: UIImage
    let onLongGesture: () -> Void
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var customCornerRadius: CGFloat = 0
    var body: some View {
        if !message.isGifImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .conditionalModifier(MessageCornerRadius(model: message), apply: customCornerRadius == 0)
                .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
                .onTapGesture {
                    // Add an empty onTapGesture to keep the table view scrolling smooth
                }
                .modifier(MessageLongPress(longPressCb: onLongGesture))
        } else {
            ScaledImageViewWrapper(imageToShow: image, maxHeight: maxHeight, maxWidth: maxHeight)
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .conditionalModifier(MessageCornerRadius(model: message), apply: customCornerRadius == 0)
                .conditionalCornerRadius(customCornerRadius, apply: customCornerRadius != 0)
                .onTapGesture {
                    // Add an empty onTapGesture to keep the table view scrolling smooth
                }
                .modifier(MessageLongPress(longPressCb: onLongGesture))
        }
    }
}

struct MediaView: View {
    @StateObject var message: MessageContentVM
    let onLongGesture: () -> Void
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let withPlayerControls: Bool
    let cornerRadius: CGFloat
    var body: some View {
        if let player = self.message.player {
            PlayerSwiftUI(model: message, player: player, onLongGesture: onLongGesture, withControls: withPlayerControls, customCornerRadius: cornerRadius)
        } else if let image = message.finalImage {
            ImageOrGifView(message: message, image: image, onLongGesture: onLongGesture, minHeight: minHeight, maxHeight: maxHeight, customCornerRadius: cornerRadius)

        } else {
            DefaultTransferView(model: message, onLongGesture: onLongGesture)
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
