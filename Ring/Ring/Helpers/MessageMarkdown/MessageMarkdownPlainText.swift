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

    /// Readable plain text when valid markdown is present; otherwise returns input unchanged.
    static func display(from raw: String) -> String {
        guard MessageMarkdownSupport.containsRenderableMarkdown(in: raw) else { return raw }
        return stripValidConstructs(from: raw)
    }

    /// Strips only complete markdown constructs; invalid markers remain literal.
    static func preview(from raw: String) -> String {
        stripValidConstructs(from: raw)
    }

    static func stripValidConstructs(from raw: String) -> String {
        var text = raw
        text = replacePattern(MessageMarkdownSupport.fencedCodePattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.linkPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.boldItalicAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.boldAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.boldUnderscorePattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.strikethroughPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.italicAsteriskPattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.italicUnderscorePattern, in: text, template: "$1")
        text = replacePattern(MessageMarkdownSupport.inlineCodePattern, in: text, template: "$1")
        text = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stripBlockLine(String($0)) }
            .joined(separator: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripBlockLine(_ line: String) -> String {
        if line.range(of: MessageMarkdownSupport.headingLinePattern, options: .regularExpression) != nil {
            return replacePattern(MessageMarkdownSupport.headingPattern, in: line, template: "")
        }
        if line.range(of: MessageMarkdownSupport.blockquoteLinePattern, options: .regularExpression) != nil {
            return replacePattern(MessageMarkdownSupport.blockquotePrefixPattern, in: line, template: "")
        }
        if line.range(of: MessageMarkdownSupport.unorderedListLinePattern, options: .regularExpression) != nil {
            return replacePattern(MessageMarkdownSupport.unorderedListPattern, in: line, template: "")
        }
        if line.range(of: MessageMarkdownSupport.orderedListLinePattern, options: .regularExpression) != nil {
            return replacePattern(MessageMarkdownSupport.orderedListPattern, in: line, template: "")
        }
        return line
    }

    private static func replacePattern(_ pattern: String, in text: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
