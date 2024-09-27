/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import Foundation
import SwiftUI
import RxSwift
import RxRelay
import Combine

// swiftlint:disable type_body_length
class ConversationsViewModel: ObservableObject, Stateable {
    // temporary conversation for jami or sip
    @Published var temporaryConversation: ConversationViewModel? {
        didSet { updateSearchStatusIfNeeded() }
    }
    // jams search  result
    @Published var jamsSearchResult = [ConversationViewModel]() {
        didSet { updateSearchStatusIfNeeded() }
    }
    @Published var publicDirectoryTitle = L10n.Smartlist.results
    @Published var searchingLabel = ""
    @Published var connectionState: ConnectionType = .none
    @Published var searchQuery: String = ""
    @Published var conversationCreated: String = ""
    @Published var searchStatus: SearchStatus = .notSearching

    private let conversationsSource: ConversationDataSource

    @Published var filteredConversations: [ConversationViewModel] = []

    enum Target {
        case smartList
        case newMessage
    }

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

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
            stateSubject: stateSubject
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

    required init(with injectionBag: InjectionBag, conversationsSource: ConversationDataSource) {
        self.injectionBag = injectionBag
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.networkService = injectionBag.networkService
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

            if let tempConversation = self.temporaryConversation, tempConversation.conversation == conversationModel {
                self.conversationFromTemporaryCreated(conversation: conversationModel)
                tempConversation.conversation = conversationModel
                tempConversation.conversationCreated.accept(true)
                return
            }

            if let jamsConversation = self.jamsSearchResult.first(where: { $0.conversation == conversationModel }) {
                jamsConversation.conversation = conversationModel
                jamsConversation.conversationCreated.accept(true)
                self.conversationFromTemporaryCreated(conversation: conversationModel)
            }
        }
    }

    func openNewMessagesWindow() {
        self.stateSubject.onNext(ConversationState.compose(model: self))
    }

    func conversationFromTemporaryCreated(conversation: ConversationModel) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            // If conversation created from temporary navigate back to smart list
            if self.presentedConversation.isTemporaryPresented() {
                self.presentedConversation.resetPresentedConversation()
            }
            // cleanup search
            self.performSearch(query: "")
            // disable search bar
            conversationCreated = conversation.id
        }
    }

    private func subscribeConversations() {
//        let conversationObservable = self.conversationsService.conversations
//            .share()
//            .startWith(self.conversationsService.conversations.value)
//        let conersationViewModels =
//            conversationObservable.map { [weak self] conversations -> [ConversationViewModel] in
//                guard let self = self else { return [] }
//
//                // Reset conversationViewModels if conversations are empty
//                if conversations.isEmpty {
//                    self.conversationViewModels.removeAll()
//                    return []
//                }
//
//                // Map conversations to view models, updating existing ones or creating new
//                return conversations.compactMap { conversationModel in
//                    // Check for existing conversation view model
//                    if let existing = self.conversationViewModels.first(where: { $0.conversation == conversationModel }) {
//                        return existing
//                    }
//                    // Check for temporary conversation
//                    else if let tempConversation = self.temporaryConversation, tempConversation.conversation == conversationModel {
//                        tempConversation.conversation = conversationModel
//                        tempConversation.conversationCreated.accept(true)
//                        self.conversationFromTemporaryCreated(conversation: conversationModel)
//                        return tempConversation
//                    } else if let jamsConversation = self.jamsSearchResult.first(where: { jams in
//                        jams.conversation == conversationModel
//                    }) {
//                        jamsConversation.conversation = conversationModel
//                        jamsConversation.conversationCreated.accept(true)
//                        self.conversationFromTemporaryCreated(conversation: conversationModel)
//                        return jamsConversation
//                    }
//                    // Create new conversation view model
//                    else {
//                        let newViewModel = ConversationViewModel(with: self.injectionBag)
//                        newViewModel.conversation = conversationModel
//                        return newViewModel
//                    }
//                }
//            }
//
//        conersationViewModels
//            .subscribe(onNext: { [weak self] updatedViewModels in
//                DispatchQueue.main.async {
//                    guard let self = self else { return }
//                    for conversation in updatedViewModels {
//                        conversation.swiftUIModel.isTemporary = false
//                    }
//                    self.conversationViewModels = updatedViewModels
//                }
//            })
//            .disposed(by: self.disposeBag)
//
//        // Observe conversation removed
//        self.conversationsService.sharedResponseStream
//            .filter({ event in
//                event.eventType == .conversationRemoved && event.getEventInput(.accountId) == self.accountsService.currentAccount?.id
//            })
//            .observe(on: MainScheduler.instance)
//            .subscribe(onNext: { [weak self] event in
//                guard let conversationId: String = event.getEventInput(.conversationId),
//                      let accountId: String = event.getEventInput(.accountId) else { return }
//                guard let index = self?.conversationViewModels.firstIndex(where: { conversationModel in
//                    conversationModel.conversation.id == conversationId && conversationModel.conversation.accountId == accountId
//                }) else { return }
//                self?.conversationViewModels.remove(at: index)
//                self?.updateConversations()
//            })
//            .disposed(by: self.disposeBag)
    }

    private func updateConversations(with filtered: [ConversationViewModel]? = nil) {
//        DispatchQueue.main.async {[weak self] in
//            guard let self = self else { return }
//            // Use filtered conversations if provided; otherwise, fall back to all conversationViewModels
//            self.conversations = filtered ?? self.conversationViewModels
//        }
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        presentedConversation.updatePresentedConversation(conversationViewModel: conversationViewModel)
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
                                                                        conversationViewModel))
    }

    func closeComposingMessage() {
        self.stateSubject.onNext(ConversationState.closeComposingMessage)
    }

    func showAccount() {
        guard let account = accountsService.currentAccount else { return }
        self.stateSubject.onNext(ConversationState.showAccountSettings(account: account))
    }

    func showConversationFromQRCode(jamiId: String) {
        // Ensure there is a current account available
        guard let account = accountsService.currentAccount else { return }

        // Attempt to find an existing one-to-one conversation with the specified jamiId
        if let existingConversation = conversationsSource.conversationViewModels.first(where: {
            $0.conversation.type == .oneToOne && $0.conversation.getParticipants().first?.jamiId == jamiId
        }) {
            // Update and show the existing conversation
            presentedConversation.updatePresentedConversation(conversationViewModel: existingConversation)
            stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel: existingConversation))
            return
        }

        // Create a new temporary swarm conversation since no existing one matched
        let tempConversation = createTemporarySwarmConversation(with: jamiId, accountId: account.id)
        temporaryConversation = tempConversation
        presentedConversation.updatePresentedConversation(conversationViewModel: tempConversation)
        stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel: tempConversation))
    }

    private func createTemporarySwarmConversation(with hash: String, accountId: String) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: hash)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: accountId)
        conversation.type = .oneToOne
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.userName.accept(hash)
        newConversation.conversation = conversation
        newConversation.swiftUIModel.isTemporary = true
        return newConversation
    }

    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: false))
    }

    func isSipAccount() -> Bool {
        guard let account = self.accountsService.currentAccount else { return false }
        return account.type == .sip
    }

    func showSipConversation(withNumber number: String) {
        guard let account = self.accountsService
                .currentAccount else {
            return
        }
        let uri = JamiURI.init(schema: URIType.sip,
                               infoHash: number,
                               account: account)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             hash: number)
        conversation.type = .sip
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = conversation
        self.stateSubject
            .onNext(ConversationState
                        .conversationDetail(conversationViewModel:
                                                newConversation))
    }

    func deleteConversation(conversationViewModel: ConversationViewModel) {
        conversationViewModel.closeAllPlayers()
        let accountId = conversationViewModel.conversation.accountId
        let conversationId = conversationViewModel.conversation.id
        if conversationViewModel.conversation.isCoredialog(),
           let participantId = conversationViewModel.conversation.getParticipants().first?.jamiId {
            self.contactsService
                .removeContact(withId: participantId,
                               ban: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversationViewModel] in
                    guard let conversationViewModel = conversationViewModel else { return }
                    self?.conversationsService
                        .removeConversationFromDB(conversation: conversationViewModel.conversation,
                                                  keepConversation: false)
                })
                .disposed(by: self.disposeBag)
        } else {
            self.conversationsService.removeConversation(conversationId: conversationId, accountId: accountId)
        }
    }

    func blockConversation(conversationViewModel: ConversationViewModel) {
        conversationViewModel.closeAllPlayers()
        let accountId = conversationViewModel.conversation.accountId
        let conversationId = conversationViewModel.conversation.id
        if conversationViewModel.conversation.isCoredialog(),
           let participantId = conversationViewModel.conversation.getParticipants().first?.jamiId {
            self.contactsService
                .removeContact(withId: participantId,
                               ban: true,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversationViewModel] in
                    guard let conversationViewModel = conversationViewModel else { return }
                    self?.conversationsService
                        .removeConversationFromDB(conversation: conversationViewModel.conversation,
                                                  keepConversation: false)
                })
                .disposed(by: self.disposeBag)
        } else {
            self.conversationsService.removeConversation(conversationId: conversationId, accountId: accountId)
        }
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
    func performSearch(query: String) {
        withAnimation {
            self.searchQuery = query
        }
        searchModel.searchBarText.accept(query)
    }

    private func updateSearchStatus(with status: SearchStatus? = nil) {
        if let status = status {
            switch status {
            case .searching, .notSearching, .invalidId:
                searchStatus = status
            default:
                evaluateSearchResults()
            }
        } else {
            evaluateSearchResults()
        }
    }

    private func updateSearchStatusIfNeeded() {
        guard let account = self.accountsService.currentAccount else { return }
        if searchQuery.count > 2 || account.isJams {
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

    func createSwarm() {
        self.stateSubject.onNext(ConversationState.createSwarm)
    }

    func scanQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }

    func openAboutJami() {
        self.stateSubject.onNext(ConversationState.openAboutJami)
    }

    func donate() {
        SharedActionsPresenter.openDonationLink()
    }

    func createAccount() {
        self.stateSubject.onNext(ConversationState.createNewAccount)
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
