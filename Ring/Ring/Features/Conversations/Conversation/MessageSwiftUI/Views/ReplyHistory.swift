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
    let model: MessageReplyTargetVM
    var target: MessageContentVM? {
        return model.target
    }
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL
    var body: some View {
        VStack(alignment: .leading) {
            if let target = self.target {
                Text(model.inReplyTo)
                if target.type == .fileTransfer {
                    if let player = target.player {
                        ZStack(alignment: .center) {
                            if colorScheme == .dark {
                                target.borderColor
                                    .modifier(MessageCornerRadius(model: target))
                                    .frame(width: target.playerWidth + 2, height: target.playerHeight + 2)
                            }
                            PlayerSwiftUI(model: target, player: player, onLongGesture: {})
                                .modifier(MessageCornerRadius(model: target))
                        }
                    } else if let image = target.finalImage {
                        if !target.isGifImage() {
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
                                .modifier(MessageCornerRadius(model: target))
                        } else {
                            ScaledImageViewWrapper(imageToShow: image)
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .onTapGesture {}
                                .modifier(MessageCornerRadius(model: target))
                        }
                    } else {
                        DefaultTransferView(model: target, onLongGesture: {})
                            .modifier(MessageCornerRadius(model: target))
                    }
                } else if target.type == .text {
                    if let metadata = target.metadata {
                        URLPreview(metadata: metadata, maxDimension: target.maxDimension)
                            .modifier(MessageCornerRadius(model: target))
                    } else if target.content.isValidURL, let url = target.getURL() {
                        Text(target.content)
                            // .modifier(MessageReplyStyle(model: model))
                            // .applyTextStyle(model: model)
                            .onTapGesture(perform: {
                                openURL(url)
                            })
                    } else {
                        Text(target.content)
                            .modifier(MessageReplyStyle(model: target))
                            .lineLimit(nil)
                    }
                }
            }
        }
        .onAppear {
            self.target?.onAppear()
        }
        .opacity(0.4)
        .scaleEffect(0.7, anchor: .bottomLeading)
    }
}