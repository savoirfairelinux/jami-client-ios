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
import RxSwift
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

    func testCallTargetForGroupConversationUsesResolvedURIWithoutDisplayName() {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .invitesOnly)
        conversation.addParticipant(jamiId: jamiId1)
        let viewModel = makeSwarmInfoViewModel(conversation: conversation, title: title1)

        let target = viewModel.callTarget

        XCTAssertEqual(target?.uri, "swarm:\(conversationId1)")
        XCTAssertEqual(target?.displayName, "")
    }

    func testSwarmProfileActionsPlaceEditAfterCallActions() {
        XCTAssertEqual(SwarmProfileAction.available(canCall: true, canEdit: true),
                       [.audioCall, .videoCall, .editProfile])
    }

    func testSwarmProfileActionsHideEditWithoutPermission() {
        XCTAssertEqual(SwarmProfileAction.available(canCall: true, canEdit: false),
                       [.audioCall, .videoCall])
    }

    func testEditProfileActionUsesStandardEditSymbol() {
        XCTAssertEqual(SwarmProfileAction.editProfile.systemImage, "square.and.pencil")
    }

    func testProfileEditingIsAvailableForOneToOneContact() {
        XCTAssertTrue(SwarmInfoVM.profileEditingAllowed(isCoreDialog: true,
                                                        hasRemoteParticipant: true,
                                                        isAdmin: false))
    }

    func testProfileEditingIsUnavailableForConversationWithYourself() {
        XCTAssertFalse(SwarmInfoVM.profileEditingAllowed(isCoreDialog: true,
                                                         hasRemoteParticipant: false,
                                                         isAdmin: false))
    }

    func testProfileEditingIsAvailableForSwarmAdmin() {
        XCTAssertTrue(SwarmInfoVM.profileEditingAllowed(isCoreDialog: false,
                                                        hasRemoteParticipant: true,
                                                        isAdmin: true))
    }

    func testProfileEditingIsUnavailableForSwarmMember() {
        XCTAssertFalse(SwarmInfoVM.profileEditingAllowed(isCoreDialog: false,
                                                         hasRemoteParticipant: true,
                                                         isAdmin: false))
    }

    func testOneToOneProfileEditorUsesLocalContactContext() {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .oneToOne)
        conversation.addParticipant(jamiId: jamiId1)
        let viewModel = makeSwarmInfoViewModel(conversation: conversation, title: title1)

        guard let context = viewModel.profileEditingContext,
              case .contact(let editingConversation) = context else {
            return XCTFail("Expected local contact profile editing")
        }
        XCTAssertTrue(editingConversation === conversation)
    }

    func testContactProfileActionsPlaceEditAfterCallActions() {
        let actions = ContactActions.make(isJamiAccount: true,
                                          isKnownContact: true,
                                          canEditProfile: true)

        XCTAssertEqual(actions.map(\.kind),
                       [.audioCall, .videoCall, .editProfile, .sendMessage,
                        .leaveConversation, .blockContact])
    }

    func testContactProfileActionsHideEditWhenEditingIsUnavailable() {
        let actions = ContactActions.make(isJamiAccount: true,
                                          isKnownContact: false,
                                          canEditProfile: false)

        XCTAssertEqual(actions.map(\.kind), [.audioCall, .videoCall, .sendMessage])
    }

    func testEditActionLabelStandsAloneWithoutTheHint() {
        XCTAssertEqual(SwarmProfileAction.editProfile.accessibilityLabel(for: title1, isGroup: true),
                       L10n.ProfileEditor.editGroup)
        XCTAssertEqual(SwarmProfileAction.editProfile.accessibilityLabel(for: title1, isGroup: false),
                       L10n.ProfileEditor.editContact)
    }

    func testEditActionHintDistinguishesGroupFromContact() {
        XCTAssertEqual(SwarmProfileAction.editProfile.accessibilityHint(isGroup: true),
                       L10n.ProfileEditor.editGroupHint)
        XCTAssertEqual(SwarmProfileAction.editProfile.accessibilityHint(isGroup: false),
                       L10n.ProfileEditor.editContactHint)
    }

    func testCallActionsHaveNoAccessibilityHint() {
        XCTAssertTrue(SwarmProfileAction.audioCall.accessibilityHint(isGroup: true).isEmpty)
        XCTAssertTrue(SwarmProfileAction.videoCall.accessibilityHint(isGroup: false).isEmpty)
    }

    func testWhitespaceOnlyTitleFallsBackToParticipantNames() {
        let swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId1)
        swarmInfo.participantsNames.accept(["Alice"])
        swarmInfo.title.accept("")
        let derivedTitle = swarmInfo.finalTitle.value

        swarmInfo.title.accept("   ")

        XCTAssertEqual(swarmInfo.finalTitle.value, derivedTitle)
    }

    func testSurroundingWhitespaceIsStrippedFromTitle() {
        let swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId1)

        swarmInfo.title.accept("  Team  ")

        XCTAssertEqual(swarmInfo.finalTitle.value, "Team")
    }

    func testSurroundingWhitespaceIsNotAProfileChange() {
        let swarmInfo = TestableSwarmInfo(participants: [],
                                          containsSearchQuery: false,
                                          hasParticipantWithRegisteredName: false)
        swarmInfo.title.accept("Team")
        swarmInfo.description.accept("Weekly sync")
        let model = ConversationProfileEditorVM(context: .swarm(swarmInfo), injectionBag: injectionBag)

        model.name = " Team "
        model.description = "Weekly sync  "

        XCTAssertFalse(model.hasChanges)
    }

    func testEmptyConversationAvatarDoesNotMaskParticipantAvatar() {
        let swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId1)
        let bag = DisposeBag()
        var emissions = [Data?]()
        swarmInfo.finalAvatarData
            .subscribe(onNext: { emissions.append($0) })
            .disposed(by: bag)

        swarmInfo.avatarData.accept(Data())

        XCTAssertNil(emissions.last ?? nil)
    }

    func testConversationAvatarIsUsedWhenItHasContent() {
        let swarmInfo = SwarmInfo(injectionBag: injectionBag, accountId: accountId1)
        let avatar = Data([0x01, 0x02, 0x03])
        let bag = DisposeBag()
        var emissions = [Data?]()
        swarmInfo.finalAvatarData
            .subscribe(onNext: { emissions.append($0) })
            .disposed(by: bag)

        swarmInfo.avatarData.accept(avatar)

        XCTAssertEqual(emissions.last ?? nil, avatar)
    }

    func testSavingTrimsSurroundingWhitespace() {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .oneToOne)
        let swarmInfo = TestableSwarmInfo(participants: [],
                                          containsSearchQuery: false,
                                          hasParticipantWithRegisteredName: false)
        swarmInfo.conversation = conversation
        let model = ConversationProfileEditorVM(context: .swarm(swarmInfo), injectionBag: injectionBag)

        model.name = "  Team  "
        model.description = "  Weekly sync  "
        model.save()

        XCTAssertEqual(swarmInfo.title.value, "Team")
        XCTAssertEqual(swarmInfo.description.value, "Weekly sync")
    }

    func testCoreDialogResolvesTitleFromParticipantNotFromInfos() {
        let conversation = ConversationModel(withId: conversationId1,
                                             accountId: accountId1,
                                             type: .oneToOne)
        conversation.addParticipant(jamiId: jamiId1)
        let swarmInfo = SwarmInfo(injectionBag: injectionBag, conversation: conversation)

        XCTAssertTrue(swarmInfo.title.value.isEmpty)
        XCTAssertFalse(swarmInfo.finalTitle.value.isEmpty)
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
