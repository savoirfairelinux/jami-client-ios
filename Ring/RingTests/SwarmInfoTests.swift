/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

@testable import Ring
import XCTest

final class SwarmInfoTests: XCTestCase {
    var injectionBag: InjectionBag!
    var swarmInfo: SwarmInfo!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dBManager = DBManager(profileHepler: ProfileDataHelper(),
                                  conversationHelper: ConversationDataHelper(),
                                  interactionHepler: InteractionDataHelper(),
                                  dbConnections: DBContainer())
        let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
        let nameService = NameService(withNameRegistrationAdapter: NameRegistrationAdapter())
        let presenceService = PresenceService(withPresenceAdapter: PresenceAdapter())
        let videoService = VideoService(withVideoAdapter: VideoAdapter())
        let audioService = AudioService(withAudioAdapter: AudioAdapter())
        let systemService = SystemService(withSystemAdapter: SystemAdapter())
        let networkService = NetworkService()
        let callsProvider = CallsProviderService(
            provider: CXProvider(configuration: CallsHelpers.providerConfiguration()),
            controller: CXCallController()
        )
        let callService = CallsService(withCallsAdapter: CallsAdapter(), dbManager: dBManager)
        let accountService = AccountsService(
            withAccountAdapter: AccountAdapter(),
            dbManager: dBManager
        )
        let contactsService = ContactsService(
            withContactsAdapter: ContactsAdapter(),
            dbManager: dBManager
        )
        let profileService =
            ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: dBManager)
        let dataTransferService =
            DataTransferService(withDataTransferAdapter: DataTransferAdapter(),
                                dbManager: dBManager)
        let conversationsService =
            ConversationsService(
                withConversationsAdapter: ConversationsAdapter(),
                dbManager: dBManager
            )
        let locationSharingService =
            LocationSharingService(dbManager: dBManager)
        let requestsService =
            RequestsService(withRequestsAdapter: RequestsAdapter(), dbManager: dBManager)

        injectionBag = InjectionBag(withDaemonService: daemonService,
                                    withAccountService: accountService,
                                    withNameService: nameService,
                                    withConversationService: conversationsService,
                                    withContactsService: contactsService,
                                    withPresenceService: presenceService,
                                    withNetworkService: networkService,
                                    withCallService: callService,
                                    withVideoService: videoService,
                                    withAudioService: audioService,
                                    withDataTransferService: dataTransferService,
                                    withProfileService: profileService,
                                    withCallsProvider: callsProvider,
                                    withLocationSharingService: locationSharingService,
                                    withRequestsService: requestsService,
                                    withSystemService: systemService)
        swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: "")
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        injectionBag = nil
        swarmInfo = nil
    }

    func createParticipant(jamiId: String, role: ParticipantRole, registeredName: String,
                           profileName: String) -> ParticipantInfo {
        let participant = ParticipantInfo(jamiId: jamiId, role: role)
        participant.registeredName.accept(registeredName)
        participant.profileName.accept(profileName)
        return participant
    }

    func testHasParticipantWithRegisteredName_True() {
        // Arrange
        let participant = createParticipant(
            jamiId: jamiId1,
            role: .admin,
            registeredName: registeredName1,
            profileName: ""
        )
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.hasParticipantWithRegisteredName(name: registeredName1)
        // Assert
        XCTAssertTrue(result)
    }

    func testHasParticipantWithRegisteredName_False() {
        // Arrange
        let participant = createParticipant(
            jamiId: jamiId1,
            role: .admin,
            registeredName: registeredName1,
            profileName: ""
        )
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.hasParticipantWithRegisteredName(name: registeredName2)
        // Assert
        XCTAssertFalse(result)
    }

    func testContainsSearchQuery_QuerIsRegisteredName_True() {
        // Arrange
        let participant = createParticipant(
            jamiId: jamiId1,
            role: .admin,
            registeredName: registeredName1,
            profileName: ""
        )
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.contains(searchQuery: registeredName1)
        // Assert
        XCTAssertTrue(result)
    }

    func testContainsSearchQuery_QueryIsProfileName_True() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: "",
                                            profileName: profileName1)
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.contains(searchQuery: profileName1)
        // Assert
        XCTAssertTrue(result)
    }

    func testContainsSearchQuery_QueryIsJamiId_True() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: "",
                                            profileName: "")
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.contains(searchQuery: jamiId1)
        // Assert
        XCTAssertTrue(result)
    }

    func testContainsSearchQuery_QueryIsTitle_True() {
        // Arrange
        swarmInfo.title.accept(title1)
        // Act
        let result = swarmInfo.contains(searchQuery: title1)
        // Assert
        XCTAssertTrue(result)
    }

    func testContainsSearchQuery_False() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: "",
                                            profileName: "")
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.contains(searchQuery: "test")
        // Assert
        XCTAssertFalse(result)
    }
}
