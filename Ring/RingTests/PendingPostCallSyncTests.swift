/*
 *  Copyright (C) 2026 - 2026 Savoir-faire Linux Inc.
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

final class PendingPostCallSyncTests: XCTestCase {

    private let callEndedAt = Date()
    private lazy var pending = PendingPostCallSync(accountId: accountId1, peerHash: jamiId1,
                                                   conversationId: conversationId1,
                                                   callEndedAt: callEndedAt)

    private func message(type: MessageType, author: String, date: Date? = nil) -> MessageModel {
        let timestamp = String((date ?? callEndedAt).timeIntervalSince1970)
        return MessageModel(withInfo: [MessageAttributes.interactionId.rawValue: "commit1",
                                       MessageAttributes.type.rawValue: type.rawValue,
                                       MessageAttributes.author.rawValue: author,
                                       MessageAttributes.timestamp.rawValue: timestamp],
                            localJamiId: jamiId2)
    }

    func testMissedCallCommitFromPeerConfirms() {
        let commit = message(type: .call, author: jamiId1)
        XCTAssertTrue(pending.isConfirmed(by: commit, from: accountId1, in: conversationId1))
    }

    func testCallCommitOnAnotherAccountDoesNotConfirm() {
        let commit = message(type: .call, author: jamiId1)
        XCTAssertFalse(pending.isConfirmed(by: commit, from: accountId2, in: conversationId1))
    }

    func testCallCommitFromAnotherAuthorDoesNotConfirm() {
        let commit = message(type: .call, author: jamiId3)
        XCTAssertFalse(pending.isConfirmed(by: commit, from: accountId1, in: conversationId1))
    }

    func testTextCommitFromPeerDoesNotConfirm() {
        let commit = message(type: .text, author: jamiId1)
        XCTAssertFalse(pending.isConfirmed(by: commit, from: accountId1, in: conversationId1))
    }

    func testCallCommitInAnotherConversationDoesNotConfirm() {
        let commit = message(type: .call, author: jamiId1)
        XCTAssertFalse(pending.isConfirmed(by: commit, from: accountId1, in: conversationId2))
    }

    func testCallCommitFromEarlierCallDoesNotConfirm() {
        let commit = message(type: .call, author: jamiId1,
                             date: callEndedAt.addingTimeInterval(-600))
        XCTAssertFalse(pending.isConfirmed(by: commit, from: accountId1, in: conversationId1))
    }

    func testCallCommitWithinClockSkewConfirms() {
        let commit = message(type: .call, author: jamiId1,
                             date: callEndedAt.addingTimeInterval(-10))
        XCTAssertTrue(pending.isConfirmed(by: commit, from: accountId1, in: conversationId1))
    }

    func testAnyConversationConfirmsWhenConversationUnknown() {
        let pending = PendingPostCallSync(accountId: accountId1, peerHash: jamiId1,
                                          conversationId: "", callEndedAt: callEndedAt)
        let commit = message(type: .call, author: jamiId1)
        XCTAssertTrue(pending.isConfirmed(by: commit, from: accountId1, in: conversationId2))
    }
}
