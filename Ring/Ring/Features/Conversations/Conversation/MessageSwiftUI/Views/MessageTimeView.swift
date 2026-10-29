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

struct MessageTimeView: View {
    let text: String
    let color: Color
    var accessibilityText: String?

    fileprivate static let font = Font.system(size: 11).monospacedDigit()

    var body: some View {
        Text(text)
            .font(Self.font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityLabel(accessibilityText ?? text)
            .accessibilityHidden(accessibilityText == nil)
    }
}

struct MessageTimeCapsule: View {
    let text: String
    var color: Color = .white
    var background = Color.black.opacity(0.4)

    var body: some View {
        MessageTimeView(text: text, color: color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(background))
            .allowsHitTesting(false)
    }
}

extension Text {
    func withInlineTime(_ time: String?, color: Color, minWidth: CGFloat? = nil) -> some View {
        (self + Self.reservedSpace(for: time))
            .frame(minWidth: minWidth, alignment: .leading)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .lastTextBaseline)) {
                if let time = time {
                    MessageTimeView(text: time, color: color)
                }
            }
    }

    private static func reservedSpace(for time: String?) -> Text {
        guard let time = time else { return Text("") }
        let unbreakableTime = time.replacingOccurrences(of: " ", with: "\u{00A0}")
        return Text("\u{2002}\u{2002}" + unbreakableTime)
            .font(MessageTimeView.font)
            .foregroundColor(.clear)
    }
}
