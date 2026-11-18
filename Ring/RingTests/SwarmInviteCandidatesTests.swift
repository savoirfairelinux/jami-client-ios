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
import RxRelay
@testable import Ring

final class SwarmInviteCandidatesTests: XCTestCase {

    var injectionBag: InjectionBag!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dBManager = DBManager(conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        injectionBag = InjectionBag(
            withDaemonService: DaemonService(dRingAdaptor: DRingAdapter()),
            withAccountService: AccountsService(withAccountAdapter: AccountAdapter(), dbManager: dBManager),
            withNameService: NameService(withNameRegistrationAdapter: NameRegistrationAdapter()),
            withConversationService: ConversationsService(withConversationsAdapter: ConversationsAdapter(),
                                                          dbManager: dBManager),
            withContactsService: ContactsService(withContactsAdapter: ContactsAdapter(), dbManager: dBManager),
            withPresenceService: PresenceService(withPresenceAdapter: PresenceAdapter()),
            withNetworkService: NetworkService(),
            withCallService: CallService(),
            withVideoService: VideoService(),
            withAudioService: AudioService(),
            withDataTransferService: DataTransferService(withDataTransferAdapter: DataTransferAdapter()),
            withProfileService: ProfilesService(withProfilesAdapter: ProfilesAdapter()),
            withLocationSharingService: LocationSharingService(),
            withRequestsService: RequestsService(withRequestsAdapter: RequestsAdapter()),
            withSystemService: SystemService(withSystemAdapter: SystemAdapter()),
            withPeerSharingService: TestPeerSharingFactory.createService(),
            withCollaborationService: CollaborationService(withCollaborationAdapter: ObjCMockCollaborationAdapter()))
    }

    override func tearDownWithError() throws {
        injectionBag = nil
        try super.tearDownWithError()
    }

    private func contact(_ jamiId: String) -> ContactModel {
        return ContactModel(withDictionary: ["id": jamiId])
    }

    private func candidateIds(members: [ParticipantInfo] = []) -> [String] {
        let candidates = SwarmInviteCandidates(injectionBag: injectionBag, accountId: accountId1,
                                               members: .just(members))
        return candidates.candidates.value.map(\.jamiId)
    }

    func testOnlyContactRequestsHideCandidates() {
        let groupInvite = RequestModel(withDictionary: [
            "from": jamiId2,
            "mode": String(ConversationType.invitesOnly.rawValue)
        ], accountId: accountId1, type: .conversation)
        let contactRequest = RequestModel(withDictionary: ["from": jamiId3],
                                          accountId: accountId1, type: .contact)
        injectionBag.requestsService.requests.accept([groupInvite, contactRequest])
        injectionBag.contactsService.contacts.accept([contact(jamiId2), contact(jamiId3)])

        XCTAssertEqual(candidateIds(), [jamiId2])
    }
}
