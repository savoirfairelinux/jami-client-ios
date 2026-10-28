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

struct ReactionsView: View {
    static let verticalPadding: CGFloat = 6

    static var cornerRadius: CGFloat {
        verticalPadding + ReactionRowView.verticalPadding + ReactionRowView.avatarSize.points / 2
    }

    @ObservedObject var model: ReactionsContainerModel
    let localJamiId: String?
    let pendingRemovals: Set<String>
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                let rows = sortedRows
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        Divider()
                            .padding(.leading, ReactionRowView.separatorInset)
                    }
                    ReactionRowView(reaction: row,
                                    isLocal: row.jamiId == localJamiId,
                                    pendingRemovals: pendingRemovals,
                                    onRemove: onRemove)
                }
            }
            .padding(.vertical, Self.verticalPadding)
        }
    }

    private var sortedRows: [ReactionsRowViewModel] {
        model.reactionsRow.sorted { lhs, rhs in
            let lhsIsLocal = lhs.jamiId == localJamiId
            if lhsIsLocal != (rhs.jamiId == localJamiId) {
                return lhsIsLocal
            }
            return lhs.jamiId < rhs.jamiId
        }
    }
}
