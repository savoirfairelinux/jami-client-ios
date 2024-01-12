/*
 *  Copyright (C) 2023-2024 Savoir-faire Linux Inc.
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

struct MessageBubbleView: View {
    let messageModel: MessageContainerModel
    @StateObject var model: MessageContentVM
    @SwiftUI.State private var frame: CGRect = .zero
    @SwiftUI.State private var presentMenu = false
    @Environment(\.openURL) var openURL
    @Environment(\.colorScheme) var colorScheme
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    let padding: CGFloat = 12
    var body: some View {
        VStack {
            if model.type == .call {
                renderCallMessage()
            } else if model.type == .fileTransfer {
                renderMediaContent()
            } else if model.type == .text {
                renderTextContent()
            }
        }
        .background(
            GeometryReader { proxy in
                Rectangle().fill(Color.clear)
                    .onChange(of: presentMenu, perform: { _ in
                        if !presentMenu {
                            return
                        }
                        DispatchQueue.main.async {
                            let frame = proxy.frame(in: .global)
                            presentMenu = false
                            onLongPress(frame, self)
                        }
                    })
            }
        )
    }

    private func renderCallMessage() -> some View {
        Text(model.content)
            .padding(model.textInset)
            .foregroundColor(model.textColor)
            .lineLimit(1)
            .background(model.backgroundColor)
            .font(model.textFont)
            .modifier(MessageCornerRadius(model: model))
    }

    private func renderImage(image: UIImage) -> some View {
        Group {
            if !model.isGifImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: 50, maxHeight: 300)
                    .onTapGesture { }
                    .modifier(MessageCornerRadius(model: model))
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            } else {
                ScaledImageViewWrapper(imageToShow: image)
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .onTapGesture { }
                    .modifier(MessageCornerRadius(model: model))
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            }
        }
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                    .modifier(MessageCornerRadius(model: model))
            } else if model.content.isValidURL, let url = model.getURL() {
                Text(model.content)
                    .applyTextStyle(model: model)
                    .onTapGesture {
                        openURL(url)
                    }
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            } else {
                Text(model.content)
                    .applyTextStyle(model: model)
                    .lineLimit(nil)
                    .onTapGesture { }
                    .modifier(MessageLongPress(longPressCb: receivedLongPress()))
            }
        }
    }

    private func renderMediaContent() -> some View {
        Group {
            if let player = self.model.player {
                ZStack(alignment: .center) {
                    if colorScheme == .dark {
                        model.borderColor
                            .modifier(MessageCornerRadius(model: model))
                            .frame(width: model.playerWidth + 2, height: model.playerHeight + 2)
                    }
                    PlayerSwiftUI(model: model, player: player, onLongGesture: receivedLongPress())
                        .modifier(MessageCornerRadius(model: model))
                }
            } else if let image = model.finalImage {
                renderImage(image: image)
            } else {
                DefaultTransferView(model: model, onLongGesture: receivedLongPress())
                    .modifier(MessageCornerRadius(model: model))
            }
        }
    }

    private func receivedLongPress() -> (() -> Void) {
        return {
            if model.menuItems.isEmpty { return }
            presentMenu = true
        }
    }
}
