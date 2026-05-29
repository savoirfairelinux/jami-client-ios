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

enum MessageMarkdownPlainText {

    private static let placeholderPrefix = "\u{FFFC}"

    /// Readable plain text when valid markdown is present; otherwise returns input unchanged.
    static func display(from raw: String) -> String {
        display(from: raw, isRenderable: MessageMarkdownSupport.containsRenderableMarkdown(in: raw))
    }

    static func display(from raw: String, isRenderable: Bool) -> String {
        guard isRenderable else { return raw }
        return stripValidConstructs(from: raw)
    }

    static func stripValidConstructs(from raw: String) -> String {
        var (text, fencedBodies) = protectPattern(
            in: raw,
            pattern: MessageMarkdownSupport.fencedCodePattern,
            bodyGroupIndex: 1,
            idPrefix: "F"
        )
        var inlineBodies: [String] = []
        (text, inlineBodies) = protectPattern(
            in: text,
            pattern: MessageMarkdownSupport.inlineCodePattern,
            bodyGroupIndex: 1,
            idPrefix: "I"
        )

        text = MessageMarkdownSupport.stripMarkdownLinks(in: text)
        text = replacePattern(MessageMarkdownSupport.boldItalicAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.boldAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.boldUnderscorePattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.strikethroughPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.italicAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.italicUnderscorePattern, in: text, template: "$1")
        text = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stripBlockLine(String($0)) }
            .joined(separator: "\n")

        text = restorePlaceholders(in: text, idPrefix: "I", bodies: inlineBodies)
        text = restorePlaceholders(in: text, idPrefix: "F", bodies: fencedBodies)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func protectPattern(
        in text: String,
        pattern: String,
        bodyGroupIndex: Int,
        idPrefix: String
    ) -> (text: String, bodies: [String]) {
        guard let regex = MessageMarkdownSupport.regularExpression(for: pattern) else {
            return (text, [])
        }

        var bodies: [String] = []
        var output = text

        while true {
            let searchRange = NSRange(output.startIndex..<output.endIndex, in: output)
            guard let match = regex.firstMatch(in: output, range: searchRange) else { break }
            guard match.numberOfRanges > bodyGroupIndex,
                  let bodyRange = Range(match.range(at: bodyGroupIndex), in: output),
                  let fullRange = Range(match.range, in: output) else { break }

            var body = String(output[bodyRange])
            if idPrefix == "F", body.hasSuffix("\n") {
                // The newline before the closing fence is syntax, not part of the displayed code body.
                body.removeLast()
            }
            let index = bodies.count
            let placeholder = placeholder(idPrefix: idPrefix, index: index)
            output.replaceSubrange(fullRange, with: placeholder)
        }

        return (output, bodies)
    }

    private static func placeholder(idPrefix: String, index: Int) -> String {
        "\(placeholderPrefix)\(idPrefix)\(index)\(placeholderPrefix)"
    }

    private static func restorePlaceholders(in text: String, idPrefix: String, bodies: [String]) -> String {
        var result = text
        for index in bodies.indices.reversed() {
            let placeholder = placeholder(idPrefix: idPrefix, index: index)
            guard let range = result.range(of: placeholder) else { continue }
            result.replaceSubrange(range, with: bodies[index])
        }
        return result
    }

    private static func stripBlockLine(_ line: String) -> String {
        if MessageMarkdownSupport.containsMatch(for: MessageMarkdownSupport.headingLinePattern, in: line) {
            return replacePattern(MessageMarkdownSupport.headingPattern, in: line, template: "")
        }
        if MessageMarkdownSupport.containsMatch(for: MessageMarkdownSupport.blockquoteLinePattern, in: line) {
            return replacePattern(MessageMarkdownSupport.blockquotePrefixPattern, in: line, template: "")
        }
        if MessageMarkdownSupport.containsMatch(for: MessageMarkdownSupport.unorderedListLinePattern, in: line) {
            return replacePattern(MessageMarkdownSupport.unorderedListPattern, in: line, template: "")
        }
        if MessageMarkdownSupport.containsMatch(for: MessageMarkdownSupport.orderedListLinePattern, in: line) {
            return replacePattern(MessageMarkdownSupport.orderedListPattern, in: line, template: "")
        }
        return line
    }

    private static func replacePattern(_ pattern: String, in text: String, template: String) -> String {
        guard let regex = MessageMarkdownSupport.regularExpression(for: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
