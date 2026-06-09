/*
 *  Copyright (C) 2024-2026 Savoir-faire Linux Inc.
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

import Foundation
import SwiftUI
import RxSwift
import RxRelay
import Combine

class ConversationStatePublisher: StatePublisher<ConversationState> {
    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: false))
    }

    func createSwarm(onCreated: ((_ conversationId: String) -> Void)? = nil) {
        self.stateSubject.onNext(ConversationState.createSwarm(onCreated: onCreated))
    }

    func scanQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }

    func openAboutJami() {
        self.stateSubject.onNext(ConversationState.openAboutJami)
    }

    func createAccount() {
        self.stateSubject.onNext(ConversationState.createNewAccount)
    }
}

// swiftlint:disable type_body_length
class ConversationsViewModel: ObservableObject {
    struct SearchFlowState: Equatable {
        var text = ""
        var isActive = false
        var isSearchBarDisabled = false
    }

    // temporary conversation for jami or sip
    @Published var temporaryConversation: ConversationViewModel? {
        didSet { updateSearchStatusIfNeeded() }
    }
    // jams search  result
    @Published var jamsSearchResult = [ConversationViewModel]() {
        didSet { updateSearchStatusIfNeeded() }
    }

    // conversation for blocked contact
    @Published var blockedConversation: ConversationViewModel? {
        didSet { updateSearchStatusIfNeeded() }
    }
    @Published var publicDirectoryTitle = L10n.Smartlist.results
    @Published var searchingLabel = ""
    @Published var connectionState: ConnectionType = .connected
    @Published var searchQuery: String = ""
    @Published private(set) var searchFlow = SearchFlowState()
    @Published var searchStatus: SearchStatus = .notSearching

    private let conversationsSource: ConversationDataSource

    @Published var filteredConversations: [ConversationViewModel] = []

    /// Identity of the conversations `List`. Changing this (on account switch)
    /// forces SwiftUI to discard and rebuild the entire list, releasing the
    /// previous account's row hosting views (and the view models they retain in
    /// the `UITableView` reuse pool) so they can deinit.
    @Published var currentAccountId: String = ""

    var disposeBag = DisposeBag()
    let conversationsService: ConversationsService
    let requestsService: RequestsService
    let accountsService: AccountsService
    let contactsService: ContactsService
    let networkService: NetworkService
    let injectionBag: InjectionBag
    let jamiImage = UIImage(asset: Asset.jamiIcon)!.resizeImageWith(newSize: CGSize(width: 20, height: 20), opaque: false)!

    lazy var accountsModel: AccountsViewModel = {
        return AccountsViewModel(
            accountService: self.injectionBag.accountService,
            profileService: self.injectionBag.profileService,
            nameService: self.injectionBag.nameService,
            stateEmitter: self.stateEmitter
        )
    }()

    lazy var requestsModel: RequestsViewModel = {
        return RequestsViewModel(injectionBag: self.injectionBag)
    }()

    lazy var searchModel: JamiSearchViewModel = {
        return JamiSearchViewModel(
            with: self.injectionBag,
            source: self.conversationsSource,
            searchOnlyExistingConversations: false
        )
    }()

    let stateEmitter: ConversationStatePublisher

    required init(with injectionBag: InjectionBag, conversationsSource: ConversationDataSource, stateEmitter: ConversationStatePublisher) {
        self.injectionBag = injectionBag
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.networkService = injectionBag.networkService
        self.currentAccountId = injectionBag.accountService.currentAccount?.id ?? ""
        self.stateEmitter = stateEmitter
        self.conversationsSource = conversationsSource
        self.setupNewConversationHandler()
        self.observeSearchModelUpdates()
        self.observeNetworkState()
        self.observeAccountChange()
        self.setupFilteredConversations()
        if let account = self.accountsService.currentAccount, account.isJams {
            publicDirectoryTitle = L10n.Smartlist.jamsResults
        }
    }

    private func setupFilteredConversations() {
        Publishers.CombineLatest($searchQuery, conversationsSource.$conversationViewModels)
            .map { searchQuery, conversationViewModels in
                if searchQuery.isEmpty {
                    return conversationViewModels
                } else {
                    return conversationViewModels.filter { $0.matches(searchQuery) }
                }
            }
            .assign(to: &$filteredConversations)
    }

    private func observeSearchModelUpdates() {
        searchModel
            .temporaryConversation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversation in
                guard let self = self else { return }
                withAnimation {
                    self.temporaryConversation = conversation
                }
            })
            .disposed(by: self.disposeBag)

        searchModel
            .blockedConversation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversation in
                guard let self = self else { return }
                withAnimation {
                    self.blockedConversation = conversation
                }
            })
            .disposed(by: self.disposeBag)

        searchModel
            .jamsTemporaryResults
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                withAnimation {
                    self.jamsSearchResult = conversations
                }
            })
            .disposed(by: self.disposeBag)
        searchModel
            .searchStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                self.updateSearchStatus(with: status)
            })
            .disposed(by: self.disposeBag)
    }

    private func observeAccountChange() {
        accountsService.currentAccountChanged
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] account in
                guard let self = self else { return }
                self.currentAccountId = account?.id ?? ""
                self.publicDirectoryTitle = account?.isJams == true
                    ? L10n.Smartlist.jamsResults
                    : L10n.Smartlist.results
            })
            .disposed(by: disposeBag)
    }

    private func observeNetworkState() {
        networkService.connectionState
            .startWith(networkService.connectionState.value)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.connectionState = state
            })
            .disposed(by: self.disposeBag)
    }

    private func setupNewConversationHandler() {
        conversationsSource.onNewConversationViewModelCreated = { [weak self] conversationModel in
            guard let self = self else { return }
            self.conversationFromTemporaryCreated(conversation: conversationModel)
        }

        conversationsSource.getTemporaryConversation = { [weak self] conversation in
            guard let self = self else { return nil }
            return self.findMatchingTemporaryConversation(for: conversation)
        }
    }

    private func findMatchingTemporaryConversation(for conversation: ConversationModel) -> ConversationViewModel? {
        if let tempConversation = temporaryConversation, tempConversation.conversation.isCoreDialogMatch(conversation: conversation) {
            return tempConversation
        }
        return jamsSearchResult.first { $0.conversation.isCoreDialogMatch(conversation: conversation) }
    }

    func conversationFromTemporaryCreated(conversation: ConversationModel) {
        guard findMatchingTemporaryConversation(for: conversation) != nil else { return }

        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            if self.presentedConversation.isTemporaryPresented() {
                self.presentedConversation.resetPresentedConversation()
            }
            self.dismissSearch()
        }
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel,
                          publisher: ConversationStatePublisher) {
        presentedConversation.updatePresentedConversation(conversationViewModel: conversationViewModel)
        let state = ConversationState
            .conversationDetail(conversationViewModel:
                                    conversationViewModel)
        publisher.emitState(state)
    }

    func showAccount(publisher: ConversationStatePublisher) {
        guard let account = accountsService.currentAccount else { return }
        let state = ConversationState.showAccountSettings(account: account)
        publisher.emitState(state)
    }

    func showConversationFromQRCode(jamiId: String,
                                    publisher: ConversationStatePublisher) {
        // Ensure there is a current account available
        guard let account = accountsService.currentAccount else { return }

        // Attempt to find an existing one-to-one conversation with the specified jamiId
        if let existingConversation = conversationsSource.conversationViewModels.first(where: {
            $0.conversation.isCoredialog() && $0.conversation.getParticipants().first?.jamiId == jamiId
        }) {
            // Update and show the existing conversation
            presentedConversation.updatePresentedConversation(conversationViewModel: existingConversation)
            let state = ConversationState
                .conversationDetail(conversationViewModel:
                                        existingConversation)
            publisher.emitState(state)
            return
        }

        // Attempt to find blocked conversation
        if let blockedConversation = conversationsSource.blockedConversation.first(where: { $0.isCoreConversationWith(jamiId: jamiId) }) {
            presentedConversation.updatePresentedConversation(conversationViewModel: blockedConversation)
            let state = ConversationState
                .conversationDetail(conversationViewModel:
                                        blockedConversation)
            publisher.emitState(state)
            return
        }

        // Create a new temporary swarm conversation since no existing one matched
        let tempConversation = createTemporarySwarmConversation(with: jamiId, accountId: account.id)
        temporaryConversation = tempConversation
        presentedConversation.updatePresentedConversation(conversationViewModel: tempConversation)
        let state = ConversationState
            .conversationDetail(conversationViewModel:
                                    tempConversation)
        publisher.emitState(state)
    }

    private func createTemporarySwarmConversation(with hash: String, accountId: String) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: hash)
        let isSelf = self.accountsService.getAccount(fromAccountId: accountId)?.jamiId == hash
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: accountId,
                                             type: .oneToOne,
                                             isLocal: isSelf)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.userName.accept(hash)
        newConversation.conversation = conversation
        newConversation.swiftUIModel.isTemporary = true
        return newConversation
    }

    func isSipAccount() -> Bool {
        guard let account = self.accountsService.currentAccount else { return false }
        return account.type == .sip
    }

    func showSipConversation(withNumber number: String,
                             publisher: ConversationStatePublisher) {
        guard let account = self.accountsService
                .currentAccount else {
            return
        }
        let uri = JamiURI.init(schema: URIType.sip,
                               infoHash: number,
                               account: account)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             hash: number,
                                             type: .sip)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = conversation
        let state = ConversationState
            .conversationDetail(conversationViewModel:
                                    newConversation)
        publisher.emitState(state)
    }

    func performDestructiveAction(_ action: ConversationDestructiveAction, conversationViewModel: ConversationViewModel) {
        switch action {
        case .blockContact:
            removeContact(conversationViewModel: conversationViewModel, ban: true)
        case .removeContact:
            removeContact(conversationViewModel: conversationViewModel, ban: false)
        case .removeConversation:
            removeConversation(conversationViewModel: conversationViewModel)
        }
    }

    private func removeConversation(conversationViewModel: ConversationViewModel) {
        conversationViewModel.closeAllPlayers()
        guard let conversation = conversationViewModel.conversation else { return }
        // SIP conversations are local DB constructs, not daemon swarms, so the daemon
        // removeConversation call is a no-op for them — clear them from the DB instead.
        if conversation.isSip() {
            self.conversationsService.removeConversationFromDB(conversation: conversation,
                                                               keepConversation: false)
            return
        }
        self.conversationsService.removeConversation(conversationId: conversation.id,
                                                     accountId: conversation.accountId)
    }

    private func removeContact(conversationViewModel: ConversationViewModel, ban: Bool) {
        conversationViewModel.closeAllPlayers()
        guard let conversation = conversationViewModel.conversation else { return }
        let accountId = conversation.accountId
        guard conversation.isCoredialog(),
              let participantId = conversation.getParticipants().first?.jamiId else {
            removeConversation(conversationViewModel: conversationViewModel)
            return
        }

        self.contactsService
            .removeContact(withId: participantId,
                           ban: ban,
                           withAccountId: accountId)
            .asObservable()
            .subscribe(onCompleted: { [weak self, weak conversationViewModel] in
                guard let conversationViewModel = conversationViewModel else { return }
                self?.conversationsService
                    .removeConversationFromDB(conversation: conversationViewModel.conversation,
                                              keepConversation: false)
            })
            .disposed(by: self.disposeBag)
    }

    // MARK: - PresentedConversation
    struct PresentedConversation {
        let temporaryConversationId = "temporary"
        var presentedId: String = ""

        mutating func updatePresentedConversation(conversationViewModel: ConversationViewModel) {
            if conversationViewModel.conversation.id.isEmpty {
                presentedId = temporaryConversationId
            } else {
                presentedId = conversationViewModel.conversation.id
            }
        }

        func isTemporaryPresented() -> Bool {
            return self.presentedId == temporaryConversationId
        }

        func hasPresentedConversation() -> Bool {
            return !presentedId.isEmpty
        }

        mutating func resetPresentedConversation() {
            self.presentedId = ""
        }
    }

    var presentedConversation = PresentedConversation()

    // MARK: - Search
    func updateSearchText(_ text: String) {
        searchFlow.text = text
        performSearch(query: text.lowercased())
    }

    func startSwarmCreation() {
        stateEmitter.createSwarm(onCreated: { [weak self] _ in
            self?.dismissSearch()
        })
    }

    func setSearchActive(_ isActive: Bool) {
        searchFlow.isActive = isActive
    }

    func setSearchBarDisabled(_ isDisabled: Bool) {
        searchFlow.isSearchBarDisabled = isDisabled
    }

    private func dismissSearch() {
        searchFlow = SearchFlowState(text: "", isActive: false, isSearchBarDisabled: true)
        performSearch(query: "")
    }

    func performSearch(query: String) {
        withAnimation {
            self.searchQuery = query
        }
        searchModel.searchBarText.accept(query)
    }

    private func updateSearchStatus(with status: SearchStatus? = nil) {
        if let status = status {
            switch status {
            case .noResult:
                evaluateSearchResults()
            default:
                searchStatus = status
            }
        } else {
            evaluateSearchResults()
        }
    }

    private func updateSearchStatusIfNeeded() {
        guard let account = self.accountsService.currentAccount else { return }
        if searchQuery.count > 2 || account.isJams || isSipAccount() {
            evaluateSearchResults()
        } else {
            searchStatus = .invalidId
        }
    }

    private func evaluateSearchResults() {
        if temporaryConversation != nil {
            searchStatus = .foundTemporary
        } else if !jamsSearchResult.isEmpty {
            searchStatus = .foundJams
        } else {
            searchStatus = .noResult
        }
    }

    // MARK: - menu settings

    func donate() {
        SharedActionsPresenter.openDonationLink()
    }

    var accountInfoToShare: String {
        return self.accountsService.accountInfoToShare?.joined(separator: "\n") ?? ""
    }

    func closeAllPlayers() {
        conversationsSource.conversationViewModels.forEach { conversationModel in
            conversationModel.closeAllPlayers()
        }
    }
}
// swiftlint:enable type_body_length
