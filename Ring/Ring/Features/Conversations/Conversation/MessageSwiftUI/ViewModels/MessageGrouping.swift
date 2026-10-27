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

struct MessageGrouping {
    let startsNewDay: Bool
    let sequencing: MessageSequencing
    let bubbleSequencing: MessageSequencing
    let endsEmojiRun: Bool
    let displaysName: Bool
    let displaysAvatar: Bool

    private static let groupingInterval: TimeInterval = 10 * 60

    private struct Boundary {
        let startsNewDay: Bool
        let startsNewGroup: Bool
    }

    static func groupings(newestFirst messages: [MessageModel], isGroupConversation: Bool) -> [MessageGrouping] {
        let boundaries = self.boundaries(newestFirst: messages)
        return messages.indices.map { index in
            let message = messages[index]
            let sequencing = self.sequencing(at: index, in: messages, boundaries: boundaries)
            let isFirst = sequencing == .firstOfSequence || sequencing == .singleMessage
            let isLast = sequencing == .lastOfSequence || sequencing == .singleMessage
            let showsContactInfo = isGroupConversation && message.incoming
            return MessageGrouping(startsNewDay: boundaries[index].startsNewDay,
                                   sequencing: sequencing,
                                   bubbleSequencing: bubbleSequencing(sequencing, at: index, in: messages),
                                   endsEmojiRun: endsEmojiRun(at: index, in: messages, boundaries: boundaries),
                                   displaysName: showsContactInfo && isFirst && !message.isReply(),
                                   displaysAvatar: showsContactInfo && isLast)
        }
    }

    static func changesGrouping(from old: MessageModel, to new: MessageModel) -> Bool {
        return old.receivedDate != new.receivedDate || old.type != new.type ||
            old.authorId != new.authorId || old.uri != new.uri ||
            old.isReply() != new.isReply() || old.isEmojiOnly() != new.isEmojiOnly()
    }

    private static func boundaries(newestFirst messages: [MessageModel]) -> [Boundary] {
        var boundaries = [Boundary]()
        boundaries.reserveCapacity(messages.count)
        var previousMessage: MessageModel?
        var runStart: Date?
        for current in messages.reversed() {
            let startsNewDay = isFirstOfDay(current, after: previousMessage)
            let continuesMemberEvents = current.type.isContact && previousMessage?.type.isContact == true
            let continuesEmojiRun = current.isEmojiOnly() && previousMessage?.isEmojiOnly() == true
                && previousMessage?.authorId == current.authorId
            let continuesRun = continuesMemberEvents || continuesEmojiRun
            let startsNewGroup = startsNewDay
                || (continuesRun && exceedsGroupingInterval(current.receivedDate, since: runStart))
            boundaries.append(Boundary(startsNewDay: startsNewDay, startsNewGroup: startsNewGroup))
            if !continuesRun || startsNewGroup {
                runStart = current.receivedDate
            }
            previousMessage = current
        }
        return boundaries.reversed()
    }

    private static func isFirstOfDay(_ message: MessageModel, after previous: MessageModel?) -> Bool {
        guard let previous = previous else { return true }
        return !Calendar.current.isDate(message.receivedDate, inSameDayAs: previous.receivedDate)
    }

    private static func exceedsGroupingInterval(_ date: Date, since groupStart: Date?) -> Bool {
        guard let groupStart = groupStart else { return true }
        return date.timeIntervalSince(groupStart) >= groupingInterval
    }

    private static func sequencing(at index: Int, in messages: [MessageModel], boundaries: [Boundary]) -> MessageSequencing {
        let message = messages[index]
        let startsSequence = index + 1 < messages.count
            ? boundaries[index].startsNewGroup || isBreakingSequence(older: messages[index + 1], newer: message)
            : true
        let endsSequence = index > 0
            ? boundaries[index - 1].startsNewGroup || isBreakingSequence(older: message, newer: messages[index - 1])
            : true
        return sequencing(startsSequence: startsSequence, endsSequence: endsSequence)
    }

    private static func bubbleSequencing(_ sequencing: MessageSequencing, at index: Int, in messages: [MessageModel]) -> MessageSequencing {
        let olderHasReactions = index + 1 < messages.count && !messages[index + 1].reactions.isEmpty
        let startsSequence = sequencing == .singleMessage || sequencing == .firstOfSequence || olderHasReactions
        let endsSequence = sequencing == .singleMessage || sequencing == .lastOfSequence || !messages[index].reactions.isEmpty
        return self.sequencing(startsSequence: startsSequence, endsSequence: endsSequence)
    }

    private static func sequencing(startsSequence: Bool, endsSequence: Bool) -> MessageSequencing {
        switch (startsSequence, endsSequence) {
        case (true, true):
            return .singleMessage
        case (true, false):
            return .firstOfSequence
        case (false, true):
            return .lastOfSequence
        case (false, false):
            return .middleOfSequence
        }
    }

    private static func isBreakingSequence(older: MessageModel, newer: MessageModel) -> Bool {
        if older.type.isContact && newer.type.isContact {
            return false
        }
        let differentUri = older.uri != newer.uri
        let messageTypeCheck = older.type.isCentered || newer.type.isCentered
        let differentAuthor = older.authorId != newer.authorId
        let startsWithReply = newer.isReply()
        let isEmojiOnlyMessage = older.isEmojiOnly() || newer.isEmojiOnly()

        return differentUri || messageTypeCheck || differentAuthor ||
            startsWithReply || isEmojiOnlyMessage
    }

    private static func endsEmojiRun(at index: Int, in messages: [MessageModel], boundaries: [Boundary]) -> Bool {
        let current = messages[index]
        guard index > 0, current.isEmojiOnly() else { return true }
        let next = messages[index - 1]
        return boundaries[index - 1].startsNewGroup || !next.isEmojiOnly() || next.authorId != current.authorId
    }
}
