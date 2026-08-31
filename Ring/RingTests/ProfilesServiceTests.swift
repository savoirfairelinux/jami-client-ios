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
import RxSwift
@testable import Ring

final class ProfilesServiceTests: XCTestCase {

    private final class StubDBManager: DBManager {
        struct Key: Hashable {
            let uri: String
            let accountId: String
        }
        var seed: [Key: Profile] = [:]

        override func profileObservable(for profileUri: String,
                                        accountId: String) -> Observable<Profile> {
            let key = Key(uri: profileUri, accountId: accountId)
            if let profile = seed[key] {
                return .just(profile)
            }
            return .error(DBBridgingError.getProfileFailed)
        }
    }

    private var database: StubDBManager!
    private var service: ProfilesService!
    private var bag: DisposeBag!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = StubDBManager(conversationHelper: ConversationDataHelper(),
                                 interactionHepler: InteractionDataHelper(),
                                 dbConnections: DBContainer())
        service = ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: database)
        bag = DisposeBag()
    }

    override func tearDownWithError() throws {
        bag = nil
        service = nil
        database = nil
        try super.tearDownWithError()
    }

    func testSameUriAcrossTwoAccountsDoesNotCrossContaminate() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        database.seed[.init(uri: uri, accountId: accountId1)] =
            Profile(uri: uri, alias: profileName1, photo: nil, type: ProfileType.ring.rawValue)
        database.seed[.init(uri: uri, accountId: accountId2)] =
            Profile(uri: uri, alias: profileName2, photo: nil, type: ProfileType.ring.rawValue)

        let exp1 = expectation(description: "account 1 resolved")
        let exp2 = expectation(description: "account 2 resolved")
        var alias1: String?
        var alias2: String?

        // Account 1 subscribes first — mirrors the Share Extension activating account 1
        // and its daemon pushing profile vcards before the main app (on account 2) opens.
        service.getProfile(uri: uri, accountId: accountId1)
            .take(1)
            .subscribe(onNext: { profile in
                alias1 = profile.alias
                exp1.fulfill()
            })
            .disposed(by: bag)

        // Account 2 subscribes shortly after — if the cache is keyed by URI alone, it
        // will receive the ReplaySubject seeded with account 1's profile.
        service.getProfile(uri: uri, accountId: accountId2)
            .take(1)
            .subscribe(onNext: { profile in
                alias2 = profile.alias
                exp2.fulfill()
            })
            .disposed(by: bag)

        await fulfillment(of: [exp1, exp2], timeout: 2.0)

        XCTAssertEqual(alias1, profileName1,
                       "account 1 should resolve to its own seeded profile")
        XCTAssertEqual(alias2, profileName2,
                       "account 2 must receive its own profile, not account 1's cached one")
    }

    // MARK: - Directory profiles

    private let directoryAlias = "Ada Lovelace"
    private let directoryPhoto = "directory-photo"

    private func resolvedProfile(uri: String) async throws -> Profile {
        let resolved = expectation(description: "profile resolved")
        var result: Profile?
        service.getProfile(uri: uri, accountId: accountId1)
            .take(1)
            .subscribe(onNext: { profile in
                result = profile
                resolved.fulfill()
            })
            .disposed(by: bag)
        await fulfillment(of: [resolved], timeout: 2.0)
        return try XCTUnwrap(result)
    }

    func testDirectoryProfileIsUsedWhenNothingIsStored() async throws {
        // Arrange
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        // Act
        service.cacheDirectoryProfile(uri: uri,
                                      accountId: accountId1,
                                      alias: directoryAlias,
                                      photo: directoryPhoto)
        let profile = try await resolvedProfile(uri: uri)
        // Assert
        XCTAssertEqual(profile.alias, directoryAlias)
        XCTAssertEqual(profile.photo, directoryPhoto)
    }

    func testStoredProfileWinsOverDirectoryProfile() async throws {
        // Arrange
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        database.seed[.init(uri: uri, accountId: accountId1)] =
            Profile(uri: uri, alias: profileName1, photo: "stored-photo", type: ProfileType.ring.rawValue)
        // Act
        service.cacheDirectoryProfile(uri: uri,
                                      accountId: accountId1,
                                      alias: directoryAlias,
                                      photo: directoryPhoto)
        let profile = try await resolvedProfile(uri: uri)
        // Assert
        XCTAssertEqual(profile.alias, profileName1)
        XCTAssertEqual(profile.photo, "stored-photo")
    }

    func testDirectoryProfileFillsGapsInAStoredProfile() async throws {
        // Arrange
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        database.seed[.init(uri: uri, accountId: accountId1)] =
            Profile(uri: uri, alias: profileName1, photo: nil, type: ProfileType.ring.rawValue)
        // Act
        service.cacheDirectoryProfile(uri: uri,
                                      accountId: accountId1,
                                      alias: directoryAlias,
                                      photo: directoryPhoto)
        let profile = try await resolvedProfile(uri: uri)
        // Assert
        XCTAssertEqual(profile.alias, profileName1)
        XCTAssertEqual(profile.photo, directoryPhoto)
    }

    func testEmptyDirectoryProfileIsNotCached() async throws {
        // Arrange
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        // Act
        service.cacheDirectoryProfile(uri: uri, accountId: accountId1, alias: nil, photo: nil)
        let profile = try await resolvedProfile(uri: uri)
        // Assert
        XCTAssertNil(profile.alias)
        XCTAssertNil(profile.photo)
    }

    func testLocalOverrideReplacesOnlyCustomizedName() {
        let remote = Profile(uri: "jami:peer",
                             alias: "Remote name",
                             photo: "remote-photo",
                             type: ProfileType.ring.rawValue)
        let local = Profile(uri: "jami:peer",
                            alias: "My contact name",
                            photo: nil,
                            type: ProfileType.ring.rawValue)

        let merged = remote.merging(preferring: local)

        XCTAssertEqual(merged.alias, "My contact name")
        XCTAssertEqual(merged.photo, "remote-photo")
    }

    func testLocalOverrideReplacesOnlyCustomizedPhoto() {
        let remote = Profile(uri: "jami:peer",
                             alias: "Remote name",
                             photo: "remote-photo",
                             type: ProfileType.ring.rawValue)
        let local = Profile(uri: "jami:peer",
                            alias: nil,
                            photo: "local-photo",
                            type: ProfileType.ring.rawValue)

        let merged = remote.merging(preferring: local)

        XCTAssertEqual(merged.alias, "Remote name")
        XCTAssertEqual(merged.photo, "local-photo")
    }

    func testEmptyLocalOverrideRestoresRemoteProfile() {
        let remote = Profile(uri: "jami:peer",
                             alias: "Updated remote name",
                             photo: "updated-remote-photo",
                             type: ProfileType.ring.rawValue)
        let local = Profile(uri: "jami:peer",
                            alias: nil,
                            photo: nil,
                            type: ProfileType.ring.rawValue)

        let merged = remote.merging(preferring: local)

        XCTAssertEqual(merged.alias, "Updated remote name")
        XCTAssertEqual(merged.photo, "updated-remote-photo")
        XCTAssertTrue(local.isEmpty)
    }
}
