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
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.messageDeletedText)
                        .font(model.textFont)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    editingIndicator()
                }
                .applyMessageStyle(model: model)
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
    }

    private func renderCallMessage() -> some View {
        Text(model.content)
            .padding(.horizontal, model.textInset)
            .padding(.vertical, model.textVerticalInset)
            .foregroundColor(model.textColor)
            .lineLimit(1)
            .background(model.backgroundColor)
            .font(model.textFont)
            .modifier(MessageCornerRadius(model: model))
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                    .modifier(MessageCornerRadius(model: model))
            } else if model.content.isValidURL, let url = model.getURL() {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.content)
                        .font(model.textFont)
                        .onTapGesture {
                            openURL(url)
                        }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                    editingIndicator()
                }
                .applyMessageStyle(model: model)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.content)
                        .font(model.textFont)
                        .lineLimit(nil)
                        .onTapGesture { }
                        .modifier(MessageLongPress(longPressCb: receivedLongPress()))
                    editingIndicator()
                }
                .applyMessageStyle(model: model)
            }
        }
    }

    private func editingIndicator() -> some View {
        HStack {
            Image(systemName: "pencil")
                .resizable()
                .imageScale(.large)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)
            Text(model.editeIndicator)
                .font(.footnote)
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
    }

    private func receivedLongPress() -> (() -> Void) {
        return {
            if model.menuItems.isEmpty { return }
            presentMenu = true
        }
    }
}
