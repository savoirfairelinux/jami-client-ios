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

import Foundation
import SwiftUI

enum MessageMarkdown {

    static func displayText(from markdown: String) -> String {
        MessageMarkdownPlainText.display(from: markdown)
    }

    static func resolveBubbleBody(
        content: String,
        linkColor: Color,
        baseFont: Font,
        inlineLinkAttributed: Any?
    ) -> MessageBubbleTextBody {
        let fallback = MessageMarkdownPlainText.display(from: content)
        if #available(iOS 15.0, *) {
            if let markdown = attributedString(from: content, linkColor: linkColor, baseFont: baseFont) {
                return .rich(markdown, fallbackPlain: fallback)
            }
            if let inlineLinkAttributed = inlineLinkAttributed as? AttributedString {
                return .rich(inlineLinkAttributed, fallbackPlain: fallback)
            }
        }
        return .plain(fallback)
    }

    @available(iOS 15.0, *)
    static func attributedString(
        from markdown: String,
        linkColor: Color,
        baseFont: Font = .callout
    ) -> AttributedString? {
        guard MessageMarkdownSupport.containsRenderableMarkdown(in: markdown) else { return nil }

        var options = AttributedString.MarkdownParsingOptions()
        switch MessageMarkdownSupport.syntaxMode(for: markdown) {
        case .inlineOnlyPreservingWhitespace:
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        case .full:
            options.interpretedSyntax = .full
        }
        options.failurePolicy = .returnPartiallyParsedIfPossible

        guard var result = try? AttributedString(markdown: markdown, options: options) else {
            return nil
        }

        applyPresentationStyles(to: &result, baseFont: baseFont, quoteColor: linkColor.opacity(0.85))
        applyLinkStyle(to: &result, linkColor: linkColor)

        return result
    }

    @available(iOS 15.0, *)
    private static func applyPresentationStyles(
        to attributed: inout AttributedString,
        baseFont: Font,
        quoteColor: Color
    ) {
        var headingRanges: [Range<AttributedString.Index>] = []

        for run in attributed.runs {
            guard let intent = run.presentationIntent else { continue }
            for component in intent.components {
                switch component.kind {
                case .header(level: let level):
                    attributed[run.range].font = headingFont(level: level, relativeTo: baseFont)
                    headingRanges.append(run.range)
                case .blockQuote:
                    attributed[run.range].foregroundColor = quoteColor
                    attributed[run.range].font = baseFont.italic()
                default:
                    break
                }
            }
        }

        for run in attributed.runs where !headingRanges.contains(where: { $0 == run.range }) {
            if run.presentationIntent != nil {
                continue
            }
            if run.font == nil {
                attributed[run.range].font = baseFont
            }
        }

        if headingRanges.isEmpty {
            for run in attributed.runs where run.font == nil {
                attributed[run.range].font = baseFont
            }
        }
    }

    @available(iOS 15.0, *)
    private static func headingFont(level: Int, relativeTo baseFont: Font) -> Font {
        switch level {
        case 1:
            return .title.bold()
        case 2:
            return .title2.bold()
        case 3:
            return .title3.bold()
        default:
            return baseFont.weight(.semibold)
        }
    }

    @available(iOS 15.0, *)
    private static func applyLinkStyle(to attributed: inout AttributedString, linkColor: Color) {
        for run in attributed.runs where run.link != nil {
            attributed[run.range].foregroundColor = linkColor
            attributed[run.range].underlineStyle = .single
        }
    }
}
