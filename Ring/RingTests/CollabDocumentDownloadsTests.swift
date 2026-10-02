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

final class CollabDocumentDownloadsTests: XCTestCase {

    private let conversationId = "7d387e1ce2beb29562a298bcbd3a20040ef28376"
    private let otherConversationId = "2d58a6278ac6de0f3e5fa9e1f1d8b4c0a5d5e6f7"
    private let documentId = "5c69ce6a5867b0b74baa3fbe73edd6e7954e1ba5"
    private let otherDocumentId = "f491fc84cfd5f9fc8856af368cc16802d287a3c1"

    func testNothingIsAwaitedAtFirst() {
        XCTAssertFalse(CollabDocumentDownloads().isAwaiting)
    }

    func testAnAnnouncedDocumentIsAwaitedUntilDownloaded() {
        var downloads = CollabDocumentDownloads()

        downloads.documentAnnounced(conversationId: conversationId, documentId: documentId)
        XCTAssertTrue(downloads.isAwaiting)

        downloads.documentDownloaded(conversationId: conversationId, documentId: documentId)
        XCTAssertFalse(downloads.isAwaiting)
    }

    func testEveryAnnouncedDocumentIsAwaited() {
        var downloads = CollabDocumentDownloads()
        downloads.documentAnnounced(conversationId: conversationId, documentId: documentId)
        downloads.documentAnnounced(conversationId: conversationId, documentId: otherDocumentId)

        downloads.documentDownloaded(conversationId: conversationId, documentId: documentId)
        XCTAssertTrue(downloads.isAwaiting)

        downloads.documentDownloaded(conversationId: conversationId, documentId: otherDocumentId)
        XCTAssertFalse(downloads.isAwaiting)
    }

    func testADocumentDownloadedBeforeItsAnnouncementIsNotAwaited() {
        // The daemon starts downloading as soon as it reads the announcement,
        // and can be done before the extension is told about it.
        var downloads = CollabDocumentDownloads()

        downloads.documentDownloaded(conversationId: conversationId, documentId: documentId)
        downloads.documentAnnounced(conversationId: conversationId, documentId: documentId)

        XCTAssertFalse(downloads.isAwaiting)
    }

    func testADownloadOnlyCountsForTheConversationThatAnnouncedIt() {
        var downloads = CollabDocumentDownloads()
        downloads.documentAnnounced(conversationId: conversationId, documentId: documentId)
        downloads.documentAnnounced(conversationId: otherConversationId, documentId: documentId)

        downloads.documentDownloaded(conversationId: otherConversationId, documentId: documentId)
        XCTAssertTrue(downloads.isAwaiting)

        downloads.documentDownloaded(conversationId: conversationId, documentId: documentId)
        XCTAssertFalse(downloads.isAwaiting)
    }
}
