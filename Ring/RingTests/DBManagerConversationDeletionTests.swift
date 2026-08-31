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
import RxSwift
@testable import Ring

final class DBManagerConversationDeletionTests: XCTestCase {

    private var accountId: String!
    private var container: DBContainer!
    private var conversationHelper: ConversationDataHelper!
    private var interactionHelper: InteractionDataHelper!
    private var manager: DBManager!
    private var store: ProfileStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard Constants.documentsPath != nil else {
            throw XCTSkip("The shared documents container is unavailable")
        }

        accountId = "db-manager-tests-\(UUID().uuidString)"
        container = DBContainer()
        store = ProfileStore()
        conversationHelper = ConversationDataHelper()
        interactionHelper = InteractionDataHelper()
        manager = DBManager(conversationHelper: conversationHelper,
                            interactionHepler: interactionHelper,
                            dbConnections: container)
        XCTAssertTrue(try manager.createDatabaseForAccount(accountId: accountId, createFolder: true))
    }

    override func tearDownWithError() throws {
        if let accountId, let container {
            container.removeDBForAccount(account: accountId, removeFolder: true)
        }
        manager = nil
        interactionHelper = nil
        conversationHelper = nil
        container = nil
        store = nil
        accountId = nil
        try super.tearDownWithError()
    }

    func testDeletingProfilelessSIPConversation() throws {
        let uri = "sip:1001@example.com"
        try insertConversation(uri: uri)

        try clearHistory(for: uri, keepConversation: false)

        XCTAssertTrue(try conversations(for: uri).isEmpty)
    }

    func testDeletingProfilelessJamiConversation() throws {
        let uri = "jami:\(jamiId1)"
        try insertConversation(uri: uri)

        try clearHistory(for: uri, keepConversation: false)

        XCTAssertTrue(try conversations(for: uri).isEmpty)
    }

    func testClearingHistoryKeepsProfilelessConversation() throws {
        let uri = "sip:1001@example.com"
        let conversationId = try insertConversation(uri: uri)
        try insertInteraction(conversationId: conversationId)

        try clearHistory(for: uri, keepConversation: true)

        XCTAssertEqual(try conversations(for: uri).count, 1)
        XCTAssertTrue(try interactions(for: conversationId).isEmpty)
    }

    func testDeletingMissingConversationDoesNotCreateOne() throws {
        let uri = "sip:missing@example.com"

        XCTAssertThrowsError(try clearHistory(for: uri, keepConversation: false))
        XCTAssertTrue(try conversations(for: uri).isEmpty)
    }

    func testConversationParticipantsListsPeersWithoutProfileFiles() throws {
        try insertConversation(uri: "sip:1001@example.com")
        try insertConversation(uri: "sip:1002@example.com")

        XCTAssertEqual(Set(manager.conversationParticipants(accountId: accountId)),
                       ["sip:1001@example.com", "sip:1002@example.com"])
    }

    func testConversationParticipantsIsEmptyWhenNoConversationExists() {
        XCTAssertTrue(manager.conversationParticipants(accountId: accountId).isEmpty)
    }

    func testDeletingConversationKeepsPeerVCardAndDeletesClientFiles() throws {
        let uri = "jami:\(jamiId1)"
        let documents = try XCTUnwrap(Constants.documentsPath)
        _ = try XCTUnwrap(container.contactsPath(accountId: accountId, createIfNotExists: true))
        let vCardPath = ProfilePathHelper.contactProfilePath(accountId: accountId,
                                                             contactId: uri,
                                                             documents: documents)
        let peerVCard = try XCTUnwrap(vCardPath)
        let legacyProfiles = ProfilePathHelper.profileURICandidates(for: uri).compactMap {
            ProfilePathHelper.legacyContactProfilePath(accountId: accountId,
                                                       profileURI: $0,
                                                       documents: documents)
        }
        let overridePath = ProfilePathHelper.contactProfileOverridePath(accountId: accountId,
                                                                        profileURI: uri,
                                                                        documents: documents,
                                                                        createIfNotExists: true)
        let localOverride = try XCTUnwrap(overridePath)
        let data = Data("profile".utf8)
        try data.write(to: URL(fileURLWithPath: peerVCard))
        for path in legacyProfiles + [localOverride] {
            try data.write(to: URL(fileURLWithPath: path))
        }

        store.removeLegacyContactProfiles(uri: uri, accountId: accountId)
        store.remove(uri: uri, accountId: accountId, source: .localOverride)

        XCTAssertTrue(FileManager.default.fileExists(atPath: peerVCard))
        for path in legacyProfiles + [localOverride] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        }
    }

    func testManagedProfileRoundTripsBinaryData() throws {
        let uri = "jami:\(jamiId1)"
        let photo = Data([0, 1, 2, 255]).base64EncodedString()
        let invitation = Profile(uri: uri,
                                 alias: profileName1,
                                 photo: photo,
                                 type: ProfileType.ring.rawValue)

        XCTAssertTrue(store.save(invitation, accountId: accountId, source: .invitation))

        let loaded = try XCTUnwrap(store.profile(uri: uri, accountId: accountId, source: .invitation))
        XCTAssertEqual(loaded.alias, profileName1)
        XCTAssertEqual(loaded.photo, photo)
    }

    func testManagedProfilesAreKeptPerSource() throws {
        let uri = "jami:\(jamiId1)"
        let invitation = Profile(uri: uri, alias: profileName1, photo: nil, type: ProfileType.ring.rawValue)
        let directory = Profile(uri: uri, alias: profileName2, photo: nil, type: ProfileType.ring.rawValue)
        XCTAssertTrue(store.save(invitation, accountId: accountId, source: .invitation))
        XCTAssertTrue(store.save(directory, accountId: accountId, source: .jamsSearch))

        store.remove(uri: uri, accountId: accountId, source: .jamsSearch)

        XCTAssertEqual(store.profile(uri: uri, accountId: accountId, source: .invitation)?.alias, profileName1)
        XCTAssertNil(store.profile(uri: uri, accountId: accountId, source: .jamsSearch))
    }

    func testEmptyProfileIsNotStored() throws {
        let uri = "jami:\(jamiId1)"
        let empty = Profile(uri: uri, alias: nil, photo: nil, type: ProfileType.ring.rawValue)

        XCTAssertFalse(store.save(empty, accountId: accountId, source: .invitation))
        XCTAssertNil(store.profile(uri: uri, accountId: accountId, source: .invitation))
    }

    func testUnreadableManagedProfileIsIgnored() throws {
        let uri = "jami:\(jamiId1)"
        let documents = try XCTUnwrap(Constants.documentsPath)
        let managedPath = ProfilePathHelper.profilePath(accountId: accountId,
                                                        contactId: uri,
                                                        folder: .invitation,
                                                        documents: documents,
                                                        createIfNotExists: true)
        let path = try XCTUnwrap(managedPath)
        try Data("not a vcard".utf8).write(to: URL(fileURLWithPath: path))

        XCTAssertNil(store.profile(uri: uri, accountId: accountId, source: .invitation))
    }

    @discardableResult
    private func insertConversation(uri: String) throws -> Int64 {
        let database = try XCTUnwrap(container.forAccount(account: accountId))
        let conversationId = Int64.random(in: 1...Int64.max)
        XCTAssertTrue(conversationHelper.insert(item: (conversationId, uri), dataBase: database))
        return conversationId
    }

    private func insertInteraction(conversationId: Int64) throws {
        let database = try XCTUnwrap(container.forAccount(account: accountId))
        let interaction = Interaction(id: 0,
                                      author: nil,
                                      conversation: conversationId,
                                      timestamp: 0,
                                      duration: 0,
                                      body: "message",
                                      type: InteractionType.text.rawValue,
                                      status: InteractionStatus.succeed.rawValue,
                                      daemonID: UUID().uuidString,
                                      incoming: false)
        XCTAssertNotNil(interactionHelper.insert(item: interaction, dataBase: database))
    }

    private func conversations(for uri: String) throws -> [Conversation] {
        let database = try XCTUnwrap(container.forAccount(account: accountId))
        return try XCTUnwrap(conversationHelper.selectConversationsForProfile(profileUri: uri,
                                                                              dataBase: database))
    }

    private func interactions(for conversationId: Int64) throws -> [Interaction] {
        let database = try XCTUnwrap(container.forAccount(account: accountId))
        return try XCTUnwrap(interactionHelper.selectInteractionsForConversation(conv: conversationId,
                                                                                 dataBase: database))
    }

    private func clearHistory(for uri: String, keepConversation: Bool) throws {
        let terminalEvent = expectation(description: "clear history terminates")
        var receivedError: Error?
        let disposable = manager
            .clearHistoryFor(accountId: accountId, and: uri, keepConversation: keepConversation)
            .subscribe(onCompleted: {
                terminalEvent.fulfill()
            }, onError: { error in
                receivedError = error
                terminalEvent.fulfill()
            })

        wait(for: [terminalEvent], timeout: 1)
        withExtendedLifetime(disposable) {}
        if let receivedError {
            throw receivedError
        }
    }
}
