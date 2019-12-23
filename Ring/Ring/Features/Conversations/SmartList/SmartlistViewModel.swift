/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

import RxSwift
import SwiftyBeaver

// swiftlint:disable type_body_length
class SmartlistViewModel: Stateable, ViewModel {

    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    fileprivate let disposeBag = DisposeBag()
    fileprivate var tempBag = DisposeBag()

    //Services
    fileprivate let conversationsService: ConversationsService
    fileprivate let nameService: NameService
    fileprivate let accountsService: AccountsService
    fileprivate let contactsService: ContactsService
    fileprivate let networkService: NetworkService
    fileprivate let profileService: ProfilesService
    fileprivate let callService: CallsService

    let searchBarText = Variable<String>("")
    var isSearching: Observable<Bool>!
    lazy var currentAccount: AccountModel? = {
        return self.accountsService.currentAccount
    }()
    lazy var searchResults: Observable<[ConversationSection]> = { [unowned self] in
        return Observable<[ConversationSection]>
            .combineLatest(self.contactFoundConversation
                .asObservable(),
                           self.filteredResults.asObservable(),
                           resultSelector: { contactFoundConversation, filteredResults in

                            var sections = [ConversationSection]()
                            if !filteredResults.isEmpty {
                                sections.append(ConversationSection(header: L10n.Smartlist.conversations, items: filteredResults))
                            } else if contactFoundConversation != nil {
                                sections.append(ConversationSection(header: L10n.Smartlist.results, items: [contactFoundConversation!]))
                            }

                            return sections
            }).observeOn(MainScheduler.instance)
    }()
    lazy var hideNoConversationsMessage: Observable<Bool> = { [unowned self] in
        return Observable<Bool>
            .combineLatest(self.conversations, self.searchBarText.asObservable(),
                           resultSelector: {(conversations, searchBarText) -> Bool in
                            if !searchBarText.isEmpty {return true}
                            if let convf = conversations.first {
                                return !convf.items.isEmpty
                            }
                            return false
            }).observeOn(MainScheduler.instance)
    }()

    var searchStatus = PublishSubject<String>()
    var connectionState = PublishSubject<ConnectionType>()
    lazy var accounts: Observable<[AccountItem]> = { [unowned self] in
        return self.accountsService
            .accountsObservable.asObservable()
            .map({ accountsModels in
            var items = [AccountItem]()
            for account in accountsModels {
                items.append(AccountItem(account: account,
                                         profileObservable: self.profileService.getAccountProfile(accountId: account.id)))
            }
            return items
        })
    }()

    fileprivate var filteredResults = Variable([ConversationViewModel]())
    fileprivate var contactFoundConversation = Variable<ConversationViewModel?>(nil)
    fileprivate var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return self.networkService.connectionState.value
    }
    let injectionBag: InjectionBag
    //Values need to be updated when selected account changed
    var profileImageForCurrentAccount = PublishSubject<AccountProfile>()

    lazy var profileImage: Observable<UIImage> = { [unowned self] in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            if let account = self.accountsService.currentAccount {
                self.profileService.getAccountProfile(accountId: account.id)
                    .subscribe(onNext: { profile in
                        self.profileImageForCurrentAccount.onNext(profile)
                    }).disposed(by: self.tempBag)
            }
        })
        return profileImageForCurrentAccount.share()
            .map({ profile in
                if let photo = profile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    guard let image = UIImage(data: data) else {
                        return UIImage(asset: Asset.icContactPicture)
                    }
                    return image
                }
                guard let account = self.accountsService.currentAccount else {
                    return UIImage(asset: Asset.icContactPicture)
                }
                guard let name = profile.alias else {return UIImage.defaultJamiAvatarFor(profileName: nil, account: account)}
                let profileName = name.isEmpty ? nil : name
                return UIImage.defaultJamiAvatarFor(profileName: profileName, account: account)
            })
        }()

    lazy var conversations: Observable<[ConversationSection]> = { [unowned self] in
        //get initial value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            self.conversationsService
                .conversationsForCurrentAccount
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { (conversations) in
                    self.conversationsForCurrentAccount.onNext(conversations)
                }).disposed(by: self.tempBag)
        })

        return self.conversationsForCurrentAccount.share().map({ (conversations) in
            return conversations
                .sorted(by: { conversation1, conversations2 in
                    guard let lastMessage1 = conversation1.messages.last,
                        let lastMessage2 = conversations2.messages.last else {
                            return true
                    }
                    return lastMessage1.receivedDate > lastMessage2.receivedDate
                })
                .filter({ self.contactsService.contact(withUri: $0.participantUri) != nil
                    || (!$0.messages.isEmpty &&
                        (self.contactsService.contactRequest(withRingId: $0.hash) == nil))
                })
                .compactMap({ conversationModel in

                    var conversationViewModel: ConversationViewModel?
                    if let foundConversationViewModel = self.conversationViewModels.filter({ conversationViewModel in
                        return conversationViewModel.conversation.value == conversationModel
                    }).first {
                        conversationViewModel = foundConversationViewModel
                    } else if let contactFound = self.contactFoundConversation.value, contactFound.conversation.value == conversationModel {
                        conversationViewModel = contactFound
                        self.conversationViewModels.append(contactFound)
                    } else {
                        conversationViewModel = ConversationViewModel(with: self.injectionBag)
                        conversationViewModel?.conversation = Variable<ConversationModel>(conversationModel)
                        if let conversation = conversationViewModel {
                            self.conversationViewModels
                                .append(conversation)
                        }
                    }
                    return conversationViewModel
                })
        }).map({ conversationsViewModels in
            return [ConversationSection(header: "", items: conversationsViewModels)]
        })
        }()

    var conversationsForCurrentAccount = PublishSubject<[ConversationModel]>()

    func reloadDataFor(accountId: String) {
        tempBag = DisposeBag()
        self.profileService.getAccountProfile(accountId: accountId)
            .subscribe(onNext: { [unowned self] profile in
                self.profileImageForCurrentAccount.onNext(profile)
            }).disposed(by: self.tempBag)
        self.conversationsService.conversationsForCurrentAccount
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] conversations in
                self.conversationsForCurrentAccount.onNext(conversations)
            }).disposed(by: self.tempBag)
    }

    lazy var currentAccountChanged: Observable<AccountModel?> = {
        return self.accountsService.currentAccountChanged.asObservable()
    }()

    required init(with injectionBag: InjectionBag) {
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.networkService = injectionBag.networkService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.injectionBag = injectionBag

        self.callService.newCall
        .asObservable()
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] _ in
            self?.closeAllPlayers()
        }).disposed(by: self.disposeBag)

        self.accountsService.currentAccountChanged
            .subscribe(onNext: { [unowned self] account in
                if let currentAccount = account {
                    self.reloadDataFor(accountId: currentAccount.id)
                }
            }).disposed(by: self.disposeBag)

        // Observe connectivity changes
        self.networkService.connectionStateObservable
            .subscribe(onNext: { [unowned self] value in
                self.connectionState.onNext(value)
            })
            .disposed(by: self.disposeBag)

        //Observes if the user is searching
        self.isSearching = searchBarText.asObservable()
            .map({ text in
            return !text.isEmpty
        }).observeOn(MainScheduler.instance)

        //Observes search bar text
        searchBarText.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self] text in
            self.search(withText: text)
        }).disposed(by: disposeBag)

        //Observe username lookup
        self.nameService.usernameLookupStatus
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [unowned self, unowned injectionBag] usernameLookupStatus in
                if usernameLookupStatus.state == .found &&
                    (usernameLookupStatus.name == self.searchBarText.value
                        || usernameLookupStatus.address == self.searchBarText.value) {
                    if let conversation = self.conversationViewModels.filter({ conversationViewModel in
                        conversationViewModel.conversation.value.participantUri == usernameLookupStatus.address || conversationViewModel.conversation.value.hash == usernameLookupStatus.address
                    }).first {
                        self.contactFoundConversation.value = conversation
                    } else {
                        if self.contactFoundConversation.value?.conversation.value
                            .participantUri != usernameLookupStatus.address && self.contactFoundConversation.value?.conversation.value
                                .hash != usernameLookupStatus.address {
                            if let account = self.accountsService.currentAccount {
                                let uri = JamiURI.init(schema: URIType.ring, infoHach: usernameLookupStatus.address)
                                //Create new converation
                                let conversation = ConversationModel(withParticipantUri: uri, accountId: account.id)
                                let newConversation = ConversationViewModel(with: injectionBag)
                                newConversation.conversation = Variable<ConversationModel>(conversation)
                                self.contactFoundConversation.value = newConversation
                            }
                        }
                    }
                    self.searchStatus.onNext("")
                } else {
                    if self.filteredResults.value.isEmpty
                        && self.contactFoundConversation.value == nil {
                        self.searchStatus.onNext(L10n.Smartlist.noResults)
                    } else {
                        self.searchStatus.onNext("")
                    }
                }
            }).disposed(by: disposeBag)
    }

    fileprivate func search(withText text: String) {
        guard let currentAccount = self.accountsService.currentAccount else { return }

        self.contactFoundConversation.value = nil
        self.filteredResults.value.removeAll()
        self.searchStatus.onNext("")

        if text.isEmpty {return}

        //Filter conversations
        let filteredConversations = self.conversationViewModels
            .filter({conversationViewModel in
                conversationViewModel.conversation.value.participantUri == text
                || conversationViewModel.conversation.value.hash == text
            })

        if !filteredConversations.isEmpty {
            self.filteredResults.value = filteredConversations
        }

        if currentAccount.type == AccountType.sip {
            let uri = JamiURI.init(schema: URIType.sip, infoHach: text, account: currentAccount)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id,
                                                 hash: text)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = Variable<ConversationModel>(conversation)
            self.contactFoundConversation.value = newConversation
            return
        }

        if !text.isSHA1() {
            self.nameService.lookupName(withAccount: "", nameserver: "", name: text)
            self.searchStatus.onNext(L10n.Smartlist.searching)
            return
        }

        if self.contactFoundConversation.value?.conversation.value.participantUri != text && self.contactFoundConversation.value?.conversation.value.hash != text {
            let uri = JamiURI.init(schema: URIType.ring, infoHach: text)
            let conversation = ConversationModel(withParticipantUri: uri,
                                                 accountId: currentAccount.id)
            let newConversation = ConversationViewModel(with: self.injectionBag)
            newConversation.conversation = Variable<ConversationModel>(conversation)
            self.contactFoundConversation.value = newConversation
        }
    }

    func delete(conversationViewModel: ConversationViewModel) {

        if let index = self.conversationViewModels.firstIndex(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {
            conversationViewModel.closeAllPlayers()

            self.conversationsService
                .clearHistory(conversation: conversationViewModel.conversation.value,
                              keepConversation: false)
            self.conversationViewModels.remove(at: index)
        }
    }

    func clear(conversationViewModel: ConversationViewModel) {

        if let index = self.conversationViewModels.firstIndex(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {
            conversationViewModel.closeAllPlayers()

            self.conversationsService
                .clearHistory(conversation: conversationViewModel.conversation.value,
                                    keepConversation: true)
            self.conversationViewModels.remove(at: index)
        }
    }

    func blockConversationsContact(conversationViewModel: ConversationViewModel) {
        if let index = self.conversationViewModels.firstIndex(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {
            conversationViewModel.closeAllPlayers()
            let contactUri = conversationViewModel.conversation.value.participantUri
            let accountId = conversationViewModel.conversation.value.accountId
            let removeCompleted = self.contactsService.removeContact(withUri: contactUri,
                                                                     ban: true,
                                                                     withAccountId: accountId)
            removeCompleted.asObservable()
                .subscribe(onCompleted: { [weak self] in
                    self?.conversationsService
                        .clearHistory(conversation: conversationViewModel.conversation.value,
                                            keepConversation: false)
                    self?.conversationViewModels.remove(at: index)
                }).disposed(by: self.disposeBag)
        }
    }

    func showConversation (withConversationViewModel conversationViewModel: ConversationViewModel) {
        //close players for other conversations
        closeAllPlayers()
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
        conversationViewModel))
    }

    func closeAllPlayers() {
        self.conversationViewModels.forEach { (conversationModel) in
            conversationModel.closeAllPlayers()
        }
    }

    func showSipConversation(withNumber number: String) {
        guard let account = self.accountsService
            .currentAccount else {
                return
        }
        let uri = JamiURI.init(schema: URIType.sip,
                               infoHach: number,
                               account: account)
        let conversation = ConversationModel(withParticipantUri: uri,
                                             accountId: account.id,
                                             hash: number)
        let newConversation = ConversationViewModel(with: self.injectionBag)
        newConversation.conversation = Variable<ConversationModel>(conversation)
        self.stateSubject
            .onNext(ConversationState
                .conversationDetail(conversationViewModel:
                    newConversation))
    }

    func showQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }

    func createAccount() {
        self.stateSubject.onNext(ConversationState.createNewAccount)
    }

    func changeCurrentAccount(accountId: String) {
        if let account = self.accountsService.getAccount(fromAccountId: accountId) {
            self.accountsService.currentAccount = account
            UserDefaults.standard.set(accountId, forKey: self.accountsService.selectedAccountID)
        }
    }

    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: false))
    }

    func showGeneralSettings() {
        self.stateSubject.onNext(ConversationState.showGeneralSettings)
    }
}
