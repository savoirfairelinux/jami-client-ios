/*
 *  Copyright (C) 2023-2025 Savoir-faire Linux Inc.
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
import UIKit

struct MessageBubbleView: View {
    let messageModel: MessageContainerModel
    @ObservedObject var model: MessageContentVM
    @SwiftUI.State private var frame: CGRect = .zero
    @SwiftUI.State private var presentMenu = false
    @Environment(\.openURL)
    var openURL
    @Environment(\.suppressLongPress)
    private var suppressLongPress
    @Environment(\.layoutDirection)
    private var layoutDirection
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView) -> Void
    let padding: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading) {
            if model.messageDeleted {
                MessageBubbleWithTimeWrapper(model: model) {
                    Text(model.messageDeletedText)
                        .font(model.styling.secondaryFont)
                        .foregroundColor(model.editionColor)
                        .withInlineTime(model.inlineTimeText(in: layoutDirection), color: model.timeColor)
                }
            } else {
                if model.type == .call {
                    renderCallMessage()
                } else if model.type == .fileTransfer {
                    renderFileTransfer()
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
                        let frame = proxy.frame(in: .global)
                        presentMenu = false
                        onLongPress(frame, self)
                    })
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(model.accessibilityLabelValue))
        .accessibilityCustomContent(Text(model.accessibilityDateLabel), Text(model.fullDateText))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.preview.toString(), action: { model.contextMenuSelect(item: .preview) }), apply: model.menuItems.contains(.preview))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.forward.toString(), action: { model.contextMenuSelect(item: .forward) }), apply: model.menuItems.contains(.forward))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.share.toString(), action: { model.contextMenuSelect(item: .share) }), apply: model.menuItems.contains(.share))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.save.toString(), action: { model.contextMenuSelect(item: .save) }), apply: model.menuItems.contains(.save))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.copy.toString(), action: { model.contextMenuSelect(item: .copy) }), apply: model.menuItems.contains(.copy))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.reply.toString(), action: { model.contextMenuSelect(item: .reply) }), apply: model.menuItems.contains(.reply))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.deleteMessage.toString(), action: { model.contextMenuSelect(item: .deleteMessage) }), apply: model.menuItems.contains(.deleteMessage))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.deleteFile.toString(), action: { model.contextMenuSelect(item: .deleteFile) }), apply: model.menuItems.contains(.deleteFile))
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.edit.toString(), action: { model.contextMenuSelect(item: .edit) }), apply: model.menuItems.contains(.edit))
        .accessibilityAddTraits(.isButton)
    }

    private func renderCallMessage() -> some View {
        Text(model.content)
            .withInlineTime(model.timeText, color: model.timeColor)
            .padding(.horizontal, model.textInset)
            .padding(.vertical, model.textVerticalInset)
            .foregroundColor(model.styling.textColor)
            .lineLimit(nil)
            .background(MessageBubbleFill(model: model))
            .font(model.styling.textFont)
            .modifier(MessageCornerRadius(model: model))
            .marksMessageBubbleBottom()
    }

    private func renderTextContent() -> some View {
        Group {
            if let metadata = model.metadata {
                VStack(alignment: .trailing, spacing: TimeLayout.outsideSpacing) {
                    URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                        .modifier(MessageCornerRadius(model: model))
                        .messageGesture(onLongPress: receivedLongPress())
                        .marksMessageBubbleBottom()
                    MessageTimeView(text: model.timeText, color: model.styling.secondaryTextColor)
                }
            } else if model.isFullURL, let url = model.getURL() {
                MessageBubbleWithTimeWrapper(model: model) {
                    Text(model.content)
                        .font(model.styling.textFont)
                        .underline()
                        .withInlineTime(model.inlineTimeText(in: layoutDirection), color: model.timeColor)
                        .onTapGesture {
                            openURL(url)
                        }
                        .messageGesture(onLongPress: receivedLongPress())
                }
            } else {
                renderBubbleTextBody()
            }
        }
    }

    @ViewBuilder
    private func renderBubbleTextBody() -> some View {
        MessageBubbleWithTimeWrapper(model: model) {
            MessageBubbleTextRenderer(textBody: model.bubbleTextBody,
                                      font: model.styling.textFont,
                                      inlineTime: model.inlineTimeText(in: layoutDirection),
                                      timeColor: model.timeColor)
                .lineLimit(nil)
                .messageGesture(onLongPress: receivedLongPress())
        }
    }

    @ViewBuilder
    private func renderFileTransfer() -> some View {
        let media = MediaView(message: model, onLongGesture: receivedLongPress(), minHeight: 50, maxHeight: 300, withPlayerControls: true, cornerRadius: 0, messageTime: model.timeText)
            .marksMessageBubbleBottom()
        if model.player == nil, model.finalImage != nil {
            media
                .overlay(alignment: .bottomTrailing) {
                    MessageTimeCapsule(text: model.timeText)
                        .padding(TimeLayout.capsuleInset)
                }
        } else {
            media
        }
    }

    private func receivedLongPress() -> (() -> Void) {
        return {
            if model.menuItems.isEmpty { return }
            if suppressLongPress { return }
            presentMenu = true
        }
    }
}

struct MessageBubbleWithTimeWrapper<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    @Environment(\.layoutDirection)
    private var layoutDirection
    let content: Content

    init(model: MessageContentVM, @ViewBuilder content: () -> Content) {
        self.model = model
        self.content = content()
    }

    @ViewBuilder var body: some View {
        switch model.timePlacement(in: layoutDirection) {
        case .belowEmoji:
            VStack(alignment: model.isIncoming ? .leading : .trailing, spacing: 0) {
                content
                    .applyMessageStyle(model: model)
                if model.endsEmojiRun {
                    MessageTimeView(text: model.timeText, color: model.timeColor)
                }
            }
        case .editedRow:
            VStack(alignment: .leading, spacing: TimeLayout.editedSpacing) {
                content
                editingIndicator()
            }
            .applyMessageStyle(model: model)
        case .belowText:
            VStack(alignment: .trailing, spacing: TimeLayout.editedSpacing) {
                content
                MessageTimeView(text: model.timeText, color: model.timeColor)
            }
            .applyMessageStyle(model: model)
        case .inline:
            content
                .applyMessageStyle(model: model)
        }
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
            MessageTimeView(text: model.timeText, color: model.timeColor)
                .padding(.leading, TimeLayout.editedSpacing)
        }
    }
}

extension VerticalAlignment {
    private enum MessageBubbleBottom: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.bottom]
        }
    }

    static let messageBubbleBottom = VerticalAlignment(MessageBubbleBottom.self)
}

extension View {
    func marksMessageBubbleBottom() -> some View {
        alignmentGuide(.messageBubbleBottom) { $0[.bottom] }
    }
}

private enum TimeLayout {
    static let outsideSpacing: CGFloat = 2
    static let editedSpacing: CGFloat = 4
    static let capsuleInset: CGFloat = 8
}

struct AccessibilityActionModifier: ViewModifier {
    let actionName: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text(actionName)) {
                action()
            }
    }
}
