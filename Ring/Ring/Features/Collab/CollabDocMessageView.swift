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
                    .foregroundColor(Color.jami)
                VStack(alignment: .leading, spacing: Layout.textSpacing) {
                    Text(model.name)
                        .font(.callout)
                        .foregroundColor(Color(UIColor.label))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(L10n.Collab.editableDocument)
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
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.Collab.editableDocument)
        .padding(.vertical, Layout.textSpacing)
    }

    private enum Layout {
        static let spacing: CGFloat = 10
        static let textSpacing: CGFloat = 2
        static let padding: CGFloat = 14
        static let verticalPadding: CGFloat = 8
        static let minHeight: CGFloat = 44
        static let corner: CGFloat = 12
    }
}
