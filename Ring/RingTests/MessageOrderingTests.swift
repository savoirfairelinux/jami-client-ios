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

import XCTest
@testable import Ring

final class MessageOrderingTests: XCTestCase {

    var conversation: ConversationModel!

    override func setUp() {
        super.setUp()
        conversation = ConversationModel(withId: conversationId1, accountId: accountId1)
        conversation.type = .oneToOne
    }

    override func tearDown() {
        conversation = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMessage(id: String, parentId: String = "") -> MessageModel {
        let msg = MessageModel(withId: id, receivedDate: Date(), content: "text", authorURI: "author", incoming: true)
        msg.id = id
        msg.parentId = parentId
        msg.type = .text
        return msg
    }

    private func messageIds() -> [String] {
        return conversation.messages.map { $0.id }
    }

    // MARK: - insertByParent: Basic Cases

    func testInsertByParent_emptyList_appendsMessage() {
        let msg = makeMessage(id: "A")
        let idx = conversation.insertByParent(msg)
        XCTAssertEqual(idx, 0)
        XCTAssertEqual(messageIds(), ["A"])
    }

    func testInsertByParent_parentIsLast_appendsMessage() {
        // A → B (linear chain, fast path)
        conversation.insertByParent(makeMessage(id: "A"))
        let idx = conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        XCTAssertEqual(idx, 1)
        XCTAssertEqual(messageIds(), ["A", "B"])
    }

    func testInsertByParent_linearChain_maintainsOrder() {
        // A → B → C → D
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        conversation.insertByParent(makeMessage(id: "D", parentId: "C"))
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D"])
    }

    func testInsertByParent_parentInMiddle_insertsAfterParent() {
        // Chain: A → B → D, then insert C with parent B
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "D", parentId: "B"))
        let idx = conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        // C should be inserted after B (at index 2), pushing D to index 3
        XCTAssertEqual(idx, 2)
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D"])
    }

    func testInsertByParent_messageIsChildsParent_insertsBeforeChild() {
        // Child C (parent=B) arrives first, then B arrives
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B")) // B not yet present, appended
        let idx = conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        // B should be placed before C (since C's parentId is B)
        XCTAssertEqual(idx, 1)
        XCTAssertEqual(messageIds(), ["A", "B", "C"])
    }

    func testInsertByParent_parentNotFound_appendsToEnd() {
        conversation.insertByParent(makeMessage(id: "A"))
        let idx = conversation.insertByParent(makeMessage(id: "X", parentId: "unknown"))
        XCTAssertEqual(idx, 1)
        XCTAssertEqual(messageIds(), ["A", "X"])
    }

    func testInsertByParent_duplicateId_skipsInsertion() {
        conversation.insertByParent(makeMessage(id: "A"))
        let idx = conversation.insertByParent(makeMessage(id: "A"))
        XCTAssertEqual(idx, -1)
        XCTAssertEqual(conversation.messages.count, 1)
    }

    // MARK: - Batch / History Loading

    func testInsertByParent_historyBatch_maintainsChainOrder() {
        // Simulate history load: daemon sends A → B → C in order
        let batch = [
            makeMessage(id: "A"),
            makeMessage(id: "B", parentId: "A"),
            makeMessage(id: "C", parentId: "B")
        ]
        batch.forEach { conversation.insertByParent($0) }
        XCTAssertEqual(messageIds(), ["A", "B", "C"])
    }

    func testInsertByParent_outOfOrderArrival_correctsOrder() {
        // C arrives, then A, then B
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        // B should be placed before C (C's parent is B)
        // A should be before B
        XCTAssertEqual(messageIds(), ["A", "B", "C"])
    }

    // MARK: - Merge Scenarios

    func testInsertByParent_mergeScenario_twoChildrenOfSameParent() {
        // A → B and A → C (fork), both have parent A
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "A"))
        // Both B and C should follow A
        XCTAssertEqual(messageIds().first, "A")
        XCTAssertTrue(messageIds().contains("B"))
        XCTAssertTrue(messageIds().contains("C"))
    }

    func testInsertByParent_historyThenNewMessage() {
        // Simulate: initial load gets latest message, then history loads older ones
        // New message D arrives first
        conversation.insertByParent(makeMessage(id: "D", parentId: "C"))
        // History loads: A → B → C
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        // D's parent is C, so D should end up after C
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D"])
    }

    // MARK: - getMessage with Index

    func testGetMessage_usesIndex() {
        let msg = makeMessage(id: "A")
        conversation.insertByParent(msg)
        let found = conversation.getMessage(messageId: "A")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, "A")
    }

    func testGetMessage_returnsNilForMissing() {
        let found = conversation.getMessage(messageId: "nonexistent")
        XCTAssertNil(found)
    }

    // MARK: - clearMessages resets index

    func testClearMessages_resetsIndex() {
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.clearMessages()
        XCTAssertEqual(conversation.messages.count, 0)
        // Should be able to insert same ID after clear
        let idx = conversation.insertByParent(makeMessage(id: "A"))
        XCTAssertEqual(idx, 0)
    }

    // MARK: - Reparenting

    func testMoveMessage_reparentsCorrectly() {
        // A → B → C, then B gets reparented to have parent C (moving B after C)
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        XCTAssertEqual(messageIds(), ["A", "B", "C"])

        conversation.moveMessage(messageId: "B", newParentId: "C")
        // After reparenting: A, C, B
        XCTAssertEqual(messageIds(), ["A", "C", "B"])
    }

    // MARK: - Reload Into Existing Conversation (background→foreground)

    func testInsertByParent_loadIntoDuplicates_skipsAll() {
        // Pre-load conversation
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        XCTAssertEqual(conversation.messages.count, 3)

        // Simulate reload returning same messages (all duplicates)
        let idxA = conversation.insertByParent(makeMessage(id: "A"))
        let idxB = conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        let idxC = conversation.insertByParent(makeMessage(id: "C", parentId: "B"))

        // All should be skipped (-1)
        XCTAssertEqual(idxA, -1)
        XCTAssertEqual(idxB, -1)
        XCTAssertEqual(idxC, -1)
        XCTAssertEqual(conversation.messages.count, 3)
        XCTAssertEqual(messageIds(), ["A", "B", "C"])
    }

    func testInsertByParent_loadWithNewMessages_insertsOnlyNew() {
        // Pre-load conversation with A → B → C
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))

        // Reload returns [A, B, C, D, E] — D, E are new (from background)
        conversation.insertByParent(makeMessage(id: "A"))          // dup, skipped
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))  // dup
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))  // dup
        conversation.insertByParent(makeMessage(id: "D", parentId: "C"))  // NEW
        conversation.insertByParent(makeMessage(id: "E", parentId: "D"))  // NEW

        XCTAssertEqual(conversation.messages.count, 5)
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D", "E"])
    }

    func testInsertByParent_raceNewInteractionDuringReload() {
        // Pre-load conversation with A → B → C
        conversation.insertByParent(makeMessage(id: "A"))
        conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        conversation.insertByParent(makeMessage(id: "C", parentId: "B"))

        // newInteraction arrives BEFORE conversationLoaded (D is new from background)
        conversation.insertByParent(makeMessage(id: "D", parentId: "C"))
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D"])

        // conversationLoaded returns [A, B, C, D] — all duplicates now
        let idxA = conversation.insertByParent(makeMessage(id: "A"))
        let idxB = conversation.insertByParent(makeMessage(id: "B", parentId: "A"))
        let idxC = conversation.insertByParent(makeMessage(id: "C", parentId: "B"))
        let idxD = conversation.insertByParent(makeMessage(id: "D", parentId: "C"))

        // All skipped — no duplication, no reordering
        XCTAssertEqual(idxA, -1)
        XCTAssertEqual(idxB, -1)
        XCTAssertEqual(idxC, -1)
        XCTAssertEqual(idxD, -1)
        XCTAssertEqual(conversation.messages.count, 4)
        XCTAssertEqual(messageIds(), ["A", "B", "C", "D"])
    }

    // MARK: - Performance

    func testInsertByParent_performance_1000messages() {
        measure {
            let conv = ConversationModel(withId: "perf", accountId: accountId1)
            conv.type = .oneToOne
            // Linear chain: most common case (fast path)
            var prevId = ""
            for num in 0..<1000 {
                let msgId = "msg\(num)"
                let msg = makeMessage(id: msgId, parentId: prevId)
                conv.insertByParent(msg)
                prevId = msgId
            }
            XCTAssertEqual(conv.messages.count, 1000)
        }
    }
}
