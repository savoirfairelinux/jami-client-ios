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

struct ReactionRowView: View {
    static let avatarSize = Constants.AvatarSize.conversation30
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 8
    static let avatarSpacing: CGFloat = 12
    private static let inlineReactionLimit = 3
    private static let inlineOwnReactionLimit = 2
    private static let emojiSpacing: CGFloat = 6
    private static let chipContentSpacing: CGFloat = 3
    private static let chipHorizontalPadding: CGFloat = 8
    private static let chipVerticalPadding: CGFloat = 2
    private static let lineSpacing: CGFloat = 2

    static var separatorInset: CGFloat {
        horizontalPadding + avatarSize.points + avatarSpacing
    }

    static func showsReactionsInline(count: Int, isLocal: Bool, usesAccessibilitySize: Bool) -> Bool {
        !usesAccessibilitySize && count <= (isLocal ? inlineOwnReactionLimit : inlineReactionLimit)
    }

    static func idealWidth(name: String, emojis: [String], isLocal: Bool, usesAccessibilitySize: Bool) -> CGFloat {
        let nameWidth = textWidth(name, style: .callout)
        let reactionsWidth: CGFloat
        if isLocal {
            let removeMarkWidth = UIFont.preferredFont(forTextStyle: .caption2).pointSize
            let chipsWidth = emojis.reduce(CGFloat(0)) { width, emoji in
                width + textWidth(emoji, style: .title3) + chipContentSpacing + removeMarkWidth + chipHorizontalPadding * 2
            }
            reactionsWidth = chipsWidth + emojiSpacing * CGFloat(max(0, emojis.count - 1))
        } else {
            reactionsWidth = textWidth(emojis.joined(separator: " "), style: .title3)
        }
        let inline = showsReactionsInline(count: emojis.count, isLocal: isLocal, usesAccessibilitySize: usesAccessibilitySize)
        let contentWidth = inline ? nameWidth + avatarSpacing + reactionsWidth : max(nameWidth, reactionsWidth)
        return ceil(horizontalPadding * 2 + avatarSize.points + avatarSpacing + contentWidth)
    }

    static func height(count: Int, isLocal: Bool, usesAccessibilitySize: Bool) -> CGFloat {
        let nameLine = UIFont.preferredFont(forTextStyle: .callout).lineHeight
        let emojiLine = UIFont.preferredFont(forTextStyle: .title3).lineHeight + (isLocal ? chipVerticalPadding * 2 : 0)
        let inline = showsReactionsInline(count: count, isLocal: isLocal, usesAccessibilitySize: usesAccessibilitySize)
        let content = inline ? max(nameLine, emojiLine) : nameLine + lineSpacing + emojiLine
        return ceil(max(avatarSize.points, content) + verticalPadding * 2)
    }

    private static func textWidth(_ text: String, style: UIFont.TextStyle) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: style)]).width
    }

    @ObservedObject var reaction: ReactionsRowViewModel
    let isLocal: Bool
    let pendingRemovals: Set<String>
    let onRemove: (String) -> Void
    @Environment(\.avatarProviderFactory)
    var avatarFactory: AvatarProviderFactory?
    @Environment(\.sizeCategory)
    var sizeCategory

    private var showsReactionsInline: Bool {
        Self.showsReactionsInline(count: reaction.content.count,
                                  isLocal: isLocal,
                                  usesAccessibilitySize: sizeCategory.isAccessibilityCategory)
    }

    var body: some View {
        HStack(alignment: showsReactionsInline ? .center : .top, spacing: Self.avatarSpacing) {
            if let factory = avatarFactory {
                AvatarSwiftUIView(source: factory.provider(for: reaction.jamiId, size: Self.avatarSize))
            }
            if showsReactionsInline {
                name
                    .frame(maxWidth: .infinity, alignment: .leading)
                reactions
            } else {
                VStack(alignment: .leading, spacing: Self.lineSpacing) {
                    name
                    reactions
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .accessibilityElement(children: isLocal ? .contain : .combine)
    }

    private var name: some View {
        HStack(spacing: 0) {
            Text(isLocal ? reaction.username.withoutYourselfSuffix : reaction.username)
                .lineLimit(1)
                .truncationMode(.tail)
            if isLocal {
                Text(String.yourselfSuffix)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .font(.callout)
    }

    @ViewBuilder private var reactions: some View {
        if isLocal {
            removableReactions
        } else {
            Text(reaction.reactions.map(\.emoji).joined(separator: " "))
                .font(.title3)
                .fixedSize(horizontal: showsReactionsInline, vertical: true)
        }
    }

    private var removableReactions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.emojiSpacing) {
                ForEach(reaction.reactions) { item in
                    Button {
                        onRemove(item.id)
                    } label: {
                        HStack(spacing: Self.chipContentSpacing) {
                            Text(item.emoji)
                                .font(.title3)
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding(.horizontal, Self.chipHorizontalPadding)
                        .padding(.vertical, Self.chipVerticalPadding)
                        .background(Capsule().fill(Color(UIColor.tertiarySystemFill)))
                    }
                    .buttonStyle(.plain)
                    .disabled(pendingRemovals.contains(item.id))
                    .opacity(pendingRemovals.contains(item.id) ? 0.4 : 1)
                    .accessibilityLabel(L10n.Accessibility.removeReaction(item.emoji))
                }
            }
        }
        .fixedSize(horizontal: showsReactionsInline, vertical: true)
    }
}
