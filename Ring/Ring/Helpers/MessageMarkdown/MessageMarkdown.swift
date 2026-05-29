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
        hasInlineLinks: Bool
    ) -> MessageBubbleTextBody {
        let isRenderable = MessageMarkdownSupport.containsRenderableMarkdown(in: content)
        let strippedFallback = MessageMarkdownPlainText.display(from: content, isRenderable: isRenderable)
        let hasBlockSyntax = MessageMarkdownSupport.requiresFullSyntax(in: content)
        // Supported bubble markdown is intentionally small:
        // - inline markdown renders rich on iOS 15+
        // - block markdown is stripped to plain text
        // - plain non-markdown URLs are linked separately
        // SwiftUI Text(AttributedString) does not preserve block layout well enough here, and
        // linking URLs after block stripping requires fragile source-to-display range mapping.
        if #available(iOS 15.0, *), !hasBlockSyntax {
            if let markdown = attributedString(
                from: content,
                linkColor: linkColor,
                baseFont: baseFont,
                isRenderable: isRenderable
            ) {
                return .rich(markdown, fallbackPlain: strippedFallback)
            }
            if hasInlineLinks,
               let linked = attributedStringWithInlineLinks(from: content, linkColor: linkColor) {
                return .rich(linked, fallbackPlain: content)
            }
        }
        return .plain(strippedFallback)
    }

    @available(iOS 15.0, *)
    static func attributedStringWithInlineLinks(
        from content: String,
        linkColor: Color
    ) -> AttributedString? {
        let linkMatches = MessageMarkdownSupport.allowedLinkMatches(in: content)
        guard !linkMatches.isEmpty else { return nil }

        var attributedString = AttributedString(content)
        var appliedLink = false
        for match in linkMatches {
            guard let url = match.url,
                  let range = Range(match.range, in: content),
                  let normalizedURL = MessageMarkdownSupport.normalizedBubbleLinkURL(url),
                  let attributedRange = Range(range, in: attributedString) else { continue }

            attributedString[attributedRange].link = normalizedURL
            attributedString[attributedRange].foregroundColor = linkColor
            attributedString[attributedRange].underlineStyle = .single
            appliedLink = true
        }
        return appliedLink ? attributedString : nil
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
        guard !MessageMarkdownSupport.containsDisallowedMarkdownLink(in: markdown) else { return nil }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible

        guard var result = try? AttributedString(markdown: markdown, options: options) else {
            return nil
        }

        applyBaseFont(to: &result, baseFont: baseFont)
        applyBareURLRuns(to: &result, linkColor: linkColor)
        filterDisallowedLinks(in: &result)
        applyLinkStyle(to: &result, linkColor: linkColor)

        return result
    }

    @available(iOS 15.0, *)
    private static func applyBareURLRuns(to attributed: inout AttributedString, linkColor: Color) {
        let text = String(attributed.characters)
        for match in MessageMarkdownSupport.allowedLinkMatches(in: text) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attributedRange = Range(range, in: attributed),
                  let normalizedURL = MessageMarkdownSupport.normalizedBubbleLinkURL(url) else { continue }

            if attributed[attributedRange].link != nil { continue }
            if isInsideInlineCode(in: attributed, range: attributedRange) { continue }

            attributed[attributedRange].link = normalizedURL
            attributed[attributedRange].foregroundColor = linkColor
            attributed[attributedRange].underlineStyle = .single
        }
    }

    @available(iOS 15.0, *)
    private static func isInsideInlineCode(
        in attributed: AttributedString,
        range: Range<AttributedString.Index>
    ) -> Bool {
        for run in attributed.runs where rangesOverlap(run.range, range) {
            if run.inlinePresentationIntent?.contains(.code) == true {
                return true
            }
        }
        return false
    }

    @available(iOS 15.0, *)
    private static func rangesOverlap(
        _ lhs: Range<AttributedString.Index>,
        _ rhs: Range<AttributedString.Index>
    ) -> Bool {
        lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    @available(iOS 15.0, *)
    private static func applyBaseFont(to attributed: inout AttributedString, baseFont: Font) {
        for run in attributed.runs where run.font == nil {
            attributed[run.range].font = baseFont
        }
    }

    @available(iOS 15.0, *)
    private static func filterDisallowedLinks(in attributed: inout AttributedString) {
        for run in attributed.runs where run.link != nil {
            guard let url = run.link,
                  let normalizedURL = MessageMarkdownSupport.normalizedBubbleLinkURL(url) else {
                attributed[run.range].link = nil
                attributed[run.range].foregroundColor = nil
                attributed[run.range].underlineStyle = nil
                continue
            }
            attributed[run.range].link = normalizedURL
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
