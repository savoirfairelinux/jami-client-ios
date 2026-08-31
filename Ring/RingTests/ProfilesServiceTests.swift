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

    private final class StubProfileStore: ProfileStore {
        struct Key: Hashable {
            let uri: String
            let accountId: String
            let source: ProfileSource
        }
        var profiles: [Key: Profile] = [:]

        override func profile(uri: String, accountId: String, source: ProfileSource) -> Profile? {
            profiles[Key(uri: uri, accountId: accountId, source: source)]
        }

        override func save(_ profile: Profile, accountId: String, source: ManagedProfileSource) -> Bool {
            profiles[Key(uri: profile.uri, accountId: accountId, source: source.profileSource)] = profile
            return true
        }

        override func remove(uri: String, accountId: String, source: ManagedProfileSource) {
            profiles[Key(uri: uri, accountId: accountId, source: source.profileSource)] = nil
        }

        override func legacyContactProfile(uri: String, accountId: String) -> Profile? {
            nil
        }

        override func removeLegacyContactProfiles(uri: String, accountId: String) {}

        override func removeAllManagedProfiles(accountId: String) {
            profiles = profiles.filter { $0.key.accountId != accountId || $0.key.source == .contact }
        }
    }

    private var store: StubProfileStore!
    private var service: ProfilesService!
    private var bag: DisposeBag!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = StubProfileStore()
        service = ProfilesService(withProfilesAdapter: ProfilesAdapter(), profileStore: store)
        bag = DisposeBag()
    }

    override func tearDownWithError() throws {
        bag = nil
        service = nil
        store = nil
        try super.tearDownWithError()
    }

    func testProfileUriStringExcludesSipHostAndPort() {
        let uri = JamiURI(from: "sip:alice@example.com:5060")

        XCTAssertEqual(ProfilesService.profileUriString(for: uri), "sip:alice")
    }

    func testProfileUriStringAcceptsBareSipPeerIdentifier() {
        let uri = JamiURI(schema: .sip, infoHash: "alice")

        XCTAssertEqual(ProfilesService.profileUriString(for: uri), "sip:alice")
    }

    // MARK: - Helpers

    private func profile(_ alias: String?, photo: String? = nil, uri: String) -> Profile {
        Profile(uri: uri, alias: alias, photo: photo, type: ProfileType.ring.rawValue)
    }

    private func seed(_ profile: Profile, accountId: String, source: ProfileSource) {
        store.profiles[.init(uri: profile.uri, accountId: accountId, source: source)] = profile
    }

    private func stored(uri: String, accountId: String, source: ProfileSource) -> Profile? {
        store.profiles[.init(uri: uri, accountId: accountId, source: source)]
    }

    private func resolvedProfile(uri: String, accountId: String = accountId1) async throws -> Profile {
        let resolved = expectation(description: "profile resolved")
        var result: Profile?
        service.getProfile(uri: uri, accountId: accountId)
            .take(1)
            .subscribe(onNext: { profile in
                result = profile
                resolved.fulfill()
            })
            .disposed(by: bag)
        await fulfillment(of: [resolved], timeout: 2.0)
        return try XCTUnwrap(result)
    }

    // MARK: - Resolution

    func testSameUriAcrossTwoAccountsDoesNotCrossContaminate() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .contact)
        seed(profile(profileName2, uri: uri), accountId: accountId2, source: .contact)

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

    func testContactProfileWinsOverInvitationProfile() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let contactPhoto = Data("contact-photo".utf8).base64EncodedString()
        seed(profile(profileName1, photo: contactPhoto, uri: uri), accountId: accountId1, source: .contact)
        seed(profile(profileName2, photo: Data("request-photo".utf8).base64EncodedString(), uri: uri),
             accountId: accountId1, source: .invitation)

        let resolved = try await resolvedProfile(uri: uri)

        XCTAssertEqual(resolved.alias, profileName1)
        XCTAssertEqual(resolved.photo, contactPhoto)
    }

    func testContactProfileCompletelyReplacesInvitationProfile() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName2, uri: uri), accountId: accountId1, source: .contact)
        seed(profile(profileName1, photo: Data("request-photo".utf8).base64EncodedString(), uri: uri),
             accountId: accountId1, source: .invitation)

        let resolved = try await resolvedProfile(uri: uri)

        XCTAssertEqual(resolved.alias, profileName2)
        XCTAssertNil(resolved.photo, "a peer vCard must not be completed with fields from another source")
    }

    func testStoredInvitationProfileIsUsedWhenThePeerVCardIsMissing() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let photo = Data("stored-photo".utf8).base64EncodedString()
        seed(profile(profileName1, photo: photo, uri: uri), accountId: accountId1, source: .invitation)

        let resolved = try await resolvedProfile(uri: uri)

        XCTAssertEqual(resolved.alias, profileName1)
        XCTAssertEqual(resolved.photo, photo)
    }

    func testJamsSearchProfileWinsOverInvitationProfile() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName2, uri: uri), accountId: accountId1, source: .invitation)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .jamsSearch)

        let resolved = try await resolvedProfile(uri: uri)

        XCTAssertEqual(resolved.alias, profileName1)
    }

    func testEmptySentJamsProfileIsNotStored() async throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let empty = profile(nil, uri: uri)

        service.invitationSent(empty, accountId: accountId1)
        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .jamsSearch))
        let resolved = try await resolvedProfile(uri: uri)

        XCTAssertNil(resolved.alias)
        XCTAssertNil(resolved.photo)
    }

    // MARK: - Lifecycle

    func testAcceptedRequestStoresTheInvitationProfile() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let peer = profile(profileName1, photo: Data("request-photo".utf8).base64EncodedString(), uri: uri)

        service.invitationAccepted(peer, accountId: accountId1)

        XCTAssertEqual(stored(uri: uri, accountId: accountId1, source: .invitation)?.alias, profileName1)
        XCTAssertEqual(stored(uri: uri, accountId: accountId1, source: .invitation)?.photo, peer.photo)
    }

    func testDiscardedRequestRemovesStoredPeerProfiles() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .invitation)
        seed(profile(profileName2, uri: uri), accountId: accountId1, source: .jamsSearch)

        service.peerDiscarded(uri: uri, accountId: accountId1)

        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .invitation))
        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .jamsSearch))
    }

    func testRemovedConversationRemovesEveryManagedProfile() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .invitation)
        seed(profile(profileName2, uri: uri), accountId: accountId1, source: .jamsSearch)
        seed(profile("My name for them", uri: uri), accountId: accountId1, source: .localOverride)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .contact)

        service.conversationDeleted(uri: uri, accountId: accountId1)

        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .invitation))
        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .jamsSearch))
        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .localOverride))
        XCTAssertNotNil(stored(uri: uri, accountId: accountId1, source: .contact),
                        "the peer's own vCard belongs to libjami and must survive")
    }

    func testRemovedContactRemovesStoredPeerProfiles() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .invitation)

        service.peerDiscarded(uri: jamiId1, accountId: accountId1)

        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .invitation))
    }

    func testAllContactsRemovedClearsManagedProfilesForTheAccount() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .invitation)
        seed(profile(profileName2, uri: uri), accountId: accountId2, source: .invitation)

        service.accountContactsCleared(accountId: accountId1)

        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .invitation))
        XCTAssertNotNil(stored(uri: uri, accountId: accountId2, source: .invitation),
                        "another account's profiles must be untouched")
    }

    func testSentRequestStoresTheJamsSearchProfile() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let sentProfile = profile(profileName1, uri: uri)

        service.invitationSent(sentProfile, accountId: accountId1)

        XCTAssertEqual(stored(uri: uri, accountId: accountId1, source: .jamsSearch)?.alias, profileName1)
    }

    func testProfileReceivedRemovesStoredPeerProfiles() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        seed(profile(profileName1, uri: uri), accountId: accountId1, source: .invitation)
        seed(profile(profileName2, uri: uri), accountId: accountId1, source: .jamsSearch)

        service.profileReceived(contact: jamiId1, withAccountId: accountId1, path: "")

        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .invitation))
        XCTAssertNil(stored(uri: uri, accountId: accountId1, source: .jamsSearch))
    }
}

final class RequestsServiceEventTests: XCTestCase {

    private var bag: DisposeBag!

    override func setUpWithError() throws {
        try super.setUpWithError()
        bag = DisposeBag()
    }

    override func tearDownWithError() throws {
        bag = nil
        try super.tearDownWithError()
    }

    private func postConversationReady(_ conversationId: String) {
        NotificationCenter.default.post(name: NSNotification.Name(ConversationNotifications.conversationReady.rawValue),
                                        object: nil,
                                        userInfo: [ConversationNotificationsKeys.conversationId.rawValue: conversationId,
                                                   ConversationNotificationsKeys.accountId.rawValue: accountId1])
    }

    func testConversationReadyAnnouncesTheAcceptedRequestWithThePeerProfile() throws {
        let conversationId = "accepted-conversation"
        let avatar = Data("request-photo".utf8)
        let payload = try XCTUnwrap(VCardUtils.dataWithImageAndUUID(from:
                                                                        Profile(uri: "jami:\(jamiId1)",
                                                                                alias: profileName1,
                                                                                photo: avatar.base64EncodedString(),
                                                                                type: ProfileType.ring.rawValue)))
        let service = RequestsService(withRequestsAdapter: RequestsAdapter())
        var accepted = [ServiceEvent]()
        service.sharedResponseStream
            .filter { $0.eventType == ServiceEventType.contactRequestAccepted }
            .subscribe(onNext: { accepted.append($0) })
            .disposed(by: bag)
        let request = RequestModel(with: jamiId1,
                                   accountId: accountId1,
                                   withPayload: payload,
                                   receivedDate: Date(),
                                   type: .contact,
                                   conversationId: conversationId)
        service.requests.accept([request])

        postConversationReady(conversationId)

        XCTAssertTrue(service.requests.value.isEmpty)
        let event = try XCTUnwrap(accepted.first)
        let uri: String? = event.getEventInput(.peerUri)
        let profile: Profile? = event.getEventInput(.profile)
        XCTAssertEqual(uri, JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        XCTAssertEqual(profile?.alias, profileName1)
        XCTAssertEqual(profile?.photo, avatar.base64EncodedString())
    }

    func testSentContactRequestAnnouncesOnlyTheSelectedPeerProfile() throws {
        let uri = try XCTUnwrap(JamiURI(schema: .ring, infoHash: jamiId1).uriString)
        let selectedProfile = Profile(uri: uri,
                                      alias: profileName1,
                                      photo: Data("directory-photo".utf8).base64EncodedString(),
                                      type: ProfileType.ring.rawValue)
        let service = RequestsService(withRequestsAdapter: RequestsAdapter())
        var sentEvent: ServiceEvent?
        service.sharedResponseStream
            .filter { $0.eventType == .contactRequestSent }
            .subscribe(onNext: { sentEvent = $0 })
            .disposed(by: bag)

        service.sendContactRequest(to: jamiId1,
                                   withAccountId: accountId1,
                                   payload: nil,
                                   peerProfile: selectedProfile)
            .subscribe()
            .disposed(by: bag)

        let profile: Profile? = sentEvent?.getEventInput(.profile)
        XCTAssertEqual(profile?.uri, uri)
        XCTAssertEqual(profile?.alias, profileName1)
        XCTAssertEqual(profile?.photo, selectedProfile.photo)
    }

    func testGroupConversationMetadataIsNeverAnnouncedAsAPeerProfile() {
        let conversationId = "group-conversation"
        let service = RequestsService(withRequestsAdapter: RequestsAdapter())
        var events = [ServiceEvent]()
        service.sharedResponseStream
            .subscribe(onNext: { events.append($0) })
            .disposed(by: bag)
        service.conversationRequestReceived(
            conversationId: conversationId,
            accountId: accountId1,
            metadata: [ConversationAttributes.conversationId.rawValue: conversationId,
                       RequestModel.RequestKey.from.rawValue: jamiId1,
                       ConversationAttributes.mode.rawValue: String(ConversationType.invitesOnly.rawValue),
                       ConversationAttributes.title.rawValue: "Group title",
                       ConversationAttributes.avatar.rawValue: Data("group-photo".utf8).base64EncodedString()])

        postConversationReady(conversationId)

        let profiles = events.compactMap { $0.getEventInput(.profile) as Profile? }
        XCTAssertTrue(profiles.isEmpty)
    }
}

final class ProfileMergingTests: XCTestCase {

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
