/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import SwiftUI

/// A document is announced in the middle of the conversation, belonging to
/// everyone in it rather than to the side that happened to start it.
struct CollabDocMessageView: View {

    @ObservedObject var model: CollabDocMessageVM

    var body: some View {
        Button(action: model.open) {
            HStack(spacing: Layout.spacing) {
                Image(systemName: "doc.richtext")
                    .font(.title3)
                    .foregroundColor(model.removed ? .secondary : Color.jami)
                VStack(alignment: .leading, spacing: Layout.textSpacing) {
                    HStack(spacing: Layout.indicatorSpacing) {
                        title
                        if hasUnreadChanges {
                            CollabUnreadIndicator()
                                .fixedSize()
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, Layout.padding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(minHeight: Layout.minHeight)
            .background(
                RoundedRectangle(cornerRadius: Layout.corner)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        // A retired announcement opens nothing, so it stops answering taps
        // rather than answer them with silence.
        .disabled(model.removed)
        .accessibilityElement(children: .combine)
        .accessibilityHint(detail)
        .accessibilityValue(hasUnreadChanges ? L10n.Accessibility.messageBubbleUnread : "")
        .padding(.vertical, Layout.textSpacing)
    }

    private var hasUnreadChanges: Bool {
        return !model.removed && model.waitingToBeRead
    }

    private var detail: String {
        return model.removed ? L10n.Collab.documentRemoved : L10n.Collab.editableDocument
    }

    @ViewBuilder private var title: some View {
        // Struck through on the Text itself: the same modifier on a view needs
        // iOS 16, and this ships to 14.5.
        let text = model.removed
            ? Text(model.name).strikethrough().foregroundColor(.secondary)
            : Text(model.name).foregroundColor(Color(UIColor.label))
        text
            .font(.callout)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private enum Layout {
        static let spacing: CGFloat = 10
        static let textSpacing: CGFloat = 2
        static let indicatorSpacing: CGFloat = 6
        static let padding: CGFloat = 14
        static let verticalPadding: CGFloat = 8
        static let minHeight: CGFloat = 44
        static let corner: CGFloat = 12
    }
}

struct CollabUnreadIndicator: View {

    @ScaledMetric(relativeTo: .callout) private var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color.unreadMessageText)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
