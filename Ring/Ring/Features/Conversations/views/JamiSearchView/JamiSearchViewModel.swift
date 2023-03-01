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

    func conversationFound(conversation: ConversationViewModel?, name: String)
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel)
}

class JamiSearchViewModel {

    struct UserSearchModel {
        var username, firstName, lastName, organization, jamiId: String
        var profilePicture: Data?
    }

    let log = SwiftyBeaver.self

    // Services
    private let nameService: NameService
    private let accountsService: AccountsService
    private let injectionBag: InjectionBag

    private let disposeBag = DisposeBag()

    lazy var searchResults: Observable<[ConversationSection]> = {
        return Observable<[ConversationSection]>
            .combineLatest(self.contactFoundConversation.asObservable(),
                           self.filteredResults.asObservable(),
                           self.jamsResults.asObservable(),
                           resultSelector: { contactFoundConversation, filteredResults, jamsResults in
                            var sections = [ConversationSection]()
                            if !jamsResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: jamsResults))
                            }
                            if let contactFoundConversation = contactFoundConversation {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: [contactFoundConversation]))
                            }
                            if !filteredResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.conversations, items: filteredResults))
                            }
                            return sections
                           })
            .observe(on: MainScheduler.instance)
    }()

    private var contactFoundConversation = BehaviorRelay<ConversationViewModel?>(value: nil) // coreDialog with participant's name matcing search result
    private var filteredResults = BehaviorRelay(value: [ConversationViewModel]()) // conversation with the title containing search result or one of the participant's name containing search result
    private let jamsResults = BehaviorRelay<[ConversationViewModel]>(value: [])

    let searchBarText = BehaviorRelay<String>(value: "")
    var isSearching: Observable<Bool>!
    var searchStatus = PublishSubject<SearchStatus>()
    let dataSource: FilterConversationDataSource

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
        searchBarText.asObservable()
            .observe(on: MainScheduler.instance)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] text in
                self?.search(withText: text)
            })
            .disposed(by: disposeBag)

        // Observe username lookup
        self.nameService.usernameLookupStatus
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self, weak injectionBag] lookupResponse in
                guard let self = self,
                      let injectionBag = injectionBag,
                      let account = self.accountsService.currentAccount else { return }
                guard lookupResponse.state == .found,
                      lookupResponse.name == self.searchBarText.value else {
                    return
                }
                // check if conversation already exists
                if let conversation = self.contactFoundConversation.value,
                   conversation.model().isCoreDilaog(for: lookupResponse.name) {
                    return
                }
                // create a new temporary conversation model for search result
                let uri = JamiURI.init(schema: URIType.ring, infoHach: lookupResponse.address)
                let conversation = ConversationModel(withParticipantUri: uri, accountId: account.id)
                let newConversation = ConversationViewModel(with: injectionBag)
                newConversation.userName.accept(lookupResponse.name)
                newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
                self.contactFoundConversation.accept(newConversation)
                self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
            })
            .disposed(by: disposeBag)

        self.nameService
            .userSearchResponseShared
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] nameSearchResponse in
                guard let self = self,
                      let results = nameSearchResponse.results as? [[String: String]],
                      let account = self.accountsService.currentAccount else { return }

                let deserializeUser = { (dictionary: [String: String]) -> UserSearchModel? in
                    guard let username = dictionary["username"], let firstName = dictionary["firstName"],
                          let lastName = dictionary["lastName"], let organization = dictionary["organization"],
                          let jamiId = dictionary["id"] ?? dictionary["jamiId"], let base64Encoded = dictionary["profilePicture"]
                    else { return nil }

                    return UserSearchModel(username: username, firstName: firstName,
                                           lastName: lastName, organization: organization, jamiId: jamiId,
                                           profilePicture: NSData(base64Encoded: base64Encoded,
                                                                  options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?)
                }

                var newConversations: [ConversationViewModel] = []
                for result in results {
                    if let user = deserializeUser(result) {

                        let uri = JamiURI.init(schema: URIType.ring, infoHach: user.jamiId)
                        let conversation = ConversationModel(withParticipantUri: uri, accountId: account.id)
                        conversation.type = .jams
                        let newConversation = ConversationViewModel(with: injectionBag,
                                                                    conversation: conversation,
                                                                    user: user)
                        newConversations.append(newConversation)
                    }
                }
                newConversations = JamiSearchViewModel.removeFilteredConversations(from: newConversations,
                                                                                   with: self.filteredResults.value)
                self.jamsResults.accept(newConversations)

            })
            .disposed(by: self.disposeBag)
    }

    static func removeFilteredConversations(from conversationViewModels: [ConversationViewModel],
                                            with filteredResults: [ConversationViewModel]) -> [ConversationViewModel] {
        return conversationViewModels
            .filter({ [filteredResults] found -> Bool in
                return filteredResults
                    .first(where: { (filtered) -> Bool in
                        found.conversation.value.getParticipants()[0].jamiId == filtered.conversation.value.getParticipants()[0].jamiId
                    }) == nil
            })
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
                conversation.swarmInfo?.hasParticipantWithRegisteredName(name: text) ?? false
            })
        return contacts
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

    func getFilteredConversations(for text: String) -> [ConversationViewModel]? {
        let contacts =
            self.dataSource.conversationViewModels
            .filter({conversation in
                guard let swarmInfo = conversation.swarmInfo else { return false }
                return swarmInfo.hasParticipantWithProfileNameContains(name: text) ||
                    swarmInfo.hasParticipantWithRegisteredNameContains(name: text) ||
                    swarmInfo.title.value.contains(text)
            })
        return contacts
    }

    func performSearch(text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }
        self.cleanUpPreviousSearch()
        if text.isEmpty { return }
        if text.isSHA1() {
            if let model = self.performExactSearchForHash(for: text) {
                self.contactFoundConversation.accept(model)
            } else {
                let newConversation = createTemoraryConversation(with: text, accountId: currentAccount.id)
                searchCallback(foundConversation: newConversation, text: text)
            }
            return
        }
        if let filteredConversations = getFilteredConversations(for: text) {
            self.filteredResults.accept(filteredConversations)
        }
        if let exactConversation = performExactSearchForRegisteredName(for: text)?.first {
            self.contactFoundConversation.accept(exactConversation)
        } else {
            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
            self.searchStatus.onNext(SearchStatus.searching)
        }
    }

    private func cleanUpPreviousSearch() {
        self.contactFoundConversation.accept(nil)
        self.jamsResults.accept([])
        self.filteredResults.accept([])
        self.dataSource.conversationFound(conversation: nil, name: "")
        self.searchStatus.onNext(SearchStatus.notSearching)
    }

    private func searchCallback(foundConversation: ConversationViewModel, text: String) {
        self.contactFoundConversation.accept(foundConversation)
        self.dataSource.conversationFound(conversation: foundConversation, name: text)
    }

    private func createTemoraryConversation(with hash: String, accountId: String) -> ConversationViewModel {
        let uri = JamiURI.init(schema: URIType.ring, infoHach: hash)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: accountId)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        return newConversation
    }

    private func search(withText text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }

        self.contactFoundConversation.accept(nil)
        self.jamsResults.accept([])
        self.dataSource.conversationFound(conversation: nil, name: "")
        self.filteredResults.accept([])
        //   self.searchStatus.onNext("")

        if text.isEmpty { return }

        // Filter conversations
        let filteredConversations =
            self.dataSource.conversationViewModels
            .filter({conversationViewModel in
                conversationViewModel.conversation.value.accountId == currentAccount.id &&
                    (conversationViewModel.conversation.value.containsParticipant(participant: text) ||
                        (conversationViewModel.displayName.value ?? "").capitalized.contains(text.capitalized) || (conversationViewModel.userName.value ).capitalized.contains(text.capitalized))
            })

        if !filteredConversations.isEmpty {
            self.filteredResults.accept(filteredConversations)
        }

        if self.accountsService.isJams(for: currentAccount.id) {
            self.nameService.searchUser(withAccount: currentAccount.id, query: text)
            // self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        if currentAccount.type == AccountType.sip {
            let trimmed = text.trimmedSipNumber()
            let uri = JamiURI.init(schema: URIType.sip, infoHach: trimmed, account: currentAccount)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id,
                                                 hash: trimmed)
            conversation.type = .sip
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
            self.contactFoundConversation.accept(newConversation)
            self.dataSource.conversationFound(conversation: newConversation, name: trimmed)
            return
        }
        for currentConversation in filteredConversations where currentConversation.userName.value.capitalized == text.capitalized {
            self.contactFoundConversation.accept(currentConversation)
            return
        }

        //        for currentConversation in filteredConversations where ((currentConversation.displayName.value ?? "").capitalized == text.capitalized || currentConversation.userName.value.capitalized == text.capitalized {
        //            self.contactFoundConversation.accept(currentConversation)
        //            return
        //        }

        // check if conversation already exists
        if let existingConversation = self.contactFoundConversation.value, existingConversation.conversation.value.containsParticipant(participant: text)
            || (existingConversation.displayName.value ?? "").capitalized == text.capitalized
            || existingConversation.userName.value.capitalized == text.capitalized {
            return
        }

        if !text.isSHA1() {
            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
            // self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        let uri = JamiURI.init(schema: URIType.ring, infoHach: text)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: currentAccount.id)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
        self.contactFoundConversation.accept(newConversation)
        self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
    }

    func showConversation(conversation: ConversationViewModel) {
        dataSource.showConversation(withConversationViewModel: conversation)
    }
}
