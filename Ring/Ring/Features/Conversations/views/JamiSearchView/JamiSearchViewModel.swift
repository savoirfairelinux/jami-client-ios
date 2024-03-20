/*
 *  Copyright (C) 2020-2023 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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
import RxSwift
import RxCocoa
import SwiftyBeaver

enum SearchStatus {
    case notSearching
    case searching
    case noResult
    case invalidId

    func toString() -> String {
        switch self {
            case .notSearching:
                return ""
            case .searching:
                return L10n.Global.search
            case .noResult:
                return "Username not found"
            case .invalidId:
                return "Invalid id"
        }
    }
}

protocol FilterConversationDataSource {
    var conversationViewModels: [ConversationViewModel] { get set }
}

protocol FilterConversationDelegate: AnyObject {
    func temporaryConversationCreated(conversation: ConversationViewModel?)
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel)
}

class JamiSearchViewModel {
    struct JamsUserSearchModel {
        var username, firstName, lastName, organization, jamiId: String
        var profilePicture: Data?
    }

    private let log = SwiftyBeaver.self

    // Services
    private let nameService: NameService
    private let accountsService: AccountsService
    private let injectionBag: InjectionBag

    private let disposeBag = DisposeBag()

    lazy var searchResults: Observable<[ConversationSection]> = {
        return Observable<[ConversationSection]>
            .combineLatest(self.temporaryConversation.asObservable(),
                           self.filteredResults.asObservable(),
                           self.jamsTemporaryResults.asObservable(),
                           resultSelector: { temporaryConversation, filteredResults, jamsTemporaryResults in
                            var sections = [ConversationSection]()
                            if !jamsTemporaryResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: jamsTemporaryResults))
                            } else if let temporaryConversation = temporaryConversation {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: [temporaryConversation]))
                            }
                            if !filteredResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.conversations, items: filteredResults))
                            }
                            return sections
                           })
            .observe(on: MainScheduler.instance)
    }()

    // Temporary conversation created when perform search for a new contact.
    var temporaryConversation = BehaviorRelay<ConversationViewModel?>(value: nil)

    /*
     Existing conversations with the title containing search result or one of
     the participant's name containing search result.
     */
    var filteredResults = BehaviorRelay(value: [ConversationViewModel]())

    // Jams temporary conversations created when perform search for a new contact
    let jamsTemporaryResults = BehaviorRelay<[ConversationViewModel]>(value: [])

    let searchBarText = BehaviorRelay<String>(value: "")
    var isSearching: Observable<Bool>!
    var searchStatus = PublishSubject<SearchStatus>()
    private let dataSource: FilterConversationDataSource
    // Indicates if the search should be limited to only existing conversations.
    private let searchOnlyExistingConversations: Bool
    private weak var delegate: FilterConversationDelegate?

    init(with injectionBag: InjectionBag, source: FilterConversationDataSource, searchOnlyExistingConversations: Bool) {
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
        self.dataSource = source
        self.searchOnlyExistingConversations = searchOnlyExistingConversations

        // Observes if the user is searching.
        self.isSearching = searchBarText.asObservable()
            .map({ text in
                return !text.isEmpty
            })
            .observe(on: MainScheduler.instance)

        // Observes search bar text.
        searchBarText.asObservable()
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] text in
                if text.isEmpty {
                    self?.searchStatus.onNext(.notSearching)
                }
                if text.count < 3 {
                    self?.searchStatus.onNext(.invalidId)
                }
                self?.search(withText: text)
            })
            .disposed(by: disposeBag)
    }

    static func removeFilteredConversations(from conversationViewModels: [ConversationViewModel],
                                            with filteredResults: [ConversationViewModel]) -> [ConversationViewModel] {
        return conversationViewModels
            .filter({ !filteredResults.contains($0) })
    }

    func updateSearchStatus() {
        if self.jamsTemporaryResults.value.isEmpty && self.temporaryConversation.value == nil {
            self.searchStatus.onNext(.noResult)
        } else {
            self.searchStatus.onNext(.notSearching)
        }
    }

    func setDelegate(delegate: FilterConversationDelegate?) {
        self.delegate = delegate
    }

    private func temporaryConversationCreated(tempConversation: ConversationViewModel?) {
        self.temporaryConversation.accept(tempConversation)
        if let delegate = self.delegate {
            delegate.temporaryConversationCreated(conversation: tempConversation)
        }
    }

    func isConversation(_ conversation: ConversationViewModel, contains searchQuery: String) -> Bool {
        /*
         For swarm conversation check if conversation title or one of the participant's
         name or jamiId contains search text. For SIP, non swarm and jams conversations
         check userName, displayName and participant hash.
         */
        if conversation.model().isSwarm() {
            guard let swarmInfo = conversation.swarmInfo else { return false }
            return swarmInfo.contains(searchQuery: searchQuery)
        } else {
            var displayNameContainsText = false
            if let displayName = conversation.displayName.value {
                displayNameContainsText = displayName.containsCaseInsensitive(string: searchQuery)
            }
            var participantHashContainsText = false
            if let hash = conversation.model().getParticipants().first?.jamiId {
                participantHashContainsText = hash.containsCaseInsensitive(string: searchQuery)
            }
            return conversation.userName.value.containsCaseInsensitive(string: searchQuery) ||
                displayNameContainsText || participantHashContainsText
        }
    }

    private func getFilteredConversations(for searchQuery: String) -> [ConversationViewModel]? {
        let conversations =
            self.dataSource.conversationViewModels
            .filter({[weak self] conversation in
                guard let self = self else { return false }
                return self.isConversation(conversation, contains: searchQuery)
            })
        return conversations
    }

    func temporaryConversationExists(for jamiId: String) -> Bool {
        guard let temporaryConversation = self.temporaryConversation.value else { return false }
        return temporaryConversation.model().getParticipants().first?.jamiId == jamiId
    }

    func isConversation(_ conversation: ConversationViewModel, match searchQuery: String) -> Bool {
        guard conversation.model().isCoredialog() else {
            return false
        }
        if searchQuery.isSHA1() {
            return conversation.model().getParticipants().first?.jamiId == searchQuery
        }
        if conversation.model().isSwarm() {
            return conversation.swarmInfo?.hasParticipantWithRegisteredName(name: searchQuery) ?? false
        }
        return conversation.userName.value == searchQuery
    }

    func isConversationExists(for searchQuery: String) -> Bool {
        let coreDialog = self.dataSource.conversationViewModels
            .filter({[weak self] conversation in
                guard let self = self else { return false }
                return self.isConversation(conversation, match: searchQuery)
            }).first
        return coreDialog != nil
    }

    private func createTemporaryConversation(searchQuery: String, account: AccountModel) -> ConversationViewModel {
        switch account.type {
        case .sip:
            return self.createTemporarySipConversation(with: searchQuery, account: account)
        case .ring:
            return self.createTemporarySwarmConversation(with: searchQuery, accountId: account.id)
        }
    }

    // Filter existing conversations, perform name lookup and create temporary conversations.
    private func search(withText searchQuery: String) {
        self.cleanUpPreviousSearch()
        if searchQuery.isEmpty { return }
        if let filteredConversations = getFilteredConversations(for: searchQuery) {
            self.filteredResults.accept(filteredConversations)
        }
        // not need to searh on network
        if searchOnlyExistingConversations || searchQuery.count < 3 {
            return
        }
        self.addTemporaryConversationsIfNeed(searchQuery: searchQuery)
    }

    private func addTemporaryConversationsIfNeed(searchQuery: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }
        /*
         For jams account perform searchUser. Temporary conversations will be added
         when search result received. We should perform search even if a conversation
         already exists to get results with similar names. There why it is done before
         checking isConversationExists.
         */
        if self.accountsService.isJams(for: currentAccount.id) {
            self.performLookup(searchQuery: searchQuery, accounId: currentAccount.id, isJams: true)
            return
        }
        // If conversation already exists we do not need to create temporary conversation.
        if self.isConversationExists(for: searchQuery) {
            return
        }
        /*
         For jami account perform name lookup if text to search is not contact
         hash(not SHA1 format) and return because temporary conversation will be
         added when lookup ended.
         */
        if currentAccount.type == .ring && !searchQuery.isSHA1() {
            self.performLookup(searchQuery: searchQuery, accounId: currentAccount.id, isJams: false)
            return
        }
        let tempConversation = self.createTemporaryConversation(searchQuery: searchQuery, account: currentAccount)
        self.temporaryConversationCreated(tempConversation: tempConversation)
    }

    private func performLookup(searchQuery: String, accounId: String, isJams: Bool) {
        self.searchStatus.onNext(.searching)
        // Observe username lookup.
        self.nameService.usernameLookupStatus
            .observe(on: MainScheduler.instance)
            .filter({ [weak self] responce in
                responce.name == self?.searchBarText.value
            })
            .take(1)
            .subscribe(onNext: { [weak self] lookupResponse in
                guard let self = self,
                      let account = self.accountsService.currentAccount else { return }
                guard lookupResponse.state == .found,
                      lookupResponse.name == self.searchBarText.value else {
                    self.updateSearchStatus()
                    return
                }
                if self.temporaryConversationExists(for: lookupResponse.address) {
                    return
                }
                // Username exists, create a new temporary conversation model
                let tempConversation = self.createTemporarySwarmConversation(with: lookupResponse.address, accountId: account.id, userName: lookupResponse.name)
                self.temporaryConversationCreated(tempConversation: tempConversation)
                self.updateSearchStatus()
            })
            .disposed(by: disposeBag)

        // Observe jams search results.
        self.nameService
            .userSearchResponseShared
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] nameSearchResponse in
                guard let self = self,
                      let results = nameSearchResponse.results as? [[String: String]],
                      let account = self.accountsService.currentAccount else {
                    return
                }
                // convert dictionary result to [UserSearchModel]
                let users = results.map { result in
                    return ContactsUtils.deserializeUser(dictionary: result)
                }
                .compactMap { $0 }
                // Create temporary conversations for search results.
                var jamsSearch = self.convertToConversations(from: users, accountId: account.id)
                // Filter out existing conversations (filtered results).
                jamsSearch = JamiSearchViewModel
                    .removeFilteredConversations(from: jamsSearch,
                                                 with: self.filteredResults.value)
                self.jamsTemporaryResults.accept(jamsSearch)
                self.updateSearchStatus()

            })
            .disposed(by: self.disposeBag)
        if isJams {
            self.nameService.searchUser(withAccount: accounId, query: searchQuery)
        } else {
            self.nameService.lookupName(withAccount: accounId, nameserver: "", name: searchQuery)
        }
    }

    private func cleanUpPreviousSearch() {
        self.temporaryConversationCreated(tempConversation: nil)
        self.jamsTemporaryResults.accept([])
        self.filteredResults.accept([])
    }

    private func convertToConversations(from searchModels: [JamiSearchViewModel.JamsUserSearchModel], accountId: String) -> [ConversationViewModel] {
        var jamsSearch: [ConversationViewModel] = []
        for model in searchModels {
            let newConversation = self.createTemporaryJamsConversation(with: model, accountId: accountId)
            jamsSearch.append(newConversation)
        }
        return jamsSearch
    }

    private func createTemporarySwarmConversation(with hash: String, accountId: String, userName: String? = nil) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: hash)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: accountId)
        conversation.type = .oneToOne
        let newConversation = ConversationViewModel(with: self.injectionBag)
        if let userName = userName {
            newConversation.userName.accept(userName)
        } else {
            newConversation.userName.accept(hash)
        }
        newConversation.conversation = conversation
        return newConversation
    }

    private func createTemporarySipConversation(with searchQuery: String, account: AccountModel) -> ConversationViewModel {
        let trimmed = searchQuery.trimmedSipNumber()
        let uri = JamiURI.init(schema: URIType.sip, infoHash: trimmed, account: account)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             hash: trimmed)
        conversation.type = .sip
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.userName.accept(trimmed)
        newConversation.conversation = conversation
        return newConversation
    }

    private func createTemporaryJamsConversation(with user: JamsUserSearchModel, accountId: String) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHash: user.jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId)
        conversation.type = .oneToOne
        let newConversation = ConversationViewModel(with: injectionBag,
                                                    conversation: conversation,
                                                    user: user)
        return newConversation
    }

    func showConversation(conversation: ConversationViewModel) {
        if let delegate = delegate {
            delegate.showConversation(withConversationViewModel: conversation)
        }
    }
}
