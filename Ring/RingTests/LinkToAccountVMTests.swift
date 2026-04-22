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
import CallKit
@testable import Ring

final class LinkToAccountVMTests: XCTestCase {

    private var accountService: MockAccountsService!
    private var injectionBag: InjectionBag!
    private var viewModel: LinkToAccountVM!
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = []
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
            controller: CXCallController())
        let callService = CallsService(withCallsAdapter: CallsAdapter(), dbManager: dBManager)
        accountService = MockAccountsService(withAccountAdapter: AccountAdapter(), dbManager: dBManager)
        let contactsService = ContactsService(withContactsAdapter: ContactsAdapter(), dbManager: dBManager)
        let profileService = ProfilesService(withProfilesAdapter: ProfilesAdapter(), dbManager: dBManager)
        let dataTransferService = DataTransferService(withDataTransferAdapter: DataTransferAdapter(),
                                                      dbManager: dBManager)
        let conversationsService = ConversationsService(withConversationsAdapter: ConversationsAdapter(),
                                                        dbManager: dBManager)
        let locationSharingService = LocationSharingService(dbManager: dBManager)
        let requestsService = RequestsService(withRequestsAdapter: RequestsAdapter(), dbManager: dBManager)

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
        viewModel = LinkToAccountVM(with: injectionBag, linkAction: {})
    }

    override func tearDownWithError() throws {
        cancellables = nil
        viewModel = nil
        injectionBag = nil
        accountService = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func spinRunLoop(for seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func waitForTempAccount() {
        spinRunLoop(for: 0.15)
    }

    private func waitForState(_ target: LinkDeviceUIState) {
        if viewModel.uiState == target { return }
        let expectation = expectation(description: "uiState reaches \(target)")
        viewModel.$uiState
            .filter { $0 == target }
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)
        wait(for: [expectation], timeout: 2.0)
    }

    private func emit(state: AuthState, details: [String: String] = [:]) {
        let result = AuthResult(accountId: accountService.temporaryAccountId,
                                operationId: 0,
                                state: state,
                                details: details)
        accountService.authStateSubject.onNext(result)
    }

    private func driveToAuthenticating(authScheme: String?) {
        emit(state: .tokenAvailable, details: [LinkDeviceConstants.Keys.token: "test-token"])
        waitForState(.displayingToken(pin: "test-token"))

        emit(state: .connecting)
        waitForState(.connecting)

        var authDetails: [String: String] = [
            LinkDeviceConstants.Keys.importPeerId: jamiId1
        ]
        if let scheme = authScheme {
            authDetails[LinkDeviceConstants.Keys.importAuthScheme] = scheme
        }
        emit(state: .authenticating, details: authDetails)
        waitForState(.authenticating)
    }

    // MARK: - Tests

    func testInitialState_importButtonIsDisabled() {
        XCTAssertEqual(viewModel.uiState, .initial)
        XCTAssertTrue(viewModel.isImportButtonDisabled)
    }

    func testAuthenticating_withPasswordScheme_emptyPassword_importButtonIsEnabled() {
        waitForTempAccount()
        viewModel.password = ""
        driveToAuthenticating(authScheme: LinkDeviceConstants.AuthScheme.password)

        XCTAssertTrue(viewModel.hasPassword)
        XCTAssertFalse(viewModel.isImportButtonDisabled)
    }

    func testAuthenticating_withPasswordScheme_nonEmptyPassword_importButtonIsEnabled() {
        waitForTempAccount()
        viewModel.password = "secret"
        driveToAuthenticating(authScheme: LinkDeviceConstants.AuthScheme.password)

        XCTAssertTrue(viewModel.hasPassword)
        XCTAssertFalse(viewModel.isImportButtonDisabled)
    }

    func testAuthenticating_noPasswordScheme_importButtonIsEnabled() {
        waitForTempAccount()
        driveToAuthenticating(authScheme: nil)

        XCTAssertFalse(viewModel.hasPassword)
        XCTAssertFalse(viewModel.isImportButtonDisabled)
    }

    func testConnect_withEmptyPassword_forwardsEmptyStringToService() {
        waitForTempAccount()
        viewModel.password = ""

        viewModel.connect()

        XCTAssertEqual(accountService.provideAccountAuthenticationCalls.count, 1)
        XCTAssertEqual(accountService.provideAccountAuthenticationCalls.first?.password, "")
        XCTAssertEqual(accountService.provideAccountAuthenticationCalls.first?.accountId,
                       accountService.temporaryAccountId)
    }

    func testConnect_fromAuthenticating_disablesImportButton() {
        waitForTempAccount()
        driveToAuthenticating(authScheme: LinkDeviceConstants.AuthScheme.password)
        XCTAssertFalse(viewModel.isImportButtonDisabled)

        viewModel.connect()

        XCTAssertEqual(viewModel.uiState, .inProgress)
        XCTAssertTrue(viewModel.isImportButtonDisabled)
    }
}
