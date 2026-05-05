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
import Combine
import RxSwift
import RxRelay
@testable import Ring

final class AvatarProviderTests: XCTestCase {

    var injectionBag: InjectionBag!

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
        let callsProvider: CallsProviderService = CallsProviderService(provider: CXProvider(configuration: CallsHelpers.providerConfiguration()), controller: CXCallController())
        let callService: CallsService = CallsService(withCallsAdapter: CallsAdapter())
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
                                    withCallsProvider: callsProvider,
                                    withLocationSharingService: locationSharingService,
                                    withRequestsService: requestsService,
                                    withSystemService: systemService)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        injectionBag = nil
    }

    // MARK: - Helpers

    func createParticipant(jamiId: String, role: ParticipantRole, registeredName: String,
                           profileName: String) -> ParticipantInfo {
        let participant = ParticipantInfo(jamiId: jamiId, role: role, profileService: injectionBag.profileService)
        participant.registeredName.accept(registeredName)
        participant.profileName.accept(profileName)
        return participant
    }

    func createGroupProvider(swarmInfo: TestableSwarmInfo) -> AvatarProvider {
        return AvatarProvider.from(swarmInfo: swarmInfo, profileService: injectionBag.profileService, size: .default55)
    }

    func setParticipants(_ participants: [ParticipantInfo], on swarmInfo: TestableSwarmInfo) {
        swarmInfo.participants.accept(participants)
        swarmInfo.participantsAvatars.accept(participants.compactMap { $0.avatarData.value })
    }

    func waitForMainScheduler() {
        let expectation = expectation(description: "wait for main queue delivery")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
    }

    func createTestImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        return renderer.pngData { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    // MARK: - Display Participant Selection

    func testDisplayParticipants_AdminFirst() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member1 = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                        profileName: profileName2)
        let member2 = createParticipant(jamiId: jamiId3, role: .member, registeredName: "",
                                        profileName: profileName3)
        // Act
        setParticipants([member1, admin, member2], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertEqual(provider.displayParticipants.count, 3)
        XCTAssertEqual(provider.displayParticipants[0].jamiId, jamiId1)
        XCTAssertEqual(provider.overflowCount, 0)
    }

    func testDisplayParticipants_OverflowWith4() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member1 = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                        profileName: profileName2)
        let member2 = createParticipant(jamiId: jamiId3, role: .member, registeredName: "",
                                        profileName: profileName3)
        let member3 = createParticipant(jamiId: jamiId4, role: .member, registeredName: "",
                                        profileName: profileName4)
        // Act
        setParticipants([admin, member1, member2, member3], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertEqual(provider.displayParticipants.count, 2)
        XCTAssertEqual(provider.overflowCount, 2)
        XCTAssertEqual(provider.displayParticipants[0].jamiId, jamiId1)
    }

    func testDisplayParticipants_ExcludesBannedAndLeft() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        let banned = createParticipant(jamiId: jamiId3, role: .banned, registeredName: "",
                                       profileName: profileName3)
        let left = createParticipant(jamiId: jamiId4, role: .left, registeredName: "",
                                     profileName: profileName4)
        // Act
        setParticipants([admin, member, banned, left], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        let displayedIds = Set(provider.displayParticipants.map { $0.jamiId })
        XCTAssertTrue(displayedIds.contains(jamiId1))
        XCTAssertTrue(displayedIds.contains(jamiId2))
        XCTAssertFalse(displayedIds.contains(jamiId3))
        XCTAssertFalse(displayedIds.contains(jamiId4))
        XCTAssertEqual(provider.overflowCount, 0)
    }

    // MARK: - Snapshot Lifecycle

    func testSnapshotCreated_AfterParticipantsSet() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        // Act
        setParticipants([admin, member], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertNotNil(provider.groupAvatarSnapshot)
        let expectedSize = Constants.AvatarSize.default55.points
        XCTAssertEqual(provider.groupAvatarSnapshot?.size.width, expectedSize)
        XCTAssertEqual(provider.groupAvatarSnapshot?.size.height, expectedSize)
    }

    func testGuardSkipsRedundantUpdate() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        setParticipants([admin, member], on: swarmInfo)
        waitForMainScheduler()
        let firstSnapshot = provider.groupAvatarSnapshot
        XCTAssertNotNil(firstSnapshot)
        let participantsBefore = provider.displayParticipants.map { $0.jamiId }
        let overflowBefore = provider.overflowCount
        // Act — fire participantsAvatars without changing participants
        swarmInfo.participantsAvatars.accept([])
        waitForMainScheduler()
        // Assert — guard blocked because visible IDs and overflow unchanged
        XCTAssertEqual(provider.displayParticipants.map { $0.jamiId }, participantsBefore)
        XCTAssertEqual(provider.overflowCount, overflowBefore)
        XCTAssertTrue(provider.groupAvatarSnapshot === firstSnapshot)
    }

    // MARK: - Reactive Updates

    func testSnapshotUpdates_OnNameChange() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        setParticipants([admin, member], on: swarmInfo)
        waitForMainScheduler()
        let initialSnapshot = provider.groupAvatarSnapshot
        XCTAssertNotNil(initialSnapshot)

        let snapshotChanged = expectation(description: "snapshot updated after name change")
        var cancellable: AnyCancellable?
        cancellable = provider.$groupAvatarSnapshot
            .dropFirst()
            .sink { newSnapshot in
                if newSnapshot !== initialSnapshot {
                    snapshotChanged.fulfill()
                    cancellable?.cancel()
                }
            }
        // Act — drive through the production derivation chain
        member.profileName.accept(profileName3)
        // Assert
        wait(for: [snapshotChanged], timeout: 1)
    }

    func testSnapshotUpdates_OnAvatarDataChange() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        setParticipants([admin, member], on: swarmInfo)
        waitForMainScheduler()
        let initialSnapshot = provider.groupAvatarSnapshot
        XCTAssertNotNil(initialSnapshot)

        let snapshotChanged = expectation(description: "snapshot updated after avatar data change")
        var cancellable: AnyCancellable?
        cancellable = provider.$groupAvatarSnapshot
            .dropFirst()
            .sink { newSnapshot in
                if newSnapshot !== initialSnapshot {
                    snapshotChanged.fulfill()
                    cancellable?.cancel()
                }
            }
        // Act
        member.avatarData.accept(createTestImageData())
        // Assert
        wait(for: [snapshotChanged], timeout: 1)
    }

    func testSnapshotUpdates_WhenParticipantJoins() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        setParticipants([admin, member], on: swarmInfo)
        waitForMainScheduler()
        XCTAssertEqual(provider.displayParticipants.count, 2)
        let initialSnapshot = provider.groupAvatarSnapshot
        XCTAssertNotNil(initialSnapshot)
        // Act — new member joins
        let newMember = createParticipant(jamiId: jamiId3, role: .member, registeredName: "",
                                          profileName: profileName3)
        setParticipants([admin, member, newMember], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertEqual(provider.displayParticipants.count, 3)
        XCTAssertFalse(provider.groupAvatarSnapshot === initialSnapshot)
    }

    func testSnapshotUpdates_WhenParticipantLeaves() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member1 = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                        profileName: profileName2)
        let member2 = createParticipant(jamiId: jamiId3, role: .member, registeredName: "",
                                        profileName: profileName3)
        setParticipants([admin, member1, member2], on: swarmInfo)
        waitForMainScheduler()
        XCTAssertEqual(provider.displayParticipants.count, 3)
        let initialSnapshot = provider.groupAvatarSnapshot
        XCTAssertNotNil(initialSnapshot)
        // Act — member leaves
        setParticipants([admin, member1], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertEqual(provider.displayParticipants.count, 2)
        XCTAssertFalse(provider.groupAvatarSnapshot === initialSnapshot)
    }

    func testDisplayParticipants_PrioritizesAvatarOverName() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let memberWithName = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                               profileName: profileName2)
        let memberWithAvatar = createParticipant(jamiId: jamiId3, role: .member, registeredName: "",
                                                  profileName: profileName3)
        memberWithAvatar.avatarData.accept(createTestImageData())
        let memberNameOnly = createParticipant(jamiId: jamiId4, role: .member, registeredName: "",
                                               profileName: profileName4)
        // Act — 4 participants triggers overflow, only admin + 1 other shown
        setParticipants([admin, memberNameOnly, memberWithAvatar, memberWithName], on: swarmInfo)
        waitForMainScheduler()
        // Assert — memberWithAvatar (priority 2) should be chosen over name-only members (priority 1)
        XCTAssertEqual(provider.displayParticipants.count, 2)
        XCTAssertEqual(provider.displayParticipants[0].jamiId, jamiId1)
        XCTAssertEqual(provider.displayParticipants[1].jamiId, jamiId3)
    }

    func testSnapshotCreated_SingleParticipant() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        // Act
        setParticipants([admin], on: swarmInfo)
        waitForMainScheduler()
        // Assert
        XCTAssertEqual(provider.displayParticipants.count, 1)
        XCTAssertNotNil(provider.groupAvatarSnapshot)
        XCTAssertEqual(provider.overflowCount, 0)
    }

    func testSnapshotShowsAvatar_WhenDataExistsBeforeSubscription() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let admin = createParticipant(jamiId: jamiId1, role: .admin, registeredName: registeredName1,
                                      profileName: profileName1)
        let member = createParticipant(jamiId: jamiId2, role: .member, registeredName: registeredName2,
                                       profileName: profileName2)
        // Set avatar data BEFORE adding participants to the swarm
        member.avatarData.accept(createTestImageData())
        // Act
        setParticipants([admin, member], on: swarmInfo)
        // Assert — wait for avatar decode and snapshot re-render with decoded avatar
        let snapshotWithAvatar = expectation(description: "snapshot rendered with decoded avatar")
        var cancellable: AnyCancellable?
        cancellable = provider.$groupAvatarSnapshot
            .compactMap { $0 }
            .sink { _ in
                if member.provider.avatar != nil {
                    snapshotWithAvatar.fulfill()
                    cancellable?.cancel()
                }
            }
        wait(for: [snapshotWithAvatar], timeout: 1)
    }

    // MARK: - Custom Avatar & Empty Group

    func testHasCustomAvatar_SetWhenSwarmHasAvatarData() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        XCTAssertFalse(provider.hasCustomAvatar)
        // Act
        swarmInfo.avatarData.accept(createTestImageData())
        waitForMainScheduler()
        // Assert
        XCTAssertTrue(provider.hasCustomAvatar)
        // Act — remove custom avatar
        swarmInfo.avatarData.accept(nil)
        waitForMainScheduler()
        // Assert
        XCTAssertFalse(provider.hasCustomAvatar)
    }

    func testSnapshotCreated_WhenAllParticipantsBanned() {
        // Arrange
        let swarmInfo = TestableSwarmInfo(participants: [], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        let provider = createGroupProvider(swarmInfo: swarmInfo)
        let banned1 = createParticipant(jamiId: jamiId1, role: .banned, registeredName: registeredName1,
                                        profileName: profileName1)
        let banned2 = createParticipant(jamiId: jamiId2, role: .banned, registeredName: registeredName2,
                                        profileName: profileName2)
        // Act
        setParticipants([banned1, banned2], on: swarmInfo)
        waitForMainScheduler()
        // Assert — all filtered out, empty group icon rendered
        XCTAssertTrue(provider.displayParticipants.isEmpty)
        XCTAssertEqual(provider.overflowCount, 0)
        XCTAssertNotNil(provider.groupAvatarSnapshot)
    }
}
