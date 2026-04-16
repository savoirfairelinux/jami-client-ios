/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
import CallKit
import Combine
@testable import Ring

final class ActiveCallsViewModelTests: XCTestCase {
    private var injectionBag: InjectionBag!
    private var dataSource: TestableFilteredDataSource!
    private var conversationVM: ConversationViewModel!
    private var cancellables = Set<AnyCancellable>()

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
        let callsProvider: CallsProviderService = CallsProviderService(
            provider: CXProvider(configuration: CallsHelpers.providerConfiguration()),
            controller: CXCallController()
        )
        let callService: CallsService = CallsService(withCallsAdapter: CallsAdapter(), dbManager: dBManager)
        let accountService: AccountsService = AccountsService(withAccountAdapter: AccountAdapter(), dbManager: dBManager)
        let contactsService: ContactsService = ContactsService(withContactsAdapter: ContactsAdapter(), dbManager: dBManager)
        let profileService: ProfilesService = ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: dBManager)
        let dataTransferService: DataTransferService = DataTransferService(withDataTransferAdapter: DataTransferAdapter(), dbManager: dBManager)
        let conversationsService: ConversationsService = ConversationsService(withConversationsAdapter: ConversationsAdapter(), dbManager: dBManager)
        let locationSharingService: LocationSharingService = LocationSharingService(dbManager: dBManager)
        let requestsService: RequestsService = RequestsService(withRequestsAdapter: RequestsAdapter(), dbManager: dBManager)

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
        let conversation = ConversationModel(withId: conversationId1, accountId: accountId1, info: [:])
        conversation.type = .publicChat
        conversationVM.conversation = conversation

        let participant = ParticipantInfo(jamiId: jamiId1, role: .admin, profileService: injectionBag.profileService)
        let swarmInfo = TestableSwarmInfo(participants: [participant], containsSearchQuery: false, hasParticipantWithRegisteredName: false)
        swarmInfo.conversation = conversation
        swarmInfo.finalTitle.accept(title1)
        conversationVM.swarmInfo = swarmInfo

        dataSource = TestableFilteredDataSource(conversations: [conversationVM], injectionBag: injectionBag)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        cancellables.removeAll()
        injectionBag = nil
        dataSource = nil
        conversationVM = nil
    }

    func testActiveCalls_WhenSameCallReportedForMultipleAccounts_DedupesToSingleRow() {
        let callId = "call1"
        let uri = "uri1"
        let device = "device1"

        let account1 = AccountModel(withAccountId: accountId1)
        let account2 = AccountModel(withAccountId: accountId2)
        injectionBag.accountService.updateCurrentAccount(account: account1)

        let viewModel = ActiveCallsViewModel(injectionBag: injectionBag, conversationsSource: dataSource)

        let exp = expectation(description: "callsByAccount dedupes to a single row")
        viewModel.$callsByAccount
            .filter { $0.values.flatMap { $0 }.count == 1 }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        let calls = [["id": callId, "uri": uri, "device": device]]
        injectionBag.callService.activeCallsChanged(conversationId: conversationId1, calls: calls, account: account1)
        injectionBag.callService.activeCallsChanged(conversationId: conversationId1, calls: calls, account: account2)

        wait(for: [exp], timeout: 1.0)

        let allRows = viewModel.callsByAccount.values.flatMap { $0 }
        XCTAssertEqual(allRows.count, 1, "same remote call mirrored across two trackers must collapse to a single row")
        XCTAssertEqual(allRows.first?.call.accountId, account1.id, "surviving row must belong to the currently-selected account")
    }
}
