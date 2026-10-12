/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
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

struct MessageEditHistoryView: View {
    static let verticalPadding: CGFloat = 6

    let versions: [MessageVersion]
    let highlightColor: Color

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(versions) { version in
                    if version.id != versions.first?.id {
                        Divider()
                            .padding(.leading, MessageVersionRow.horizontalPadding)
                    }
                    MessageVersionRow(version: version, highlightColor: highlightColor)
                }
            }
            .padding(.vertical, Self.verticalPadding)
        }
    }
}

struct MessageVersionRow: View {
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 8
    private static let titleSpacing: CGFloat = 2
    private static var copyButtonSide: CGFloat {
        max(44, UIFont.preferredFont(forTextStyle: .footnote).lineHeight)
    }

    static func idealWidth(of version: MessageVersion) -> CGFloat {
        let titleWidth = (version.title as NSString).size(withAttributes: [.font: UIFont.preferredFont(forTextStyle: .footnote)]).width
        let textWidth = measuredText(version).size().width
        return ceil(max(titleWidth + copyButtonSide, textWidth) + horizontalPadding * 2)
    }

    static func height(of version: MessageVersion, width: CGFloat) -> CGFloat {
        let textHeight = measuredText(version)
            .boundingRect(with: CGSize(width: max(0, width - horizontalPadding * 2), height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                          context: nil)
            .height
        let titleHeight = UIFont.preferredFont(forTextStyle: .footnote).lineHeight
        return ceil(titleHeight + titleSpacing + textHeight + verticalPadding * 2)
    }

    /// A removed word would otherwise touch the word that follows it.
    private static func displaySegments(_ version: MessageVersion) -> [TextSegment] {
        var segments = version.segments
        for index in segments.indices.dropFirst() {
            let segment = segments[index]
            if segment.change != .removed,
               segments[index - 1].change == .removed,
               segments[index - 1].text.last?.isWhitespace == false,
               segment.text.first?.isWhitespace == false {
                segments[index].text = " " + segment.text
            }
        }
        return segments
    }

    private static func measuredText(_ version: MessageVersion) -> NSAttributedString {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let emphasized = UIFont.systemFont(ofSize: body.pointSize, weight: .semibold)
        let text = NSMutableAttributedString()
        for segment in displaySegments(version) {
            text.append(NSAttributedString(string: segment.text,
                                           attributes: [.font: segment.change == .inserted ? emphasized : body]))
        }
        return text
    }

    let version: MessageVersion
    let highlightColor: Color
    @SwiftUI.State private var showsCopied = false
    @SwiftUI.State private var copiedToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleSpacing) {
            Text(version.title)
                .font(.footnote)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .lineLimit(1)
                .padding(.trailing, Self.copyButtonSide)
            styledText
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .overlay(alignment: .topTrailing) {
            copyButton
                .padding(.trailing, Self.horizontalPadding)
                .padding(.top, Self.verticalPadding)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(version.accessibilityLabel)
        .accessibilityAction(named: Text(L10n.Global.copy)) {
            copyVersion()
            UIAccessibility.post(notification: .announcement, argument: L10n.Accessibility.editHistoryCopied)
        }
    }

    private var copyButton: some View {
        Button(action: copyVersion) {
            copyIcon
                .font(.footnote)
                .frame(width: Self.copyButtonSide, height: Self.copyButtonSide, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var copyIcon: some View {
        ZStack(alignment: .topTrailing) {
            if showsCopied {
                copiedMark
            } else {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var copiedMark: some View {
        let mark = Image(systemName: "checkmark")
            .foregroundColor(highlightColor)
        if #available(iOS 26.0, *) {
            mark.transition(AsymmetricTransition(insertion: .symbolEffect(.drawOn), removal: .opacity))
        } else {
            mark.transition(.opacity)
        }
    }

    private func copyVersion() {
        UIPasteboard.general.string = version.content
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        copiedToken += 1
        let token = copiedToken
        withAnimation(.easeOut(duration: 0.15)) {
            showsCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard copiedToken == token else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                showsCopied = false
            }
        }
    }

    private var styledText: Text {
        Self.displaySegments(version).reduce(Text("")) { text, segment in
            switch segment.change {
            case .unchanged:
                return text + Text(segment.text)
            case .removed:
                return text + Text(segment.text)
                    .strikethrough()
                    .foregroundColor(Color(UIColor.secondaryLabel))
            case .inserted:
                return text + Text(segment.text)
                    .fontWeight(.semibold)
                    .underline(true, color: highlightColor)
            }
        }
    }
}
