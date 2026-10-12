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
    @Environment(\.openURL)
    var openURL
    @Environment(\.suppressLongPress)
    private var suppressLongPress
    @Environment(\.layoutDirection)
    private var layoutDirection
    @Binding var menuRequest: ContextMenuMode?
    var onLongPress: (_ frame: CGRect, _ message: MessageBubbleView, _ mode: ContextMenuMode) -> Void
    let padding: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading) {
            if model.messageDeleted {
                MessageBubbleWithTimeWrapper(model: model, requestMenu: requestMenu) {
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
                    .onChange(of: menuRequest, perform: { mode in
                        guard let mode = mode else { return }
                        let frame = proxy.frame(in: .global)
                        menuRequest = nil
                        onLongPress(frame, self, mode)
                    })
            }
        )
        .accessibilityElement(children: .ignore)
        .modifier(ReplyQuoteAccessibility(reply: messageModel.replyTarget,
                                          messageLabel: model.accessibilityLabelValue,
                                          showsReplyQuote: model.isHistory && !model.messageDeleted))
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
        .conditionalModifier(AccessibilityActionModifier(actionName: ContextualMenuItem.editHistory.toString(),
                                                         action: { requestMenu(.editHistory) }),
                             apply: model.menuItems.contains(.editHistory))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func textBubble<Content: View>(@ViewBuilder _ text: @escaping (_ minWidth: CGFloat?) -> Content) -> some View {
        if model.isHistory && model.hasBubbleBackground {
            ReplyBubbleContainer(model: model, reply: messageModel.replyTarget, layout: .text, onLongPress: receivedLongPress()) { minBubbleWidth in
                MessageBubbleWithTimeWrapper(model: model, requestMenu: requestMenu) {
                    text(minBubbleWidth.map { max(0, $0 - 2 * model.textInset) })
                }
            }
        } else {
            MessageBubbleWithTimeWrapper(model: model, requestMenu: requestMenu) {
                if model.isHistory {
                    VStack(alignment: model.isIncoming ? .leading : .trailing, spacing: 4) {
                        ReplyQuote(reply: messageModel.replyTarget, message: model, onLongPress: receivedLongPress())
                        text(nil)
                    }
                } else {
                    text(nil)
                }
            }
        }
    }

    private var replyMediaCornerRadius: CGFloat {
        model.cornerRadius - ReplyBubbleLayout.media.contentInset
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
                    Group {
                        if model.isHistory {
                            ReplyBubbleContainer(model: model, reply: messageModel.replyTarget, layout: .media, onLongPress: receivedLongPress()) { _ in
                                URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                                    .cornerRadius(replyMediaCornerRadius)
                                    .messageGesture(onLongPress: receivedLongPress())
                            }
                        } else {
                            URLPreview(metadata: metadata, maxDimension: model.maxDimension)
                                .modifier(MessageCornerRadius(model: model))
                                .messageGesture(onLongPress: receivedLongPress())
                        }
                    }
                    .marksMessageBubbleBottom()
                    MessageTimeView(text: model.timeText, color: model.timeColor)
                }
            } else if model.isFullURL, let url = model.getURL() {
                textBubble { minWidth in
                    Text(model.content)
                        .font(model.styling.textFont)
                        .underline()
                        .withInlineTime(model.inlineTimeText(in: layoutDirection), color: model.timeColor, minWidth: minWidth)
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

    private func renderBubbleTextBody() -> some View {
        textBubble { minWidth in
            MessageBubbleTextRenderer(textBody: model.bubbleTextBody,
                                      font: model.styling.textFont,
                                      inlineTime: model.inlineTimeText(in: layoutDirection),
                                      timeColor: model.timeColor,
                                      minWidth: minWidth)
                .lineLimit(nil)
                .messageGesture(onLongPress: receivedLongPress())
        }
    }

    private func renderFileTransfer() -> some View {
        Group {
            if model.isHistory {
                ReplyBubbleContainer(model: model, reply: messageModel.replyTarget, layout: hasVisualMedia ? .media : .inset, onLongPress: receivedLongPress()) { _ in
                    fileTransferMedia(cornerRadius: hasVisualMedia ? replyMediaCornerRadius : 0)
                }
            } else {
                fileTransferMedia(cornerRadius: 0)
            }
        }
        .marksMessageBubbleBottom()
    }

    private var hasImage: Bool {
        model.player == nil && (model.finalImage != nil || model.thumbnailSize != nil)
    }

    private var hasVisualMedia: Bool {
        hasImage || model.player?.hasVideo.value == true
    }

    @ViewBuilder
    private func fileTransferMedia(cornerRadius: CGFloat) -> some View {
        let media = MediaView(message: model, onLongGesture: receivedLongPress(), minHeight: 50, maxHeight: 300, withPlayerControls: true, cornerRadius: cornerRadius, messageTime: model.timeText)
        if hasImage {
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
        return { requestMenu(.actions) }
    }

    private func requestMenu(_ mode: ContextMenuMode) {
        if model.menuItems.isEmpty { return }
        if mode == .editHistory && !model.menuItems.contains(.editHistory) { return }
        if suppressLongPress { return }
        menuRequest = mode
    }
}

struct MessageBubbleWithTimeWrapper<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    @Environment(\.layoutDirection)
    private var layoutDirection
    @ScaledMetric(relativeTo: .caption2)
    private var editedFontSize = TimeLayout.editedFontSize
    @ScaledMetric(relativeTo: .caption2)
    private var editedChevronSize = TimeLayout.editedChevronSize
    @ScaledMetric(relativeTo: .caption2)
    private var editedRowHeight = TimeLayout.editedRowHeight
    let requestMenu: (ContextMenuMode) -> Void
    let content: Content

    init(model: MessageContentVM, requestMenu: @escaping (ContextMenuMode) -> Void, @ViewBuilder content: () -> Content) {
        self.model = model
        self.requestMenu = requestMenu
        self.content = content()
    }

    @ViewBuilder var body: some View {
        switch model.timePlacement(in: layoutDirection) {
        case .belowEmoji:
            VStack(alignment: model.isIncoming ? .leading : .trailing, spacing: 0) {
                content
                    .applyMessageStyle(model: model)
                if model.showsTimeBelowEmoji {
                    MessageTimeView(text: model.timeText, color: model.timeColor)
                }
            }
        case .editedRow:
            // The hidden copy reserves the footer's width so a short text keeps its leading edge.
            VStack(alignment: .leading, spacing: TimeLayout.editedFooterTop) {
                content
                editingIndicator()
                    .hidden()
            }
            .overlay(alignment: .bottomTrailing) {
                editingIndicator()
            }
            .padding(.bottom, max(0, TimeLayout.editedFooterBottom - model.textVerticalInset))
            .applyMessageStyle(model: model)
            .overlay(alignment: .bottom) {
                Color.clear
                    .frame(height: TimeLayout.editedFooterTop + editedRowHeight + TimeLayout.editedFooterBottom)
                    .messageGesture(onLongPress: { requestMenu(.actions) },
                                    onTap: { _, _ in requestMenu(.editHistory) })
            }
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
        HStack(spacing: TimeLayout.editedTimeSpacing) {
            // Stronger than the time and joined to its chevron, so it reads as the tappable part.
            (Text(model.editIndicator + "\u{2009}")
                .font(.system(size: editedFontSize, weight: .medium))
             + Text(Image(systemName: "chevron.forward"))
                .font(.system(size: editedChevronSize, weight: .bold)))
                .foregroundColor(model.styling.textColor.opacity(TimeLayout.editedOpacity))
                .lineLimit(1)
                .fixedSize()
                .allowsHitTesting(false)
            MessageTimeView(text: model.timeText, color: model.timeColor)
        }
        .frame(height: editedRowHeight)
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
    static let editedFooterTop: CGFloat = 12
    static let editedFooterBottom: CGFloat = 12
    static let editedRowHeight: CGFloat = 13
    static let editedTimeSpacing: CGFloat = 10
    static let editedFontSize: CGFloat = 11
    static let editedChevronSize: CGFloat = 8
    static let editedOpacity: CGFloat = 0.75
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
