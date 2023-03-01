//
//  SmartListSearchingTests.swift
//  RingTests
//
//  Created by kateryna on 2023-03-01.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import XCTest
import RxRelay
@testable import Ring

final class SmartListSearchingTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSearchReslut_whenExactMatchJamiId() {
        // setup
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

        let injectionBag: InjectionBag = InjectionBag(withDaemonService: daemonService,
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
        let smartListVM = SmartlistViewModel(with: injectionBag)
        let conversationVM = ConversationViewModel(with: injectionBag)
        let testJamiId = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        let convInfo = ["mode": "0"]
        let participants = [["uri": testJamiId]]
        let conversation = ConversationModel(withId: "", accountId: "", info: convInfo)
        conversation.addParticipantsFromArray(participantsInfo: participants, accountURI: "")
        conversationVM.conversation = BehaviorRelay(value: conversation)
        let searchString = "b48cf0140bea12734db05ebcdb012f1d265bed84"
        smartListVM.conversationViewModels = [conversationVM]
        let searchVM = JamiSearchViewModel(with: injectionBag, source: smartListVM)
        let result = searchVM.performExactSearchForSHA1(for: searchString)
        XCTAssertEqual(result, conversationVM, "when search for existing conversation the conversation should be returned")
    }
}
