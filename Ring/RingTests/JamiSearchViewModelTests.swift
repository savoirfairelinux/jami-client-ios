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
import RxRelay
import RxSwift
@testable import Ring

final class JamiSearchViewModelTests: XCTestCase {

    var conversationVM: ConversationViewModel!
    var injectionBag: InjectionBag!
    var dataSource: TestableFilteredDataSource!
    var searchViewModel: JamiSearchViewModel!

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
                                    withSystemService: systemService,
                                    withPeerSharingService: TestPeerSharingFactory.createService())
        conversationVM = ConversationViewModel(with: injectionBag)
        conversationVM.conversation = ConversationModel(type: .oneToOne)
        dataSource = TestableFilteredDataSource(conversations: [conversationVM], injectionBag: injectionBag)
        searchViewModel = JamiSearchViewModel(with: injectionBag, source: dataSource, searchOnlyExistingConversations: false)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        conversationVM = nil
        injectionBag = nil
        dataSource = nil
        searchViewModel = nil
    }

    func createSwarmConversation(jamiId: String, type: ConversationType) -> ConversationModel {
        let conversation = ConversationModel(withId: "", accountId: "", type: type)
        let participants = [["uri": jamiId]]
        conversation.addParticipantsFromArray(participantsInfo: participants, accountURI: "")
        return conversation
    }

    func createSwarmInfo(jamiId: String, name: String, containsSearchQuery: Bool, hasParticipantWithRegisteredName: Bool) -> TestableSwarmInfo {
        let participant = ParticipantInfo(jamiId: jamiId, role: .admin, profileService: injectionBag.profileService)
        participant.registeredName.accept(name)
        let swarmInfo = TestableSwarmInfo(participants: [participant], containsSearchQuery: containsSearchQuery, hasParticipantWithRegisteredName: hasParticipantWithRegisteredName)
        return swarmInfo
    }

    func createSipAccount() -> AccountModel {
        let account = AccountModel(withAccountId: "sip-account")
        account.details = AccountConfigModel(withDetails: [
            ConfigKey.accountType.rawValue: AccountType.sip.rawValue,
            ConfigKey.accountUsername.rawValue: "user",
            ConfigKey.accountHostname.rawValue: "sip.example.org"
        ])
        return account
    }

    func testConversationExists_ForOneToOneConversation_QueryIsHash_Exists() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        // Act
        let searchQuery = jamiId1
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertTrue(result)

    }

    func testConversationExists_ForOneToOneConversation_QueryIsHash_DoesNotExist() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        // Act
        let searchQuery = jamiId2
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationExists_ForOneToOneConversation_QueryIsRegisteredName_Exists() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: true, hasParticipantWithRegisteredName: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName1
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationExists_PrivateConversation_QueryIsRegisteredName_Exists() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .invitesOnly)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: true, hasParticipantWithRegisteredName: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName1
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationExists_PrivateConversation_QueryIsRegisteredName_DoesNotExist() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .invitesOnly)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName2
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationExists_PrivateConversation_QueryIsHash_DoesNotExist() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .invitesOnly)
        conversationVM.conversation = conversation
        // Act
        let searchQuery = jamiId2
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationExists_PrivateConversation_QueryIsHash_Exists() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .invitesOnly)
        conversationVM.conversation = conversation
        // Act
        let searchQuery = jamiId1
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationExists_ForOneToOneConversation_QueryIsRegisteredName_DoesNotExist() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName2
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationMatch_OneToOneConversation_QueryIsHash_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        // Act
        let searchQuery = jamiId1
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationMatch_OneToOneConversation_QueryIsRegisteredName_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: true, hasParticipantWithRegisteredName: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName1
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationMatch_PrivateConversation_QueryIsRegisteredName_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .invitesOnly)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: true, hasParticipantWithRegisteredName: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName1
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationMatch_SwarmConversation_QueryIsRegisteredName_DoesNotMatch() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM.conversation = conversation
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId1, name: registeredName1, containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName1 + "1"
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationMatch_SipConversation_Match() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHash: sipTestNumber1)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: "", hash: sipTestNumber1, type: .sip)
        conversationVM.conversation = conversation
        conversationVM.userName.accept(sipTestNumber1)
        // Act
        let searchQuery = sipTestNumber1
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result)
    }

    func testConversationMatch_SipConversation_DoesNotMatch() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHash: sipTestNumber1)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: "", hash: sipTestNumber1, type: .sip)
        conversationVM.conversation = conversation
        conversationVM.userName.accept(sipTestNumber1)
        // Act
        let searchQuery = sipTestNumber1 + "1"
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result)
    }

    func testConversationContains_SipConversation_Contains() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHash: sipTestNumber1)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: "", hash: sipTestNumber1, type: .sip)
        conversationVM.conversation = conversation
        conversationVM.userName.accept(sipTestNumber1)
        // Act
        let searchQuery = sipTestNumber1
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result)
    }

    func testSearch_SipAccount_CreatesSipTemporaryConversationForShortNumber() {
        // Arrange
        let account = createSipAccount()
        injectionBag.accountService.setAccountList([account])
        let creationExpectation = expectation(description: "SIP temporary conversation created")
        var temporaryConversation: ConversationViewModel?
        let disposable = searchViewModel.temporaryConversation
            .skip(1)
            .compactMap { $0 }
            .subscribe(onNext: { conversation in
                temporaryConversation = conversation
                creationExpectation.fulfill()
            })
        defer { disposable.dispose() }

        // Act
        searchViewModel.searchBarText.accept("12")

        // Assert
        waitForExpectations(timeout: 2)
        XCTAssertEqual(temporaryConversation?.conversation.accountId, account.id)
        XCTAssertEqual(temporaryConversation?.conversation.hash, "12")
        XCTAssertEqual(temporaryConversation?.conversation.getAllParticipants().first?.jamiId, "12")
        XCTAssertEqual(temporaryConversation?.conversation.isCoredialog(), true)
        XCTAssertEqual(temporaryConversation?.conversation.isSwarm(), false)
    }

    func testTemporaryConversationExist_True() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM = ConversationViewModel(with: injectionBag)
        conversationVM.conversation = conversation
        searchViewModel.temporaryConversation.accept(conversationVM)
        // Act
        let result = searchViewModel.temporaryConversationExists(for: jamiId1)
        // Assert
        XCTAssertTrue(result)
    }

    func testTemporaryConversationExist_False() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId1, type: .oneToOne)
        conversationVM = ConversationViewModel(with: injectionBag)
        conversationVM.conversation = conversation
        searchViewModel.temporaryConversation.accept(conversationVM)
        // Act
        let result = searchViewModel.temporaryConversationExists(for: jamiId2)
        // Assert
        XCTAssertFalse(result)
    }
}
