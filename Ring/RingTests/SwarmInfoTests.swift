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

import XCTest
@testable import Ring

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
        let videoService = VideoService()
        let audioService = AudioService()
        let callService = CallService()
        let systemService = SystemService(withSystemAdapter: SystemAdapter())
        let networkService = NetworkService()
        let accountService: AccountsService = AccountsService(withAccountAdapter: AccountAdapter(), dbManager: dBManager)
        let contactsService: ContactsService = ContactsService(withContactsAdapter: ContactsAdapter(), dbManager: dBManager)
        let profileService: ProfilesService =
            ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: dBManager)
        let dataTransferService: DataTransferService =
            DataTransferService(withDataTransferAdapter: DataTransferAdapter(),
                                dbManager: dBManager)
        let conversationsService: ConversationsService =
            ConversationsService(withConversationsAdapter: ConversationsAdapter(), dbManager: dBManager)
        let locationSharingService: LocationSharingService =
            LocationSharingService(dbManager: dBManager)
        let requestsService: RequestsService =
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
                                    withLocationSharingService: locationSharingService,
                                    withRequestsService: requestsService,
                                    withSystemService: systemService,
                                    withPeerSharingService: TestPeerSharingFactory.createService(),
                                    withCollaborationService: CollaborationService(withCollaborationAdapter: ObjCMockCollaborationAdapter()))
        swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: "")
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        injectionBag = nil
        swarmInfo = nil
    }

    func createParticipant(jamiId: String, role: ParticipantRole, registeredName: String,
                           profileName: String) -> ParticipantInfo {
        let participant = ParticipantInfo(jamiId: jamiId, role: role, profileService: injectionBag.profileService)
        participant.registeredName.accept(registeredName)
        participant.profileName.accept(profileName)
        return participant
    }

    func testParticipantsString_ExcludesInactiveParticipantsFromGeneratedTitle() {
        // Arrange
        let activeAdmin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: "",
                                            profileName: "Eli")
        let activeMember = createParticipant(jamiId: jamiId2, role: .member, registeredName: "",
                                             profileName: "Dana")
        let activeInvited = createParticipant(jamiId: jamiId3, role: .invited, registeredName: "",
                                              profileName: "Mariah")
        let activeOverflow = createParticipant(jamiId: jamiId4, role: .member, registeredName: "",
                                               profileName: "Christine")
        let inactiveBanned = createParticipant(jamiId: "inactiveBanned", role: .banned, registeredName: "",
                                               profileName: "Al")
        let inactiveLeft = createParticipant(jamiId: "inactiveLeft", role: .left, registeredName: "",
                                             profileName: "Bo")

        // Act
        swarmInfo.participants.accept([activeAdmin, activeMember, activeInvited, activeOverflow,
                                       inactiveBanned, inactiveLeft])

        // Assert
        XCTAssertEqual(swarmInfo.participantsString.value, "Eli, Dana, Mariah, + 1")
        XCTAssertEqual(Set(swarmInfo.participantsNames.value), Set(["Eli", "Dana", "Mariah", "Christine"]))
        XCTAssertFalse(swarmInfo.participantsString.value.contains("Al"))
        XCTAssertFalse(swarmInfo.participantsString.value.contains("Bo"))
    }

    func testHasParticipantWithRegisteredName_True() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                            profileName: "")
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.hasParticipantWithRegisteredName(name: registeredName1)
        // Assert
        XCTAssertTrue(result)
    }

    func testHasParticipantWithRegisteredName_False() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                            profileName: "")
        swarmInfo.participants.accept([participant])
        // Act
        let result = swarmInfo.hasParticipantWithRegisteredName(name: registeredName2)
        // Assert
        XCTAssertFalse(result)
    }

    func testContainsSearchQuery_QuerIsRegisteredName_True() {
        // Arrange
        let participant = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                            profileName: "")
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

    func testCallTargetForOneToOneConversationUsesParticipant() {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .oneToOne)
        conversation.addParticipant(jamiId: jamiId1)
        let viewModel = makeSwarmInfoViewModel(conversation: conversation, title: profileName1)

        let target = viewModel.callTarget

        XCTAssertEqual(target?.uri, jamiId1)
        XCTAssertEqual(target?.displayName, profileName1)
    }

    func testCallTargetForGroupConversationUsesSwarmURI() {
        let conversation = makeGroupConversation()
        let viewModel = makeSwarmInfoViewModel(conversation: conversation, title: title1)

        let target = viewModel.callTarget

        XCTAssertEqual(target?.uri, "swarm:\(conversationId1)")
        XCTAssertEqual(target?.displayName, "")
    }

    func testCallTargetForGroupConversationUsesActiveCallURI() {
        let conversation = makeGroupConversation()
        let activeCall = ActiveCall(id: "call-id",
                                    uri: jamiId1,
                                    device: "device-id",
                                    conversationId: conversationId1,
                                    accountId: accountId1,
                                    isFromLocalDevice: false)
        var tracker = AccountCallTracker()
        tracker.setCalls(for: conversationId1, to: [activeCall])
        injectionBag.callService.activeCalls.accept([accountId1: tracker])
        let viewModel = makeSwarmInfoViewModel(conversation: conversation, title: title1)

        let target = viewModel.callTarget

        XCTAssertEqual(target?.uri, activeCall.constructURI())
        XCTAssertEqual(target?.displayName, "")
    }

    func testCallTargetIsNilWithoutConversation() {
        let testableSwarmInfo = TestableSwarmInfo(participants: [],
                                                  containsSearchQuery: false,
                                                  hasParticipantWithRegisteredName: false)
        let viewModel = SwarmInfoVM(with: injectionBag, swarmInfo: testableSwarmInfo)

        XCTAssertNil(viewModel.callTarget)
    }

    private func makeGroupConversation() -> ConversationModel {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .invitesOnly)
        conversation.addParticipant(jamiId: jamiId1)
        conversation.addParticipant(jamiId: jamiId2)
        conversation.addParticipant(jamiId: jamiId3)
        return conversation
    }

    private func makeSwarmInfoViewModel(conversation: ConversationModel,
                                        title: String) -> SwarmInfoVM {
        let testableSwarmInfo = TestableSwarmInfo(participants: [],
                                                  containsSearchQuery: false,
                                                  hasParticipantWithRegisteredName: false)
        testableSwarmInfo.conversation = conversation
        let viewModel = SwarmInfoVM(with: injectionBag, swarmInfo: testableSwarmInfo)
        viewModel.title = title
        return viewModel
    }
}
