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

import XCTest
@testable import Ring

final class MessageGroupingTests: XCTestCase {
    private let author = "author1"
    private lazy var start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12))!

    private func message(_ minutes: Double, content: String = "hello", author: String? = nil,
                         _ change: (inout MessageData) -> Void = { _ in }) -> MessageModel {
        return MessageModel(withId: UUID().uuidString,
                            receivedDate: start.addingTimeInterval(minutes * 60),
                            content: content, authorURI: author ?? self.author, incoming: true)
            .updating(change)
    }

    private let reacted: (inout MessageData) -> Void = {
        $0.reactions.insert(MessageAction(withInfo: ["id": UUID().uuidString, "body": "👍", "author": "author2"]))
    }

    private func groupings(_ oldestFirst: [MessageModel], isGroupConversation: Bool = false) -> [MessageGrouping] {
        return MessageGrouping.groupings(newestFirst: oldestFirst.reversed(),
                                         isGroupConversation: isGroupConversation).reversed()
    }

    func testMessagesFromSameAuthorWithinIntervalFormOneSequence() {
        let result = groupings([message(0), message(1), message(2)])

        XCTAssertEqual(result.map(\.sequencing), [.firstOfSequence, .middleOfSequence, .lastOfSequence])
    }

    func testTimeGapsKeepSameAuthorMessagesInOneSequence() {
        let result = groupings([message(0), message(10), message(180)], isGroupConversation: true)

        XCTAssertEqual(result.map(\.sequencing), [.firstOfSequence, .middleOfSequence, .lastOfSequence])
        XCTAssertEqual(result.map(\.displaysName), [true, false, false])
        XCTAssertEqual(result.map(\.displaysAvatar), [false, false, true])
    }

    func testDifferentAuthorsSplitSequence() {
        let result = groupings([message(0), message(1, author: "author2")])

        XCTAssertEqual(result.map(\.sequencing), [.singleMessage, .singleMessage])
    }

    func testNewDayStartsNewDayAndSplitsSequence() {
        let result = groupings([message(0), message(24 * 60)])

        XCTAssertEqual(result.map(\.startsNewDay), [true, true])
        XCTAssertEqual(result.map(\.sequencing), [.singleMessage, .singleMessage])
    }

    func testReplyStartsSequenceAndHidesName() {
        let result = groupings([message(0), message(1) { $0.reply = "parent" }], isGroupConversation: true)

        XCTAssertEqual(result.map(\.sequencing), [.singleMessage, .singleMessage])
        XCTAssertEqual(result.map(\.displaysName), [true, false])
    }

    func testMemberEventsGroupWithinIntervalFromFirstEvent() {
        let join: (inout MessageData) -> Void = { $0.type = .contact(.join) }
        let result = groupings([message(0, join), message(6, join), message(12, join)])

        XCTAssertEqual(result.map(\.sequencing), [.firstOfSequence, .lastOfSequence, .singleMessage])
    }

    func testEmojiRunEndsOnLastEmojiFromSameAuthor() {
        let result = groupings([message(0, content: "😀"), message(1, content: "😀"), message(2)])

        XCTAssertEqual(result.map(\.endsEmojiRun), [false, true, true])
    }

    func testEmojiRunSplitsWithinIntervalFromFirstEmoji() {
        let result = groupings([message(0, content: "😀"), message(6, content: "😀"),
                                message(12, content: "😀")])

        XCTAssertEqual(result.map(\.endsEmojiRun), [false, true, true])
    }

    func testBubbleSequencingMatchesSequencingWithoutReactions() {
        let result = groupings([message(0), message(1), message(2)])

        XCTAssertEqual(result.map(\.bubbleSequencing), result.map(\.sequencing))
    }

    func testReactionsSplitBubbleSequenceAroundReactedMessage() {
        let result = groupings([message(0), message(1, reacted), message(2), message(3)])

        XCTAssertEqual(result.map(\.sequencing), [.firstOfSequence, .middleOfSequence, .middleOfSequence, .lastOfSequence])
        XCTAssertEqual(result.map(\.bubbleSequencing), [.firstOfSequence, .lastOfSequence, .firstOfSequence, .lastOfSequence])
    }

    func testReactionsOnLastMessageKeepBubbleSequencing() {
        let result = groupings([message(0), message(1, reacted)])

        XCTAssertEqual(result.map(\.bubbleSequencing), [.firstOfSequence, .lastOfSequence])
    }

    func testReactionsOnBothNeighborsMakeMiddleMessageSingle() {
        let result = groupings([message(0, reacted), message(1, reacted), message(2)])

        XCTAssertEqual(result.map(\.bubbleSequencing), [.singleMessage, .singleMessage, .singleMessage])
    }

    func testGroupConversationShowsNameOnFirstAndAvatarOnLast() {
        let result = groupings([message(0), message(1)], isGroupConversation: true)

        XCTAssertEqual(result.map(\.displaysName), [true, false])
        XCTAssertEqual(result.map(\.displaysAvatar), [false, true])
    }

    func testOneToOneConversationShowsNoContactInfo() {
        let result = groupings([message(0), message(1)])

        XCTAssertEqual(result.map(\.displaysName), [false, false])
        XCTAssertEqual(result.map(\.displaysAvatar), [false, false])
    }

    func testStatusUpdateDoesNotChangeGrouping() {
        let original = message(0)

        XCTAssertFalse(MessageGrouping.changesGrouping(from: original, to: original.updating { $0.status = .displayed }))
    }

    func testGroupingFieldUpdatesChangeGrouping() {
        let original = message(0)

        XCTAssertTrue(MessageGrouping.changesGrouping(from: original, to: original.updating { $0.content = "😀" }))
        XCTAssertTrue(MessageGrouping.changesGrouping(from: original, to: original.updating { $0.reply = "parent" }))
        XCTAssertTrue(MessageGrouping.changesGrouping(from: original, to: original.updating { $0.authorId = "author2" }))
        XCTAssertTrue(MessageGrouping.changesGrouping(from: original, to: original.updating {
            $0.receivedDate = $0.receivedDate.addingTimeInterval(60)
        }))
    }
}
