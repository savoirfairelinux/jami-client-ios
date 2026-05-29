/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

struct MessageBubbleTextBody {
    enum Kind {
        case plain(String)
        case rich(Any)
    }

    let kind: Kind
    let fallbackPlain: String

    static func plain(_ text: String) -> MessageBubbleTextBody {
        MessageBubbleTextBody(kind: .plain(text), fallbackPlain: text)
    }

    @available(iOS 15.0, *)
    static func rich(_ attributed: AttributedString, fallbackPlain: String) -> MessageBubbleTextBody {
        MessageBubbleTextBody(kind: .rich(attributed), fallbackPlain: fallbackPlain)
    }
}

/// Encapsulates iOS 15 rich-text availability.
struct MessageBubbleTextRenderer: View {
    let textBody: MessageBubbleTextBody
    let font: Font

    var body: some View {
        switch textBody.kind {
        case .plain(let text):
            Text(text)
                .font(font)
        case .rich(let storage):
            if #available(iOS 15.0, *), let attributed = storage as? AttributedString {
                Text(attributed)
            } else {
                Text(textBody.fallbackPlain)
                    .font(font)
            }
        }
    }
}
