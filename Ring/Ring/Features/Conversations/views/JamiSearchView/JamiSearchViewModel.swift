/*
 *  Copyright (C) 2020 Savoir-faire Linux Inc.
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

    func toString() -> String {
        switch self {
        case .notSearching:
            return ""
        case .searching:
            return L10n.Smartlist.searching
        case .noResult:
            return L10n.Smartlist.noResults
        }
    }
}

protocol FilterConversationDataSource {
    var conversationViewModels: [ConversationViewModel] { get set }
}

protocol FilterConversationDelegate {
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

    private var temporaryConversation = BehaviorRelay<ConversationViewModel?>(value: nil) // temporary conversation created when perform search for a new contact
    private var filteredResults = BehaviorRelay(value: [ConversationViewModel]()) // existing conversations with the title containing search result or one of the participant's name containing search result
    private let jamsTemporaryResults = BehaviorRelay<[ConversationViewModel]>(value: []) // jams temporary conversations created when perform search for a new contact

    let searchBarText = BehaviorRelay<String>(value: "")
    var isSearching: Observable<Bool>!
    var searchStatus = PublishSubject<SearchStatus>()
    private let dataSource: FilterConversationDataSource
    private var delegate: FilterConversationDelegate?

    init(with injectionBag: InjectionBag, source: FilterConversationDataSource) {
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.injectionBag = injectionBag
        self.dataSource = source

        // Observes if the user is searching
        self.isSearching = searchBarText.asObservable()
            .map({ text in
                return !text.isEmpty
            })
            .observe(on: MainScheduler.instance)

        // Observes search bar text
//        searchBarText.asObservable()
//            .observe(on: MainScheduler.instance)
//            .distinctUntilChanged()
//            .subscribe(onNext: { [weak self] text in
//                self?.search(withText: text)
//            })
//            .disposed(by: disposeBag)

        // Observe username lookup
        self.nameService.usernameLookupStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] lookupResponse in
                guard let self = self,
                      let account = self.accountsService.currentAccount else { return }
                guard lookupResponse.state == .found,
                      lookupResponse.name == self.searchBarText.value else {
                    return
                }
                // username exists, create a new temporary conversation model
                let tempConversation = self.createTemporarySwarmConversation(with: lookupResponse.address, accountId: account.id, userName: lookupResponse.name)
                self.temporaryConversationCreated(tempConversation: tempConversation)
            })
            .disposed(by: disposeBag)

        // observe jams search results
        self.nameService
            .userSearchResponseShared
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] nameSearchResponse in
                guard let self = self,
                      let results = nameSearchResponse.results as? [[String: String]],
                      let account = self.accountsService.currentAccount else { return }
                var jamsSearch: [ConversationViewModel] = []
                // convert dictionary result to [UserSearchModel]
                let users = results.map { result in
                    return ContactsUtils.deserializeUser(dictionary: result)
                }.compactMap { $0 }
                // create temporary conversations for search result
                for user in users {
                    let newConversation = self.createTemporaryJamsConversation(with: user, accountId: account.id)
                    jamsSearch.append(newConversation)
                }
                // filter out existing conversations (filtered results)
                jamsSearch = JamiSearchViewModel.removeFilteredConversations(from: jamsSearch,
                                                                             with: self.filteredResults.value)
                self.jamsTemporaryResults.accept(jamsSearch)

            })
            .disposed(by: self.disposeBag)
    }

    static func removeFilteredConversations(from conversationViewModels: [ConversationViewModel],
                                            with filteredResults: [ConversationViewModel]) -> [ConversationViewModel] {
        return conversationViewModels
            .filter({ !filteredResults.contains($0) })
    }

    func setDelegate(delegate: FilterConversationDelegate) {
        self.delegate = delegate
    }

    private func temporaryConversationCreated(tempConversation: ConversationViewModel?) {
        self.temporaryConversation.accept(tempConversation)
        if let delegate = self.delegate {
            delegate.temporaryConversationCreated(conversation: tempConversation)
        }
    }

    func performExactSearchForHash(for text: String) -> ConversationViewModel? {
        if let contact =
            self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.model().isCoreDilaog(for: text)
            }).first {
            return contact
        }
        return nil
    }

    func performExactSearchForSipHash(for text: String) -> ConversationViewModel? {
        if let contact =
            self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.model().hash == text
            }).first {
            return contact
        }
        return nil
    }

    func isSipConversationExists(for text: String) -> Bool {
        return self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.model().hash == text
            }).first != nil
    }

    func performExactSearchForProfileName(for text: String) -> [ConversationViewModel]? {
        let contacts =
            self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.swarmInfo?.hasParticipantWithProfileName(name: text) ?? false
            })
        return contacts
    }

    func performExactSearchForRegisteredName(for text: String) -> [ConversationViewModel]? {
        let contacts =
            self.dataSource.conversationViewModels
            .filter({conversation in
                if conversation.model().isSwarm() {
                    return conversation.model().isCoredialog() &&
                    conversation.swarmInfo?.hasParticipantWithRegisteredName(name: text) ?? false
                }
                return conversation.userName.value == text
            })
        return contacts
    }

    func performExactSearchForSip(for text: String) -> ConversationViewModel? {
        let contacts =
        self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.swarmInfo?.hasParticipantWithRegisteredName(name: text) ?? false
            })
        return contacts.first
    }

    func performContainsSearchForProfileName(for text: String) -> [ConversationViewModel]? {
        let contacts =
            self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.swarmInfo?.hasParticipantWithProfileNameContains(name: text) ?? false
            })
        return contacts
    }

    func performContainsSearchForRegisteredName(for text: String) -> [ConversationViewModel]? {
        let contacts =
            self.dataSource.conversationViewModels
            .filter({conversation in
                conversation.swarmInfo?.hasParticipantWithRegisteredNameContains(name: text) ?? false
            })
        return contacts
    }

    func isConversation(_ conversation: ConversationViewModel, contains text: String) -> Bool {
        /*
         For swarm conversation check if conversation title or one of the participant's
         name or jamiId contains search text. For SIP, non swarm and jams conversations
         check userName, displayName and participant hash.
         */
        if conversation.model().isSwarm() {
            guard let swarmInfo = conversation.swarmInfo else { return false }
            return swarmInfo.hasParticipantWithProfileNameContains(name: text) ||
            swarmInfo.hasParticipantWithRegisteredNameContains(name: text) ||
            swarmInfo.hasParticipantWithJamiIdContains(name: text) ||
            swarmInfo.title.value.contains(text)
        } else {
            var displayNameContainsText = false
            if let displayName = conversation.displayName.value {
                displayNameContainsText = displayName.contains(text)
            }
            var participantHashContainsText = false
            if let hash = conversation.model().getParticipants().first?.jamiId {
                participantHashContainsText = hash.contains(text)
            }
            return conversation.userName.value.contains(text) ||
            displayNameContainsText || participantHashContainsText
        }
    }

    func getFilteredConversations(for text: String) -> [ConversationViewModel]? {
        let conversations =
            self.dataSource.conversationViewModels
            .filter({conversation in
                return self.isConversation(conversation, contains: text)
            })
        return conversations
    }

    private func isConversationExists(text: String, account: AccountModel) -> Bool {
        switch account.type {
            case .sip:
                return self.isSipConversationExists(for: text)
            case .ring:
                return self.isJamiConversationExists(for: text)
        }
    }

    private func isJamiConversationExists(for text: String)  -> Bool {
        if text.isSHA1() {
            return self.dataSource.conversationViewModels
                .filter({conversation in
                    conversation.model().isCoreDilaog(for: text)
                }).first != nil
        }
        return self.dataSource.conversationViewModels
            .filter({conversation in
                if conversation.model().isSwarm() {
                    return conversation.model().isCoredialog() &&
                    conversation.swarmInfo?.hasParticipantWithRegisteredName(name: text) ?? false
                }
                return conversation.userName.value == text
            }).first != nil
    }

    private func createTemporaryConversation(text: String, account: AccountModel) -> ConversationViewModel {
        switch account.type {
            case .sip:
                return self.createTemporarySipConversation(with: text, account: account)
            case .ring:
                return self.createTemporarySwarmConversation(with: text, accountId: account.id)
        }
    }

    // Filter existing conversations, perform name lookup and create temporary conversations.
    func performSearch(text: String) {
        self.cleanUpPreviousSearch()
        if text.isEmpty { return }
        if let filteredConversations = getFilteredConversations(for: text) {
            self.filteredResults.accept(filteredConversations)
        }
        self.addTemporaryConversationsIfNeed(text: text)
    }

    private func addTemporaryConversationsIfNeed(text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }
        /*
         For jams account perform searchUser. Temporary conversations will be added
         when search result received. We should perform search even if a conversation
         already exists to get results with similar names. There why it is done before
         checking isConversationExists.
         */
        if self.accountsService.isJams(for: currentAccount.id) {
            self.nameService.searchUser(withAccount: currentAccount.id, query: text)
            return
        }
        // If conversation already exists we do not need to create temporary conversation.
        if self.isConversationExists(text: text, account: currentAccount) {
            return
        }
        /*
         For jami account perform name lookup if text to search is not contact
         hash(not SHA1 format) and return because temporary conversation will be
         added when lookup ended.
         */
        if currentAccount.type == .ring && !text.isSHA1() {
            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
            return
        }
        let tempConversation = self.createTemporaryConversation(text: text, account: currentAccount)
        self.temporaryConversationCreated(tempConversation: tempConversation)
    }

    private func cleanUpPreviousSearch() {
        self.temporaryConversationCreated(tempConversation: nil)
        self.jamsTemporaryResults.accept([])
        self.filteredResults.accept([])
    }

    private func createTemporarySwarmConversation(with hash: String, accountId: String, userName: String? = nil) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHach: hash)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: accountId)
        conversation.type = .oneToOne
        let newConversation = ConversationViewModel(with: self.injectionBag)
        if let userName = userName {
            newConversation.userName.accept(userName)
        } else {
            newConversation.userName.accept(hash)
        }
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        return newConversation
    }

    private func createTemporarySipConversation(with text: String, account: AccountModel) -> ConversationViewModel {
        let trimmed = text.trimmedSipNumber()
        let uri = JamiURI.init(schema: URIType.sip, infoHach: trimmed, account: account)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             hash: trimmed)
        conversation.type = .sip
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        return newConversation
    }

    private func createTemporaryJamsConversation(with user: JamsUserSearchModel, accountId: String) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHach: user.jamiId)
        let conversation = ConversationModel(withParticipantUri: uri, accountId: accountId)
        conversation.type = .jams
        let newConversation = ConversationViewModel(with: injectionBag,
                                                    conversation: conversation,
                                                    user: user)
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        return newConversation
    }

//    private func search(withText text: String) {
//        guard let currentAccount = self.accountsService.currentAccount else { return }
//
//        self.contactFoundConversation.accept(nil)
//        self.jamsResults.accept([])
//        self.dataSource.conversationFound(conversation: nil, name: "")
//        self.filteredResults.accept([])
//        //   self.searchStatus.onNext("")
//
//        if text.isEmpty { return }
//
//        // Filter conversations
//        let filteredConversations =
//            self.dataSource.conversationViewModels
//            .filter({conversationViewModel in
//                conversationViewModel.conversation.value.accountId == currentAccount.id &&
//                    (conversationViewModel.conversation.value.containsParticipant(participant: text) ||
//                        (conversationViewModel.displayName.value ?? "").capitalized.contains(text.capitalized) || (conversationViewModel.userName.value ).capitalized.contains(text.capitalized))
//            })
//
//        if !filteredConversations.isEmpty {
//            self.filteredResults.accept(filteredConversations)
//        }
//
//        if self.accountsService.isJams(for: currentAccount.id) {
//            self.nameService.searchUser(withAccount: currentAccount.id, query: text)
//            // self.searchStatus.onNext(L10n.Smartlist.searching)
//            return
//        }
//
//        if currentAccount.type == AccountType.sip {
//            let trimmed = text.trimmedSipNumber()
//            let uri = JamiURI.init(schema: URIType.sip, infoHach: trimmed, account: currentAccount)
//            let conversation = ConversationModel(withParticipantUri: uri,
//                                                 accountId: currentAccount.id,
//                                                 hash: trimmed)
//            conversation.type = .sip
//            let newConversation = ConversationViewModel(with: self.injectionBag)
//            newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
//            self.contactFoundConversation.accept(newConversation)
//            self.dataSource.conversationFound(conversation: newConversation, name: trimmed)
//            return
//        }
//        for currentConversation in filteredConversations where currentConversation.userName.value.capitalized == text.capitalized {
//            self.contactFoundConversation.accept(currentConversation)
//            return
//        }
//
//        //        for currentConversation in filteredConversations where ((currentConversation.displayName.value ?? "").capitalized == text.capitalized || currentConversation.userName.value.capitalized == text.capitalized {
//        //            self.contactFoundConversation.accept(currentConversation)
//        //            return
//        //        }
//
//        // check if conversation already exists
//        if let existingConversation = self.contactFoundConversation.value, existingConversation.conversation.value.containsParticipant(participant: text)
//            || (existingConversation.displayName.value ?? "").capitalized == text.capitalized
//            || existingConversation.userName.value.capitalized == text.capitalized {
//            return
//        }
//
//        if !text.isSHA1() {
//            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
//            // self.searchStatus.onNext(L10n.Smartlist.searching)
//            return
//        }
//
//        let uri = JamiURI.init(schema: URIType.ring, infoHach: text)
//        let conversation = ConversationModel(withParticipantUri: uri,
//                                             accountId: currentAccount.id)
//        let newConversation = ConversationViewModel(with: self.injectionBag)
//        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
//        self.contactFoundConversation.accept(newConversation)
//        self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
//    }

    func showConversation(conversation: ConversationViewModel) {
        if let delegate = delegate {
            delegate.showConversation(withConversationViewModel: conversation)
        }
    }
}
