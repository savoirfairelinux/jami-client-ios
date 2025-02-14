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
        VStack(alignment: .leading) {
            if model.messageDeleted {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.messageDeletedText)
                        .font(model.styling.secondaryFont)
                        .foregroundColor(model.editionColor)
                }
            } else {
                if model.type == .call {
                    renderCallMessage()
                } else if model.type == .fileTransfer {
                    MediaView(message: model, onLongGesture: receivedLongPress(), minHeight: 50, maxHeight: 300, withPlayerControls: true, cornerRadius: 0)
                } else if model.type == .text {
                    renderTextContent()
                }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.accessibilityLabelValue))
    }

    private func renderCallMessage() -> some View {
        Text(model.content)
            .padding(.horizontal, model.textInset)
            .padding(.vertical, model.textVerticalInset)
            .foregroundColor(model.styling.textColor)
            .lineLimit(nil)
            .background(model.backgroundColor)
            .font(model.styling.textFont)
            .modifier(MessageCornerRadius(model: model))
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                    .modifier(MessageCornerRadius(model: model))
            } else if model.content.isValidURL, let url = model.getURL() {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.content)
                        .font(model.styling.textFont)
                        .underline()
                        .onTapGesture {
                            openURL(url)
                        }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                }
            } else {
                MessageBubbleWithEditionWrapper(model: model) {
                    Text(model.content)
                        .font(model.styling.textFont)
                        .lineLimit(nil)
                        .onTapGesture {
                            // Add an empty onTapGesture to keep the table view scrolling smooth
                        }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                }
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

struct MessageBubbleWithEditionWrapper<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    let content: Content
    let messageEditedPadding: CGFloat = 4

    init(model: MessageContentVM, @ViewBuilder content: () -> Content) {
        self.model = model
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: messageEditedPadding) {
            content

            if model.messageEdited {
                editingIndicator()
            }
        }
        .applyMessageStyle(model: model)
    }

    private func editingIndicator() -> some View {
        HStack(spacing: 2) {
            Image(systemName: "pencil")
                .resizable()
                .font(Font.body.weight(.bold))
                .foregroundColor(model.editionColor)
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 12)
            Text(model.editIndicator)
                .font(.footnote)
                .foregroundColor(model.editionColor)
        }
    }
}
