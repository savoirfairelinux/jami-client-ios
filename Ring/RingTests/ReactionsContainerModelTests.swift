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

final class ReactionsContainerModelTests: XCTestCase {
    private let localJamiId = "local"

    private func message(reactions: [(String, String)]) -> MessageModel {
        return MessageModel(withId: "message", receivedDate: Date(), content: "hello",
                            authorURI: "author", incoming: true)
            .updating { data in
                for (emoji, author) in reactions {
                    data.reactions.insert(MessageAction(withInfo: ["id": UUID().uuidString,
                                                                   "body": emoji,
                                                                   "author": author]))
                }
            }
    }

    private func model(_ reactions: [(String, String)]) -> ReactionsContainerModel {
        return ReactionsContainerModel(message: message(reactions: reactions), localJamiId: localJamiId)
    }

    func testSegmentsAreSortedByCountThenEmoji() {
        let result = model([("😀", "a"), ("👍", "a"), ("👍", "b"), ("❤️", "c")])

        XCTAssertEqual(result.segments.map(\.emoji), ["👍", "❤️", "😀"])
        XCTAssertEqual(result.segments.map(\.count), [2, 1, 1])
    }

    func testSummaryShowsAtMostMaxVisibleSegmentsAndCountsTheRest() {
        let result = model([("1️⃣", "a"), ("2️⃣", "a"), ("3️⃣", "a"), ("4️⃣", "a"), ("5️⃣", "a"), ("6️⃣", "a")])

        let summary = result.summary(maxVisible: 4)

        XCTAssertEqual(summary.segments.count, 4)
        XCTAssertEqual(summary.hiddenCount, 2)
    }

    func testSummaryHidesNothingWhenAllSegmentsFit() {
        let summary = model([("👍", "a"), ("❤️", "b")]).summary(maxVisible: 4)

        XCTAssertEqual(summary.segments.count, 2)
        XCTAssertEqual(summary.hiddenCount, 0)
    }

    func testOwnReactionReplacesLastVisibleSegment() {
        let others = [("👍", "a"), ("👍", "b"), ("❤️", "a"), ("❤️", "b"),
                      ("😀", "a"), ("😀", "b"), ("🎉", "a"), ("🎉", "b")]
        let summary = model(others + [("🔥", localJamiId)]).summary(maxVisible: 4)

        XCTAssertEqual(summary.segments.map(\.emoji), ["❤️", "🎉", "👍", "🔥"])
        XCTAssertEqual(summary.segments.last?.includesLocalAccount, true)
        XCTAssertEqual(summary.hiddenCount, 1)
    }

    func testOwnReactionStaysVisibleWithSmallerLimit() {
        let summary = model([("👍", "a"), ("👍", "b"), ("❤️", "a"), ("❤️", "b"), ("🔥", localJamiId)])
            .summary(maxVisible: 2)

        XCTAssertEqual(summary.segments.map(\.emoji), ["❤️", "🔥"])
        XCTAssertEqual(summary.hiddenCount, 1)
    }

    private let sixEmojis = [("1️⃣", "a"), ("2️⃣", "a"), ("3️⃣", "a"), ("4️⃣", "a"), ("5️⃣", "a"), ("6️⃣", "a")]

    private func width(_ summary: ReactionsSummary) -> CGFloat {
        CGFloat(summary.segments.count * 50) + (summary.hiddenCount > 0 ? 30 : 0)
    }

    func testFittingSummaryShowsFourSegmentsWhenTheyFit() {
        let summary = model(sixEmojis).summary(fitting: 230, width: width)

        XCTAssertEqual(summary.segments.count, 4)
        XCTAssertEqual(summary.hiddenCount, 2)
    }

    func testFittingSummaryDropsSegmentsUntilTheRowFits() {
        let summary = model(sixEmojis).summary(fitting: 140, width: width)

        XCTAssertEqual(summary.segments.count, 2)
        XCTAssertEqual(summary.hiddenCount, 4)
    }

    func testFittingSummaryKeepsOneSegmentWhenNothingFits() {
        let summary = model(sixEmojis).summary(fitting: 10, width: width)

        XCTAssertEqual(summary.segments.count, 1)
        XCTAssertEqual(summary.hiddenCount, 5)
    }

    func testFittingSummaryShowsFourSegmentsWhenWidthIsUnknown() {
        let summary = model(sixEmojis).summary(fitting: 0, width: width)

        XCTAssertEqual(summary.segments.count, 4)
    }

    func testReactionsUpdatedRefreshesSegmentsImmediately() {
        let result = model([])

        result.message = message(reactions: [("👍", "a")])
        result.reactionsUpdated()

        XCTAssertEqual(result.segments.map(\.emoji), ["👍"])
    }
}
