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

class ConversationsViewModel: ObservableObject, FilterConversationDataSource {
    // filtered conversations to display
    @Published var conversations = [ConversationViewModel]()
    // temporary conversation for jami or sip
    @Published var temporaryConversation: ConversationViewModel? {
        didSet { updateSearchStatusIfNeeded() }
    }
    // jams search  result
    @Published var jamsSearchResult = [ConversationViewModel]() {
        didSet { updateSearchStatusIfNeeded() }
    }
    // all conversations
    var conversationViewModels = [ConversationViewModel]() {
        didSet {
            self.updateConversations()
        }
    }

    var publicDirectoryTitle = "Public directory"

    @Published var selectedSegment = 0
    @Published var unreadMessages = 0
    @Published var searchingLabel = ""
    @Published var connectionState: ConnectionType = .none
    @Published var isSip: Bool = false
    var disposeBag = DisposeBag()
    let conversationsService: ConversationsService
    let requestsService: RequestsService
    let accountsService: AccountsService
    let contactsService: ContactsService
    let stateSubject: PublishSubject<State>
    let injectionBag: InjectionBag
    var searchModel: JamiSearchViewModel?
    var requestsModel: RequestsViewModel
    @Published var searchQuery: String = ""
    @Published var conversationCreated: String = ""
    @Published var searchStatus: SearchStatus = .notSearching
    let jamiImage = UIImage(asset: Asset.jamiIcon)!.resizeImageWith(newSize: CGSize(width: 20, height: 20), opaque: false)!

    var accountsModel: AccountsViewModel

    init(injectionBag: InjectionBag, stateSubject: PublishSubject<State>) {
        self.conversationsService = injectionBag.conversationsService
        self.requestsService = injectionBag.requestsService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.accountsModel = AccountsViewModel(accountService: injectionBag.accountService, profileService: injectionBag.profileService, stateSubject: stateSubject)
        self.injectionBag = injectionBag
        self.stateSubject = stateSubject
        self.requestsModel = RequestsViewModel(injectionBag: injectionBag)
        self.searchModel = JamiSearchViewModel(with: injectionBag, source: self, searchOnlyExistingConversations: false)
        self.subscribeConversations()
        self.subscribeSearch()
        if let account = self.accountsService.currentAccount, account.isJams {
            publicDirectoryTitle = "Search Result"
        }
        injectionBag.networkService.connectionState
            .startWith(injectionBag.networkService.connectionState.value)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.connectionState = state
            })
            .disposed(by: self.disposeBag)
        if let account = self.accountsService.currentAccount {
            self.isSip = account.type == .sip
        }
    }

    func conversationFromTemporaryCreated(conversation: ConversationModel) {
        // If conversation created from temporary navigate back to smart list
        if self.presentedConversation.isTemporaryPresented() {
            navigationTarget = .smartList
            self.presentedConversation.resetPresentedConversation()
        }
        // cleanup search
        self.performSearch(query: "")
        // disable search bar
        conversationCreated = conversation.id
    }

    private func subscribeConversations() {
        let conversationObservable = self.conversationsService.conversations
            .share()
            .startWith(self.conversationsService.conversations.value)
        let conersationViewModels =
        conversationObservable.map { [weak self] conversations -> [ConversationViewModel] in
                guard let self = self else { return [] }

                // Reset conversationViewModels if conversations are empty
                if conversations.isEmpty {
                    self.conversationViewModels.removeAll()
                    return []
                }

                // Map conversations to view models, updating existing ones or creating new
                return conversations.compactMap { conversationModel in
                    // Check for existing conversation view model
                    if let existing = self.conversationViewModels.first(where: { $0.conversation == conversationModel }) {
                        return existing
                    }
                    // Check for temporary conversation
                    else if let tempConversation = self.temporaryConversation, tempConversation.conversation == conversationModel {
                        tempConversation.conversation = conversationModel
                        self.conversationViewModels.append(tempConversation)
                        tempConversation.showInvitation.accept(false)
                        tempConversation.conversationCreated.accept(true)
                        self.conversationFromTemporaryCreated(conversation: conversationModel)
                        return tempConversation
                    }
                    // Create new conversation view model
                    else {
                        let newViewModel = ConversationViewModel(with: self.injectionBag)
                        newViewModel.conversation = conversationModel
                        self.conversationViewModels.append(newViewModel)
                        return newViewModel
                    }
                }
            }

        conersationViewModels
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] updatedViewModels in
                self?.conversationViewModels = updatedViewModels
            })
            .disposed(by: self.disposeBag)

        // Observe conversation removed
        self.conversationsService.sharedResponseStream
            .filter({ event in
                event.eventType == .conversationRemoved && event.getEventInput(.accountId) == self.accountsService.currentAccount?.id
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let conversationId: String = event.getEventInput(.conversationId),
                      let accountId: String = event.getEventInput(.accountId) else { return }
                guard let index = self?.conversationViewModels.firstIndex(where: { conversationModel in
                    conversationModel.conversation.id == conversationId && conversationModel.conversation.accountId == accountId
                }) else { return }
                self?.conversationViewModels.remove(at: index)
                self?.updateConversations()
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeSearch() {
        searchModel?
            .filteredResults
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                let filteredConv = conversations.isEmpty && searchQuery.isEmpty  ? nil : conversations
                self.updateConversations(with: filteredConv)
            })
            .disposed(by: self.disposeBag)

        searchModel?
            .temporaryConversation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversation in
                guard let self = self else { return }
                withAnimation {
                    self.temporaryConversation = conversation
                }
            })
            .disposed(by: self.disposeBag)

        searchModel?
            .jamsTemporaryResults
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                guard let self = self else { return }
                withAnimation {
                    self.jamsSearchResult = conversations
                }
            })
            .disposed(by: self.disposeBag)
        searchModel?
            .searchStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                self.updateSearchStatus(with: status)
            })
            .disposed(by: self.disposeBag)
    }

    private func updateConversations(with filtered: [ConversationViewModel]? = nil) {
        DispatchQueue.main.async {[weak self] in
            guard let self = self else { return }
            withAnimation {
                // Use filtered conversations if provided; otherwise, fall back to all conversationViewModels
                self.conversations = filtered ?? self.conversationViewModels
            }
        }
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        presentedConversation.updatePresentedConversation(conversationViewModel: conversationViewModel)
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
                                                                        conversationViewModel))
    }

    func showConversationFromQRCode(jamiId: String) {
        // Ensure there is a current account available
        guard let account = accountsService.currentAccount else { return }

        // Attempt to find an existing one-to-one conversation with the specified jamiId
        if let existingConversation = conversations.first(where: {
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
        newConversation.showInvitation.accept(true)
        return newConversation
    }

    func showConversationIfExists(conversationId: String) {
        if let conversation = self.conversations.first(where: { conv in
            conv.conversation.id == conversationId
        }) {
            self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel: conversation))
        }
    }

    func deleteConversation() {

    }

    func blockConversation() {

    }

    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: false))
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

    func delete(conversationViewModel: ConversationViewModel) {
        //conversationViewModel.closeAllPlayers()
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

    func blockConversationsContact(conversationViewModel: ConversationViewModel) {
        // conversationViewModel.closeAllPlayers()
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

    // MARK: - Navigation
    enum Target {
        case smartList
        case newMessage
    }

    @Published var slideDirectionUp: Bool = true

    @Published var navigationTarget: Target = .smartList

    // MARK: - Search
    func performSearch(query: String) {
        withAnimation {
            self.searchQuery = query
        }
        if let searchModel = self.searchModel {
            searchModel.searchBarText.accept(query)
        }
    }

    private func updateSearchStatus(with status: SearchStatus? = nil) {
        if let status = status {
            switch status {
                case .searching:
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
        if let _ = temporaryConversation {
            searchStatus = .foundTemporary
        } else if !jamsSearchResult.isEmpty {
            searchStatus = .foundJams
        } else {
            searchStatus = .noResult
        }
    }

    // MARK: - menu settings

    func openSettings() {
        self.stateSubject.onNext(ConversationState.showAccountSettings)
    }

    func openRequests() {
        self.stateSubject.onNext(ConversationState.presentRequestsController)
    }

    func createSwarm() {
        self.stateSubject.onNext(ConversationState.createSwarm)
    }

    func scanQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }

    func showGeneralSettings() {
        self.stateSubject.onNext(ConversationState.showGeneralSettings)
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
}
