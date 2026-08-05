/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
import Combine
@testable import Ring

@MainActor
final class CallParticipantAvatarsTests: XCTestCase {

    private let peerHash = jamiId1
    private var cancellables = Set<AnyCancellable>()

    func testBareHashGetsCanonicalProfileKey() {
        let key = CallParticipantAvatars.participantKey(for: peerHash)
        XCTAssertEqual(key.profileUri, "jami:" + peerHash)
        XCTAssertEqual(key.hash, peerHash)
    }

    func testSchemeAndHostAreStripped() {
        let key = CallParticipantAvatars.participantKey(for: "jami:\(peerHash)@ring.dht")
        XCTAssertEqual(key.profileUri, "jami:" + peerHash)
        XCTAssertEqual(key.hash, peerHash)
    }

    func testSipPeerKeepsItsSipUri() {
        let key = CallParticipantAvatars.participantKey(for: "sip:1001@10.0.0.1")
        XCTAssertEqual(key.profileUri, "sip:1001@10.0.0.1")
        XCTAssertEqual(key.hash, "1001")
    }

    func testRegisteredNameArrivingAfterProviderResolvesName() {
        let database = DBManager(profileHepler: ProfileDataHelper(),
                                 conversationHelper: ConversationDataHelper(),
                                 interactionHepler: InteractionDataHelper(),
                                 dbConnections: DBContainer())
        let profileService = ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                             dbManager: database)
        let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
        let avatars = CallParticipantAvatars(accountId: accountId1,
                                             profileService: profileService,
                                             nameService: nameService,
                                             localJamiId: jamiId2)

        let provider = avatars.provider(forUri: peerHash)

        let resolved = expectation(description: "name resolves to the registered name")
        provider.$profileName
            .filter { $0 == "alice42" }
            .sink { _ in resolved.fulfill() }
            .store(in: &cancellables)

        let response = LookupNameResponse()
        response.state = .found
        response.address = peerHash
        response.name = "alice42"
        response.requestedName = ""
        nameService.usernameLookupStatus.onNext(response)

        wait(for: [resolved], timeout: 2)
    }

}
