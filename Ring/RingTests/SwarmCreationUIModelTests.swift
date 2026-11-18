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

final class SwarmCreationUIModelTests: XCTestCase {

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

    func testContactUpdateKeepsSearchAndDropsSelectionOfRemovedContact() {
        let contacts = injectionBag.contactsService.contacts
        contacts.accept([contact(jamiId2), contact(jamiId3)])
        let search = BehaviorRelay(value: "")
        let model = SwarmCreationUIModel(with: injectionBag, accountId: accountId1,
                                         strSearchText: search, swarmCreated: { _, _ in })
        waitUntil { model.participantsRows.count == 2 }
        model.selections = [jamiId2, jamiId3]
        search.accept(jamiId4)

        contacts.accept([contact(jamiId3), contact(jamiId4)])
        waitUntil { model.selections == [jamiId3] }

        XCTAssertEqual(model.participantsRows.map(\.id), [jamiId4])
        XCTAssertEqual(model.selections, [jamiId3])
        XCTAssertNotNil(model.getParticipant(id: jamiId3),
                        "a selected member keeps its chip while the search hides its row")
    }

    func testSearchMatchesRegisteredNameBehindProfileName() {
        let info = ParticipantInfo(jamiId: jamiId2, role: .unknown,
                                   profileService: injectionBag.profileService)
        info.profileName.accept("Bob")
        info.registeredName.accept("alice")

        let row = ParticipantRow(participantData: info)

        XCTAssertTrue(row.match(string: "ALI"))
    }
}
