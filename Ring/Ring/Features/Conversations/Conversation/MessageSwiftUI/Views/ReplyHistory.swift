/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
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

struct MessageReplyStyle: ViewModifier {
    @ObservedObject var model: MessageContentVM

    func body(content: Content) -> some View {
        content
            .padding(.top, 5)
            .padding(.bottom, 5)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .foregroundColor(Color(UIColor.label))
            .background(Color(UIColor.lightGray))
            .font(.footnote)
            .cornerRadius(model.cornerRadius)
    }
}

struct ReplyHistory: View {
    @ObservedObject var model: MessageReplyTargetVM

    var body: some View {
        VStack(alignment: model.alignment, spacing: 4) {
            if let target = model.target {
                Text(model.inReplyTo)
                    .font(model.styling.secondaryFont)
                    .foregroundColor(model.styling.secondaryTextColor)
                    .onAppear {
                        target.onAppear()
                    }
                ReplyTargetContent(model: model, target: target)
            }
        }
    }
}

private struct ReplyTargetContent: View {
    let model: MessageReplyTargetVM
    @ObservedObject var target: MessageContentVM

    var body: some View {
        if target.messageDeleted {
            Text(L10n.Conversation.lastMessageDeleted)
                .italic()
                .modifier(MessageReplyStyle(model: target))
                .font(target.styling.secondaryFont)
                .opacity(0.4)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            model.scrollToReplyTarget()
                        }
                )
        } else if target.type == .fileTransfer {
            if let image = target.finalImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(minHeight: model.imageMinHeight, maxHeight: model.imageMaxHeight)
                    .cornerRadius(15)
                    .opacity(0.7)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                model.scrollToReplyTarget()
                            }
                    )
            } else {
                Text(target.displayContent)
                    .modifier(MessageReplyStyle(model: target))
                    .font(target.styling.textFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .opacity(0.4)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                model.scrollToReplyTarget()
                            }
                    )
            }
        } else if target.type == .text {
            if let metadata = target.metadata {
                URLPreview(metadata: metadata, maxDimension: target.maxDimension * model.sizeIndex)
                    .cornerRadius(target.cornerRadius)
                    .opacity(0.7)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                model.scrollToReplyTarget()
                            }
                    )
            } else {
                Text(target.displayContent)
                    .modifier(MessageReplyStyle(model: target))
                    .font(target.styling.textFont)
                    .lineLimit(nil)
                    .opacity(0.4)
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                model.scrollToReplyTarget()
                            }
                    )
            }
        }
    }
}
