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

struct ReplyQuote: View {
    @ObservedObject var reply: MessageReplyTargetVM
    @ObservedObject var message: MessageContentVM
    var fillWidth: CGFloat?
    let onLongPress: () -> Void

    @ViewBuilder var body: some View {
        if let line = reply.line {
            ReplyQuoteContent(reply: reply,
                              authorName: reply.authorName,
                              line: line,
                              thumbnail: reply.thumbnail,
                              accent: message.replyQuoteAccentColor,
                              textColor: message.styling.textColor,
                              fillWidth: fillWidth,
                              onLongPress: onLongPress)
        } else {
            ReplyQuoteFrame(accent: message.replyQuoteAccentColor.opacity(0.4), isHighlighted: false, fillWidth: fillWidth) {
                VStack(alignment: .leading, spacing: 1) {
                    Label(L10n.Global.reply, systemImage: "arrowshape.turn.up.left")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(message.replyQuoteAccentColor)
                    Text(L10n.Conversation.replyQuoteUnavailable)
                        .italic()
                        .font(.footnote)
                        .foregroundColor(message.styling.textColor.opacity(0.6))
                }
                .lineLimit(1)
            }
            .messageGesture(onLongPress: onLongPress)
        }
    }
}

private struct ReplyQuoteContent: View {
    let reply: MessageReplyTargetVM
    let authorName: String
    let line: ReplyQuoteLine
    let thumbnail: UIImage?
    let accent: Color
    let textColor: Color
    let fillWidth: CGFloat?
    let onLongPress: () -> Void

    @SwiftUI.State private var isHighlighted = false

    private let highlightDuration: TimeInterval = 0.25

    var body: some View {
        ReplyQuoteFrame(accent: accent, isHighlighted: isHighlighted, fillWidth: fillWidth) {
            ReplyQuoteLabel(title: authorName, line: line, thumbnail: thumbnail, accent: accent, textColor: textColor)
        }
        .onAppear {
            reply.onQuoteAppear()
        }
        .messageGesture(onLongPress: onLongPress, onTap: line.isDeleted ? nil : { _, _ in showOriginal() })
    }

    private func showOriginal() {
        withAnimation(.easeOut(duration: highlightDuration / 2)) { isHighlighted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + highlightDuration) {
            withAnimation(.easeOut(duration: highlightDuration)) { isHighlighted = false }
        }
        reply.scrollToReplyTarget()
    }
}

struct ReplyQuoteLabel: View {
    let title: String
    let line: ReplyQuoteLine
    let thumbnail: UIImage?
    let accent: Color
    let textColor: Color

    private let thumbnailSize: CGFloat = 34
    private let thumbnailCornerRadius: CGFloat = 6

    var body: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous))
        }
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(accent)
            HStack(spacing: 4) {
                if let symbolName = line.symbolName {
                    Image(systemName: symbolName)
                }
                (line.isDeleted ? Text(line.text).italic() : Text(line.text))
                    .truncationMode(line.truncation)
            }
            .font(.footnote)
            .foregroundColor(textColor)
        }
        .lineLimit(1)
    }
}

struct ReplyQuoteFrame<Content: View>: View {
    let accent: Color
    let isHighlighted: Bool
    var fillWidth: CGFloat?
    var isTinted = true
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .footnote)
    var quoteHeight: CGFloat = 40

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 7
    private let cornerRadius = MessageContentVM.bubbleCornerRadius - ReplyBubbleLayout.quoteMargin
    private let tintOpacity: Double = 0.12
    private let highlightOpacity: Double = 0.25

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
        .frame(height: quoteHeight)
        .padding(.vertical, 2)
        .padding(.leading, barWidth + spacing)
        .padding(.trailing, spacing)
        .reportingWidth(ReplyQuoteWidthKey.self)
        .frame(minWidth: fillWidth, alignment: .leading)
        .background(accent.opacity(fillOpacity))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: barWidth)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var fillOpacity: Double {
        if isHighlighted { return highlightOpacity }
        return isTinted ? tintOpacity : 0
    }
}

struct ReplyQuoteWidthKey: MeasuredWidthKey {}

enum ReplyBubbleLayout {
    case media
    case inset
    case text

    static let quoteMargin: CGFloat = 6

    var contentInset: CGFloat {
        switch self {
        case .media: return 4
        case .inset, .text: return 0
        }
    }

    var quoteInsets: EdgeInsets {
        let inset = Self.quoteMargin - contentInset
        return EdgeInsets(top: inset, leading: inset, bottom: 0, trailing: inset)
    }

    var growsWithQuote: Bool {
        self == .text
    }
}

struct ReplyBubbleContainer<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    let reply: MessageReplyTargetVM
    let layout: ReplyBubbleLayout
    let onLongPress: () -> Void
    @ViewBuilder let content: (_ minBubbleWidth: CGFloat?) -> Content

    @SwiftUI.State private var quoteWidth: CGFloat = 0
    @SwiftUI.State private var contentWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: layout.contentInset) {
            ReplyQuote(reply: reply, message: model, fillWidth: quoteFillWidth, onLongPress: onLongPress)
                .if(layout.growsWithQuote) { $0.onMeasuredWidthChange(ReplyQuoteWidthKey.self, into: $quoteWidth) }
                .frame(maxWidth: layout.growsWithQuote ? nil : quoteFillWidth, alignment: .leading)
                .padding(layout.quoteInsets)
            content(minBubbleWidth)
                .environment(\.drawsMessageBubble, false)
                .measuringWidth(ReplyContentWidthKey.self, into: $contentWidth)
        }
        .padding(layout.contentInset)
        .background(MessageBubbleFill(model: model))
        .modifier(MessageCornerRadius(model: model))
    }

    private var quoteHorizontalInsets: CGFloat {
        layout.quoteInsets.leading + layout.quoteInsets.trailing
    }

    private var quoteFillWidth: CGFloat? {
        guard contentWidth > 0 else { return nil }
        return max(0, contentWidth - quoteHorizontalInsets)
    }

    private var minBubbleWidth: CGFloat? {
        guard layout.growsWithQuote, quoteWidth > 0 else { return nil }
        return quoteWidth + quoteHorizontalInsets
    }
}

private struct ReplyContentWidthKey: MeasuredWidthKey {}

struct ReplyQuoteAccessibility: ViewModifier {
    @ObservedObject var reply: MessageReplyTargetVM
    let messageLabel: String
    let showsReplyQuote: Bool

    private let summaryKey = AccessibilityCustomContentKey(Text(L10n.Conversation.inReplyTo), id: "replyTarget")

    private var label: String {
        guard showsReplyQuote, reply.accessibilitySummary == nil else { return messageLabel }
        return messageLabel + ". " + L10n.Accessibility.inReply
    }

    private var summary: Text? {
        guard showsReplyQuote, let summary = reply.accessibilitySummary else { return nil }
        return Text(summary)
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(Text(label))
            .accessibilityCustomContent(summaryKey, summary, importance: .high)
            .conditionalModifier(AccessibilityActionModifier(actionName: L10n.Accessibility.showReplyTarget, action: reply.scrollToReplyTarget),
                                 apply: showsReplyQuote && reply.canShowTarget)
    }
}
