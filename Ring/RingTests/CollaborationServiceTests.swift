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
    private let localJamiId = "0123456789abcdef0123456789abcdef01234567"

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

    // MARK: - Which removals a document offers

    private func document(author: String?, storedLocally: Bool) throws -> CollaborativeDocument {
        var map = ["id": documentId, "displayName": "Notes", "timestamp": "42"]
        if let author = author {
            map["author"] = author
        }
        // Only a local removal writes this key, and it writes "false".
        if !storedLocally {
            map["storedLocally"] = "false"
        }
        return try XCTUnwrap(CollaborativeDocument(fromNative: map))
    }

    func testAuthorMayRetireItsOwnDocumentForEveryone() throws {
        let removals = try CollabDocumentRemoval
            .available(for: document(author: localJamiId, storedLocally: true),
                       localJamiId: localJamiId)

        XCTAssertEqual(removals, [.fromThisDevice, .forEveryone])
    }

    func testAMemberMayOnlyStopHoldingSomeoneElsesDocument() throws {
        let removals = try CollabDocumentRemoval
            .available(for: document(author: "someone-else", storedLocally: true),
                       localJamiId: localJamiId)

        XCTAssertEqual(removals, [.fromThisDevice])
    }

    /**
     An account that could not be read matches nobody, not even a document whose
     author is unknown too.

     Only the empty `localJamiId` is exercised here. The model already collapses
     an empty author to nil, and declaring `init?(fromNative:)` in its body
     suppresses the memberwise initializer, so a document with an empty author is
     not something a test can build: the guard against one is defence in depth
     against a state the model cannot hold.
     */
    func testAnUnknownIdentityIsNeverTheAuthor() throws {
        XCTAssertEqual(try CollabDocumentRemoval
            .available(for: document(author: localJamiId, storedLocally: true), localJamiId: ""),
                       [.fromThisDevice])
        XCTAssertEqual(try CollabDocumentRemoval
            .available(for: document(author: nil, storedLocally: true), localJamiId: localJamiId),
                       [.fromThisDevice])
    }

    func testADocumentThisDeviceDoesNotHoldCannotBeDroppedAgain() throws {
        XCTAssertEqual(try CollabDocumentRemoval
            .available(for: document(author: localJamiId, storedLocally: false),
                       localJamiId: localJamiId),
                       [.forEveryone])
        XCTAssertTrue(try CollabDocumentRemoval
            .available(for: document(author: "someone-else", storedLocally: false),
                       localJamiId: localJamiId).isEmpty)
    }

    func testEveryRemovalIsNamedOnBothSurfaces() {
        for removal in CollabDocumentRemoval.allCases {
            XCTAssertFalse(removal.menuTitle.isEmpty)
            XCTAssertFalse(removal.swipeTitle.isEmpty)
            XCTAssertFalse(removal.symbol.isEmpty)
            XCTAssertFalse(removal.alertTitle.isEmpty)
            XCTAssertFalse(removal.alertMessage(for: "Notes").isEmpty)
        }
        // A translation may legitimately collapse two titles into one; a symbol
        // is not translated, and telling the two removals apart is its whole job.
        let symbols = Set(CollabDocumentRemoval.allCases.map { $0.symbol })
        XCTAssertEqual(symbols.count, CollabDocumentRemoval.allCases.count)
    }

    func testAResolvedAuthorIsNamed() {
        XCTAssertEqual(CollabDocumentsVM.authorName(for: "author-uri",
                                                    resolved: ["author-uri": "Alice"],
                                                    localJamiId: localJamiId),
                       "Alice")
    }

    func testAnAuthorlessDocumentIsNotAttributed() {
        XCTAssertNil(CollabDocumentsVM.authorName(for: nil,
                                                  resolved: [:],
                                                  localJamiId: localJamiId))
        XCTAssertNil(CollabDocumentsVM.authorName(for: "",
                                                  resolved: [:],
                                                  localJamiId: localJamiId))
    }

    func testAnUnresolvedAuthorIsShortened() {
        XCTAssertEqual(CollabDocumentsVM.authorName(for: "0123456789abcdef",
                                                    resolved: [:],
                                                    localJamiId: localJamiId),
                       "01234567")
    }

    func testAShortUnresolvedAuthorIsLeftWhole() {
        XCTAssertEqual(CollabDocumentsVM.authorName(for: "abc",
                                                    resolved: [:],
                                                    localJamiId: localJamiId),
                       "abc")
    }

    func testALookupThatResolvedNothingFallsBack() {
        XCTAssertEqual(CollabDocumentsVM.authorName(for: "0123456789abcdef",
                                                    resolved: ["0123456789abcdef": "0123456789abcdef"],
                                                    localJamiId: localJamiId),
                       "01234567")
        XCTAssertEqual(CollabDocumentsVM.authorName(for: "0123456789abcdef",
                                                    resolved: ["0123456789abcdef": ""],
                                                    localJamiId: localJamiId),
                       "01234567")
    }

    func testYourOwnDocumentSaysSo() {
        let name = CollabDocumentsVM.authorName(for: localJamiId,
                                                resolved: [localJamiId: "Alice"],
                                                localJamiId: localJamiId)

        XCTAssertEqual(name, "Alice".withYourselfSuffix())
    }

    func testYourOwnDocumentSaysSoEvenUnresolved() {
        let name = CollabDocumentsVM.authorName(for: localJamiId,
                                                resolved: [:],
                                                localJamiId: localJamiId)

        XCTAssertEqual(name, String(localJamiId.prefix(8)).withYourselfSuffix())
    }

    func testAnUnreadableAccountClaimsNoDocument() {
        let name = CollabDocumentsVM.authorName(for: "author-uri",
                                                resolved: ["author-uri": "Alice"],
                                                localJamiId: "")

        XCTAssertEqual(name, "Alice")
    }
}
