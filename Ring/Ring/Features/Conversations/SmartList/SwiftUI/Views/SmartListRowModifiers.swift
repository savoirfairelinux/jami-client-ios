/*
 *  Copyright (C) 2024-2026 Savoir-faire Linux Inc.
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

extension View {
    func smartListRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 15))
            .listRowBackground(Color.clear)
            .hideRowSeparator()
    }

    func conversationRowSeparator(isFirstRow: Bool = false) -> some View {
        self.modifier(ConversationRowSeparatorModifier(isFirstRow: isFirstRow))
    }
}

private struct ConversationRowSeparatorModifier: ViewModifier {
    let isFirstRow: Bool

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .listRowSeparator(.visible, edges: .bottom)
                // Hide the top separator the plain List draws above the first row.
                .listRowSeparator(isFirstRow ? .hidden : .automatic, edges: .top)
                .alignmentGuide(.listRowSeparatorLeading) { _ in
                    Constants.defaultAvatarSize
                }
        } else {
            content
        }
    }
}
