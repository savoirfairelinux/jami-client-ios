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

enum MessageMarkdownSupport {

    // MARK: - Valid construct patterns (complete markdown only)

    static let fencedCodePattern = #"```[^\n]*\n([\s\S]*?)```"#
    static let linkPattern = #"\[([^\]]+)\]\([^)]+\)"#
    static let boldItalicAsteriskPattern = #"\*\*\*([^*]+)\*\*\*"#
    static let boldAsteriskPattern = #"\*\*([^*]+)\*\*"#
    static let boldUnderscorePattern = #"__([^_]+)__"#
    static let strikethroughPattern = #"~~([^~]+)~~"#
    static let italicAsteriskPattern = #"(?<![*\w])\*(?!\s)([^*\n]*?\S)\*(?![*\w])"#
    static let italicUnderscorePattern = #"(?<![A-Za-z0-9])_([^_\n]+)_(?![A-Za-z0-9])"#
    static let inlineCodePattern = #"(?<![`])`([^`\n]+)`(?![`])"#

    static let headingLinePattern = #"^#{1,6}\s+\S"#
    static let blockquoteLinePattern = #"^>\s+\S"#
    static let unorderedListLinePattern = #"^[-*+]\s+\S"#
    static let orderedListLinePattern = #"^\d+\.\s+\S"#

    static let headingPattern = #"(?m)^#{1,6}\s+"#
    static let blockquotePrefixPattern = #"^>\s+"#
    static let unorderedListPattern = #"(?m)^[-*+]\s+"#
    static let orderedListPattern = #"(?m)^\d+\.\s+"#

    private static let markerCharacters: Set<Character> = ["*", "_", "`", "~", "#", "[", "]", ">", "-", "+"]

    private static let renderablePatterns: [String] = [
        fencedCodePattern,
        linkPattern,
        boldItalicAsteriskPattern,
        boldAsteriskPattern,
        boldUnderscorePattern,
        strikethroughPattern,
        italicAsteriskPattern,
        italicUnderscorePattern,
        inlineCodePattern,
        #"(?m)\#(headingLinePattern)"#,
        #"(?m)\#(blockquoteLinePattern)"#,
        #"(?m)\#(unorderedListLinePattern)"#,
        #"(?m)\#(orderedListLinePattern)"#
    ]

    private static let compiledPatterns: [String: NSRegularExpression] = {
        let patterns = Set(
            renderablePatterns + [
                headingLinePattern,
                blockquoteLinePattern,
                unorderedListLinePattern,
                orderedListLinePattern,
                headingPattern,
                blockquotePrefixPattern,
                unorderedListPattern,
                orderedListPattern
            ]
        )
        var result = [String: NSRegularExpression]()
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result[pattern] = regex
            }
        }
        return result
    }()

    static func regularExpression(for pattern: String) -> NSRegularExpression? {
        compiledPatterns[pattern]
    }

    static func containsMatch(for pattern: String, in text: String) -> Bool {
        guard let regex = regularExpression(for: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// True when the text contains at least one complete, renderable markdown construct.
    static func containsRenderableMarkdown(in text: String) -> Bool {
        guard text.contains(where: { markerCharacters.contains($0) }) ||
                containsMatch(for: #"(?m)\#(orderedListLinePattern)"#, in: text)
        else { return false }
        return renderablePatterns.contains { containsMatch(for: $0, in: text) }
    }

    static func requiresFullSyntax(in text: String) -> Bool {
        let blockPatterns = [
            #"(?m)\#(headingLinePattern)"#,
            #"(?m)\#(blockquoteLinePattern)"#,
            #"(?m)\#(unorderedListLinePattern)"#,
            #"(?m)\#(orderedListLinePattern)"#,
            fencedCodePattern
        ]
        return blockPatterns.contains { containsMatch(for: $0, in: text) }
    }
}
