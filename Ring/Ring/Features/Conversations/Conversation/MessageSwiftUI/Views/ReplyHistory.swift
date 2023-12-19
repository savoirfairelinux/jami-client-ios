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

struct ReplyHistory: View {
    let messageModel: MessageContainerModel
    var model: MessageContentVM? {
        return messageModel.replyTo
    }
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    var body: some View {
        VStack {
            if let model = self.model {
                Text("in reply to")
                if model.type == .fileTransfer {
                    if let player = model.player {
                        ZStack(alignment: .center) {
                            if colorScheme == .dark {
                                model.borderColor
                                    .modifier(MessageCornerRadius(model: model))
                                    .frame(width: model.playerWidth + 2, height: model.playerHeight + 2)
                            }
                            PlayerSwiftUI(model: model, player: player, onLongGesture: {})
                                .modifier(MessageCornerRadius(model: model))
                        }
                    } else if let image = model.finalImage {
                        if !model.isGifImage() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(minHeight: 50, maxHeight: 300)
                                /*
                                 Views with long press tap gesture prevent table from receiving
                                 tap gesture and it causing scroll issue.
                                 Adding empty onTapGesture fixes this.
                                 */
                                .onTapGesture {}
                                .modifier(MessageCornerRadius(model: model))
                        } else {
                            ScaledImageViewWrapper(imageToShow: image)
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .onTapGesture {}
                                .modifier(MessageCornerRadius(model: model))
                        }
                    } else {
                        DefaultTransferView(model: model, onLongGesture: {})
                            .modifier(MessageCornerRadius(model: model))
                    }
                } else if model.type == .text {
                    if let metadata = model.metadata {
                        URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                            .modifier(MessageCornerRadius(model: model))
                    } else if model.content.isValidURL, let url = model.getURL() {
                        Text(model.content)
                            .modifier(MessageReplyStyle(model: model))
                            // .applyTextStyle(model: model)
                            .onTapGesture(perform: {
                                openURL(url)
                            })
                    } else {
                        Text(model.content)
                            .modifier(MessageReplyStyle(model: model))
                            // .applyTextStyle(model: model)
                            .lineLimit(nil)
                            // add onTapGesture to fix scroll
                            .onTapGesture {}
                        // .modifier(MessageLongPress(longPressCb: {}))
                    }
                }
            }
        }
        .onAppear {
            self.model?.onAppear()
        }
        // .background(Color.red)
        .opacity(0.4)
        .scaleEffect(0.9, anchor: .bottomLeading)
    }
}
