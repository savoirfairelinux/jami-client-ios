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
    let onLongPress: () -> Void

    private let cardInset = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    private let cardCornerRadius: CGFloat = 12

    var body: some View {
        quote
            .if(!message.hasBubbleBackground) { view in
                view
                    .padding(cardInset)
                    .background(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                    .fill(Color(UIColor.tertiarySystemFill)))
            }
    }

    @ViewBuilder private var quote: some View {
        if let line = reply.line {
            ReplyQuoteContent(reply: reply,
                              authorName: reply.authorName,
                              line: line,
                              thumbnail: reply.thumbnail,
                              accent: message.replyQuoteAccentColor,
                              textColor: message.styling.textColor,
                              onLongPress: onLongPress)
        } else {
            ReplyQuoteFrame(accent: message.replyQuoteAccentColor.opacity(0.4), isHighlighted: false) {
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
    let onLongPress: () -> Void

    @SwiftUI.State private var isHighlighted = false

    private let highlightDuration: TimeInterval = 0.25

    var body: some View {
        ReplyQuoteFrame(accent: accent, isHighlighted: isHighlighted) {
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
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .footnote)
    var quoteHeight: CGFloat = 40

    private let barWidth: CGFloat = 3
    private let spacing: CGFloat = 7
    private let cornerRadius: CGFloat = 6
    private let highlightOpacity: Double = 0.15

    var body: some View {
        HStack(spacing: spacing) {
            RoundedRectangle(cornerRadius: barWidth / 2)
                .fill(accent)
                .frame(width: barWidth)
                .frame(maxHeight: .infinity)
            content
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: quoteHeight)
        .padding(.vertical, 2)
        .padding(.trailing, spacing)
        .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(accent.opacity(isHighlighted ? highlightOpacity : 0)))
    }
}

enum ReplyBubbleLayout {
    case media
    case inset

    var contentInset: CGFloat {
        switch self {
        case .media: return 4
        case .inset: return 0
        }
    }

    var quoteInsets: EdgeInsets {
        switch self {
        case .media: return EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8)
        case .inset: return EdgeInsets(top: 9, leading: MessageContentVM.bubbleTextInset, bottom: 0, trailing: MessageContentVM.bubbleTextInset)
        }
    }
}

struct ReplyBubbleContainer<Content: View>: View {
    @ObservedObject var model: MessageContentVM
    let reply: MessageReplyTargetVM
    let layout: ReplyBubbleLayout
    let onLongPress: () -> Void
    @ViewBuilder let content: Content

    @SwiftUI.State private var contentWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: layout.contentInset) {
            ReplyQuote(reply: reply, message: model, onLongPress: onLongPress)
                .frame(maxWidth: quoteMaxWidth, alignment: .leading)
                .padding(layout.quoteInsets)
            content
                .environment(\.drawsMessageBubble, false)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ReplyContentWidthKey.self, value: proxy.size.width)
                })
        }
        .onPreferenceChange(ReplyContentWidthKey.self) { width in
            contentWidth = width
        }
        .padding(layout.contentInset)
        .background(MessageBubbleFill(model: model))
        .modifier(MessageCornerRadius(model: model))
    }

    private var quoteMaxWidth: CGFloat? {
        guard contentWidth > 0 else { return nil }
        return max(0, contentWidth - layout.quoteInsets.leading - layout.quoteInsets.trailing)
    }
}

private struct ReplyContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

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
