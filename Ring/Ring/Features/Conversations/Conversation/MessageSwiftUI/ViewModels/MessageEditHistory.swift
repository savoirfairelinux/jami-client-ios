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

import Foundation

struct TextSegment: Equatable {
    enum Change {
        case unchanged
        case inserted
        case removed
    }

    var text: String
    let change: Change

    init(_ text: String, _ change: Change) {
        self.text = text
        self.change = change
    }
}

struct MessageVersion: Identifiable, Equatable {
    enum Kind: Equatable {
        case current
        case edit(Int)
        case original
    }

    let id: String
    let kind: Kind
    let text: String
    let content: String
    let segments: [TextSegment]

    var title: String {
        switch kind {
        case .current:
            return L10n.Conversation.editHistoryCurrent
        case .edit(let number):
            return L10n.Conversation.editHistoryEdit(number)
        case .original:
            return L10n.Conversation.editHistoryOriginal
        }
    }

    var accessibilityLabel: String {
        var parts = [title, text]
        let removed = words(.removed)
        if !removed.isEmpty {
            parts.append(L10n.Accessibility.editHistoryRemoved(removed))
        }
        let added = words(.inserted)
        if !added.isEmpty {
            parts.append(L10n.Accessibility.editHistoryAdded(added))
        }
        return parts.joined(separator: ". ")
    }

    private func words(_ change: TextSegment.Change) -> String {
        segments
            .filter { $0.change == change }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

enum MessageEditHistory {
    /// Below this share of unchanged characters an edit reads as a rewrite,
    /// and marking every word would only add noise.
    private static let minUnchangedShare = 1.0 / 3.0

    /// `editions` are the superseded bodies, newest first, as the daemon sends them.
    static func versions(current: String, editions: [MessageAction]) -> [MessageVersion] {
        guard !editions.isEmpty else { return [] }
        let contents = [current] + editions.map(\.content)
        let texts = contents.map(MessageMarkdown.displayText(from:))
        return texts.indices.map { index in
            let kind: MessageVersion.Kind
            if index == 0 {
                kind = .current
            } else if index == texts.count - 1 {
                kind = .original
            } else {
                kind = .edit(texts.count - 1 - index)
            }
            let segments = index == texts.count - 1
                ? [TextSegment(texts[index], .unchanged)]
                : diff(from: texts[index + 1], to: texts[index])
            let id = index == 0 ? "current" : editions[index - 1].id + "-\(index)"
            return MessageVersion(id: id, kind: kind, text: texts[index], content: contents[index], segments: segments)
        }
    }

    static func diff(from old: String, to new: String) -> [TextSegment] {
        let oldTokens = tokens(old)
        let newTokens = tokens(new)
        // Compare words only, so a changed space or line break before a word doesn't mark the word.
        let difference = newTokens.difference(from: oldTokens) { word($0) == word($1) }
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _):
                removed.insert(offset)
            case .insert(let offset, _, _):
                inserted.insert(offset)
            }
        }

        var segments = [TextSegment]()
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldTokens.count || newIndex < newTokens.count {
            if oldIndex < oldTokens.count && removed.contains(oldIndex) {
                append(oldTokens[oldIndex], .removed, to: &segments)
                oldIndex += 1
            } else if newIndex < newTokens.count && inserted.contains(newIndex) {
                append(newTokens[newIndex], .inserted, to: &segments)
                newIndex += 1
            } else {
                append(newTokens[newIndex], .unchanged, to: &segments)
                oldIndex += 1
                newIndex += 1
            }
        }

        let unchangedCount = segments
            .filter { $0.change == .unchanged }
            .reduce(0) { $0 + visibleCount($1.text) }
        let largestCount = max(visibleCount(old), visibleCount(new))
        if largestCount > 0 && Double(unchangedCount) < Double(largestCount) * minUnchangedShare {
            return [TextSegment(new, .unchanged)]
        }
        return segments
    }

    /// Words with their leading whitespace, so a change never starts or ends on a bare space.
    private static func tokens(_ text: String) -> [String] {
        var tokens = [String]()
        var current = ""
        var inWord = false
        for character in text {
            if character.isWhitespace {
                if inWord {
                    tokens.append(current)
                    current = ""
                    inWord = false
                }
            } else {
                inWord = true
            }
            current.append(character)
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    private static func word(_ token: String) -> Substring {
        token.drop { $0.isWhitespace }
    }

    private static func append(_ token: String, _ change: TextSegment.Change, to segments: inout [TextSegment]) {
        if let last = segments.last, last.change == change {
            segments[segments.count - 1].text += token
            return
        }
        var token = token
        if change != .unchanged {
            let space = token.prefix { $0.isWhitespace }
            // A space alone changing is invisible.
            if space.count == token.count { return }
            // Keep the space before a changed word in the text around it, so only the word is marked.
            if let last = segments.last, last.change == .unchanged {
                segments[segments.count - 1].text += space
                token.removeFirst(space.count)
            }
        }
        segments.append(TextSegment(token, change))
    }

    private static func visibleCount(_ text: String) -> Int {
        text.reduce(0) { $0 + ($1.isWhitespace ? 0 : 1) }
    }
}
