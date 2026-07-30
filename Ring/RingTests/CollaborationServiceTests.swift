/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
import RxSwift
@testable import Ring

final class CollaborationServiceTests: XCTestCase {
    private let accountId = "account"
    private let conversationId = "conversation"
    private let documentId = "document"

    private var service: CollaborationService!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        service = CollaborationService(withCollaborationAdapter: ObjCMockCollaborationAdapter())
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        disposeBag = nil
        service = nil
        super.tearDown()
    }

    func testDocumentReadsIdentifierFromIdKey() {
        let document = CollaborativeDocument(fromNative: [
            "id": documentId,
            "displayName": "Notes",
            "mimeType": "text/plain",
            "author": "author",
            "timestamp": "42"
        ])

        XCTAssertEqual(document?.id, documentId)
    }

    func testEmptyUpdateIsAChangeNotification() {
        let notificationReceived = expectation(description: "Empty payload delivered as a notification")
        let updateLeaked = expectation(description: "Empty payload must not reach the editor update stream")
        updateLeaked.isInverted = true

        service.updates(forAccount: accountId,
                        conversationId: conversationId,
                        documentId: documentId)
            .subscribe(onNext: { _ in updateLeaked.fulfill() })
            .disposed(by: disposeBag)

        service.changes(forAccount: accountId,
                        conversationId: conversationId,
                        documentId: documentId)
            .subscribe(onNext: { change in
                XCTAssertEqual(change, .notification)
                notificationReceived.fulfill()
            })
            .disposed(by: disposeBag)

        service.documentUpdate(withAccountId: accountId,
                               conversationId: conversationId,
                               documentId: documentId,
                               update: Data())

        wait(for: [notificationReceived, updateLeaked], timeout: 1)
    }
}
