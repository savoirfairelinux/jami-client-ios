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
        // App target entry point; notification extension uses MessageMarkdownPlainText.display directly.
        MessageMarkdownPlainText.display(from: markdown)
    }

    static func resolveBubbleBody(
        content: String,
        linkColor: Color,
        baseFont: Font,
        inlineLinkAttributed: Any?
    ) -> MessageBubbleTextBody {
        let isRenderable = MessageMarkdownSupport.containsRenderableMarkdown(in: content)
        let fallback = MessageMarkdownPlainText.display(from: content, isRenderable: isRenderable)
        let hasBlockSyntax = MessageMarkdownSupport.requiresFullSyntax(in: content)
        // Block markdown uses plain strip: SwiftUI Text(AttributedString) does not preserve block layout.
        if #available(iOS 15.0, *), !hasBlockSyntax {
            if let markdown = attributedString(
                from: content,
                linkColor: linkColor,
                baseFont: baseFont,
                isRenderable: isRenderable
            ) {
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
        attributedString(
            from: markdown,
            linkColor: linkColor,
            baseFont: baseFont,
            isRenderable: MessageMarkdownSupport.containsRenderableMarkdown(in: markdown)
        )
    }

    @available(iOS 15.0, *)
    static func attributedString(
        from markdown: String,
        linkColor: Color,
        baseFont: Font,
        isRenderable: Bool
    ) -> AttributedString? {
        guard isRenderable else { return nil }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        guard var result = try? AttributedString(markdown: markdown, options: options) else {
            return nil
        }

        applyBaseFont(to: &result, baseFont: baseFont)
        applyLinkStyle(to: &result, linkColor: linkColor)

        return result
    }

    @available(iOS 15.0, *)
    private static func applyBaseFont(to attributed: inout AttributedString, baseFont: Font) {
        for run in attributed.runs where run.font == nil {
            attributed[run.range].font = baseFont
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
