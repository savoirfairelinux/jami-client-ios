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
@testable import Ring

final class JamiSearchViewModelTests: XCTestCase {

    var conversationVM: ConversationViewModel!
    var injectionBag: InjectionBag!
    var dataSource: TestableFilteredDataSource!
    var searchViewModel: JamiSearchViewModel!
    let jamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
    let registeredName = "Alice"
    let sipTestNumber = "234"

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
        let callsProvider: CallsProviderDelegate = CallsProviderDelegate()
        let callService: CallsService = CallsService(withCallsAdapter: CallsAdapter(), dbManager: dBManager)
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
        conversationVM = ConversationViewModel(with: injectionBag)
        conversationVM.conversation = BehaviorRelay(value: ConversationModel())
        dataSource = TestableFilteredDataSource(conversations: [conversationVM])
        searchViewModel = JamiSearchViewModel(with: injectionBag, source: dataSource)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        conversationVM = nil
        injectionBag = nil
        dataSource = nil
        searchViewModel = nil
    }

    func createSwarmConversation(jamiId: String, type: ConversationType) -> ConversationModel {
        let conversation = ConversationModel(withId: "", accountId: "", info: [:])
        conversation.type = type
        let participants = [["uri": jamiId]]
        conversation.addParticipantsFromArray(participantsInfo: participants, accountURI: "")
        return conversation
    }

    func createSwarmInfo(jamiId: String, name: String, containsSearchQuery: Bool) -> TestableSwarmInfo {
        let participant = ParticipantInfo(jamiId: jamiId, role: .admin)
        participant.registeredName.accept(name)
        let swarmInfo = TestableSwarmInfo(participants: [participant], containsSearchQuery: containsSearchQuery)
        return swarmInfo
    }

    func testIsConversationExists_ForExistingOneToOneConversation_QueryIsHash() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId, type: .oneToOne)
        conversationVM.conversation.accept(conversation)
        // Act
        let searchQuery = jamiId
        let result = searchViewModel.isConversationExists(for: searchQuery)
        // Assert
        XCTAssertTrue(result, "Conversation should be found when a core dialog exists for a search query")

    }

    func testIsConversationMatch_OneToOneConversation_QueryIsHash_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId, type: .oneToOne)
        conversationVM.conversation.accept(conversation)
        // Act
        let searchQuery = jamiId
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result, "When search query match participant's jamiId for oneToOne swarm conversation it should be a core dialog")
    }

    func testIsConversationMatch_OneToOneConversation_QueryIsRegisteredName_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId, type: .oneToOne)
        conversationVM.conversation.accept(conversation)
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId, name: registeredName, containsSearchQuery: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result, "When search query match participant registered name for oneToOne swarm conversation it should be a core dialog")
    }

    func testIsConversationMatch_PrivateConversation_QueryIsRegisteredName_Match() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId, type: .invitesOnly)
        conversationVM.conversation.accept(conversation)
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId, name: registeredName, containsSearchQuery: true)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result, "Invites only is not a core dialog")
    }

    func testIsConversationMatch_SwarmConversation_QueryIsRegisteredName_DoesNotMatch() {
        // Arrange
        let conversation = self.createSwarmConversation(jamiId: jamiId, type: .oneToOne)
        conversationVM.conversation.accept(conversation)
        let swarmInfo = self.createSwarmInfo(jamiId: jamiId, name: registeredName, containsSearchQuery: false)
        conversationVM.swarmInfo = swarmInfo
        // Act
        let searchQuery = registeredName + "1"
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result, "When search query match participant registered name for oneToOne swarm conversation it should be a core dialog")
    }

    func testIsConversationMatch_SipConversation_Match() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHach: sipTestNumber)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: "", hash: sipTestNumber)
        conversationVM.conversation.accept(conversation)
        conversationVM.userName.accept(sipTestNumber)
        // Act
        let searchQuery = sipTestNumber
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertTrue(result, "When search query match userName for sip conversation it should be a core dialog")
    }

    func testIsConversationMatch_SipConversation_DoesNotMatch() {
        // Arrange
        let uri = JamiURI(schema: .sip, infoHach: sipTestNumber)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: "", hash: sipTestNumber)
        conversationVM.conversation.accept(conversation)
        conversationVM.userName.accept(sipTestNumber)
        // Act
        let searchQuery = sipTestNumber + "1"
        let result = searchViewModel.isConversation(conversationVM, match: searchQuery)
        // Assert
        XCTAssertFalse(result, "When search query does not match userName for sip conversation it is not a core dialog")
    }
}
