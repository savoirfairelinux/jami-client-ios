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

final class CollabDocumentAnnouncementTests: XCTestCase {

    private let documentType = "application/collab-doc+json"
    private let documentId = "5c69ce6a5867b0b74baa3fbe73edd6e7954e1ba5"

    func testAnnouncementGivesTheDocumentAndItsName() {
        let announcement = CollabDocumentAnnouncement(message: [
            "type": documentType,
            "uri": documentId,
            "displayName": "Notes",
            "mimeType": "text/html"
        ])

        XCTAssertEqual(announcement?.documentId, documentId)
        XCTAssertEqual(announcement?.name, "Notes")
    }

    func testAnnouncementWithoutNameHasAnEmptyName() {
        let announcement = CollabDocumentAnnouncement(message: ["type": documentType, "uri": documentId])

        XCTAssertEqual(announcement?.documentId, documentId)
        XCTAssertEqual(announcement?.name, "")
    }

    func testRetiringADocumentIsNotAnAnnouncement() {
        // A document is retired by editing its announcement with a commit of the same type.
        XCTAssertNil(CollabDocumentAnnouncement(message: ["type": documentType,
                                                          "edit": "8a3828b5d0450f69988d84baaf0ded8b4614cd14"]))
        XCTAssertNil(CollabDocumentAnnouncement(message: ["type": documentType,
                                                          "edit": "8a3828b5d0450f69988d84baaf0ded8b4614cd14",
                                                          "uri": documentId]))
    }

    func testOtherMessagesAreNotAnnouncements() {
        XCTAssertNil(CollabDocumentAnnouncement(message: ["type": "text/plain", "uri": documentId]))
        XCTAssertNil(CollabDocumentAnnouncement(message: ["type": documentType]))
        XCTAssertNil(CollabDocumentAnnouncement(message: ["type": documentType, "uri": ""]))
    }
}
