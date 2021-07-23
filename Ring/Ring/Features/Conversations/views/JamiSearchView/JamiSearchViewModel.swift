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

protocol FilterConversationDataSource {
    var conversationViewModels: [ConversationViewModel] { get set }

    func conversationFound(conversation: ConversationViewModel?, name: String)
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel)
}

class JamiSearchViewModel {

    typealias UserSearchModel = (username: String, firstName: String, lastName: String, organization: String, jamiId: String, profilePicture: Data?)

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
                            let jamsResults = JamiSearchViewModel.removeFilteredConversations(from: jamsResults,
                                                                                              with: filteredResults)
                            if !jamsResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: jamsResults))
                            } else if contactFoundConversation != nil {
                                let contactFoundConversation = JamiSearchViewModel.removeFilteredConversations(from: [contactFoundConversation!],
                                                                                                               with: filteredResults)
                                if !contactFoundConversation.isEmpty {
                                    sections.append(ConversationSection(header: L10n.Smartlist.results, items: contactFoundConversation))
                                }
                            }
                            if !filteredResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.conversations, items: filteredResults))
                            }
                            return sections
            })
            .observe(on: MainScheduler.instance)
    }()

    private var contactFoundConversation = BehaviorRelay<ConversationViewModel?>(value: nil)
    private var filteredResults = BehaviorRelay(value: [ConversationViewModel]())
    private let jamsResults = BehaviorRelay<[ConversationViewModel]>(value: [])

    let searchBarText = BehaviorRelay<String>(value: "")
    var isSearching: Observable<Bool>!
    var searchStatus = PublishSubject<String>()
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
                guard let self = self else { return }
                if lookupResponse.state == .found && (lookupResponse.name == self.searchBarText.value || lookupResponse.address == self.searchBarText.value) {
                    if let conversation = self.dataSource.conversationViewModels
                                                          .filter({ conversationViewModel in
                                                              conversationViewModel.conversation.value.participantUri == lookupResponse.address ||
                                                              conversationViewModel.conversation.value.hash == lookupResponse.address }).first {
                        self.contactFoundConversation.accept(conversation)
                        self.dataSource.conversationFound(conversation: conversation, name: self.searchBarText.value)

                    } else if self.contactFoundConversation.value?.conversation.value.participantUri != lookupResponse.address &&
                        self.contactFoundConversation.value?.conversation.value.hash != lookupResponse.address,
                        let account = self.accountsService.currentAccount,
                        let injectionBag = injectionBag {

                        let uri = JamiURI.init(schema: URIType.ring, infoHach: lookupResponse.address)
                        // Create new converation
                        let conversation = ConversationModel(withParticipantUri: uri, accountId: account.id)
                        let newConversation = ConversationViewModel(with: injectionBag)
                        if lookupResponse.name == self.searchBarText.value {
                            newConversation.userName.accept(lookupResponse.name)
                        }
                        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
                        self.contactFoundConversation.accept(newConversation)
                        self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
                    }
                    self.searchStatus.onNext("")
                } else {
                    if self.filteredResults.value.isEmpty && self.contactFoundConversation.value == nil {
                        self.searchStatus.onNext(L10n.Smartlist.noResults)
                    } else {
                        self.searchStatus.onNext("")
                    }
                }
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
                        let newConversation = ConversationViewModel(with: injectionBag,
                                                                    conversation: ConversationModel(withParticipantUri: uri, accountId: account.id),
                                                                    user: user)
                        newConversations.append(newConversation)
                    }
                }
                self.jamsResults.accept(newConversations)

                if self.filteredResults.value.isEmpty && self.jamsResults.value.isEmpty {
                    self.searchStatus.onNext(L10n.Smartlist.noResults)
                } else {
                    self.searchStatus.onNext("")
                }
            })
            .disposed(by: self.disposeBag)
    }

    static func removeFilteredConversations(from conversationViewModels: [ConversationViewModel],
                                            with filteredResults: [ConversationViewModel]) -> [ConversationViewModel] {
        return conversationViewModels
            .filter({ [filteredResults] found -> Bool in
                return filteredResults
                    .first(where: { (filtered) -> Bool in
                        found.conversation.value.participantUri == filtered.conversation.value.participantUri
                    }) == nil
            })
    }

    private func search(withText text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }

        self.contactFoundConversation.accept(nil)
        self.jamsResults.accept([])
        self.dataSource.conversationFound(conversation: nil, name: "")
        self.filteredResults.accept([])
        self.searchStatus.onNext("")

        if text.isEmpty { return }

        // Filter conversations
        let filteredConversations =
            self.dataSource.conversationViewModels
                .filter({conversationViewModel in
                    conversationViewModel.conversation.value.accountId == currentAccount.id &&
                        (conversationViewModel.conversation.value.participantUri == text ||
                            conversationViewModel.conversation.value.hash == text ||
                            conversationViewModel.userName.value.capitalized.contains(text.capitalized) ||
                            (conversationViewModel.displayName.value ?? "").capitalized.contains(text.capitalized))
                })

        if !filteredConversations.isEmpty {
            self.filteredResults.accept(filteredConversations)
        }

        if self.accountsService.isJams(for: currentAccount.id) {
            self.nameService.searchUser(withAccount: currentAccount.id, query: text)
            self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        if currentAccount.type == AccountType.sip {
            let trimmed = text.trimmedSipNumber()
            let uri = JamiURI.init(schema: URIType.sip, infoHach: trimmed, account: currentAccount)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id,
                                                 hash: trimmed)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
            self.contactFoundConversation.accept(newConversation)
            self.dataSource.conversationFound(conversation: newConversation, name: trimmed)
            return
        }

        if !text.isSHA1() {
            self.nameService.lookupName(withAccount: currentAccount.id, nameserver: "", name: text)
            self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        if self.contactFoundConversation.value?.conversation.value.participantUri != text && self.contactFoundConversation.value?.conversation.value.hash != text {
            let uri = JamiURI.init(schema: URIType.ring, infoHach: text)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
            self.contactFoundConversation.accept(newConversation)
            self.dataSource.conversationFound(conversation: newConversation, name: self.searchBarText.value)
        }
    }

    func showConversation(conversation: ConversationViewModel) {
        dataSource.showConversation(withConversationViewModel: conversation)
    }
}
