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
import RxCocoa
import SwiftyBeaver

class SmartlistViewModel: Stateable, ViewModel, FilterConversationDataSource {

    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    //Services
    private let conversationsService: ConversationsService
    private let nameService: NameService
    private let accountsService: AccountsService
    private let contactsService: ContactsService
    private let networkService: NetworkService
    private let profileService: ProfilesService
    private let callService: CallsService

    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    var searching = PublishSubject<Bool>()

    private var contactFoundConversation = BehaviorRelay<ConversationViewModel?>(value: nil)

    lazy var hideNoConversationsMessage: Observable<Bool> = {
        return Observable<Bool>
            .combineLatest(self.conversations,
                           self.searching.asObservable().startWith(false),
                           resultSelector: {(conversations, searching) -> Bool in
                            if searching { return true }
                            if let convf = conversations.first {
                                return !convf.items.isEmpty
                            }
                            return false
            })
            .observeOn(MainScheduler.instance)
    }()

    var connectionState = PublishSubject<ConnectionType>()
    lazy var accounts: Observable<[AccountItem]> = {
        return self.accountsService
            .accountsObservable.asObservable()
            .map({ [weak self] accountsModels in
                var items = [AccountItem]()
                guard let self = self else { return items }
                for account in accountsModels {
                    items.append(AccountItem(account: account,
                                             profileObservable: self.profileService.getAccountProfile(accountId: account.id)))
                }
                return items
            })
    }()

    /// For FilterConversationDataSource protocol
    var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return self.networkService.connectionState.value
    }

    let injectionBag: InjectionBag
    //Values need to be updated when selected account changed
    var profileImageForCurrentAccount = PublishSubject<Profile>()

    lazy var profileImage: Observable<UIImage> = { [weak self] in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            if let self = self, let account = self.accountsService.currentAccount {
                self.profileService.getAccountProfile(accountId: account.id)
                    .subscribe(onNext: { profile in
                        self.profileImageForCurrentAccount.onNext(profile)
                    })
                    .disposed(by: self.tempBag)
            }
        })
        return profileImageForCurrentAccount.share()
            .map({ profile in
                if let photo = profile.photo,
                    let data = NSData(base64Encoded: photo,
                                      options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                    guard let image = UIImage(data: data) else {
                        return UIImage(asset: Asset.icContactPicture)!
                    }
                    return image
                }
                guard let account = self?.accountsService.currentAccount else {
                    return UIImage(asset: Asset.icContactPicture)!
                }
                guard let name = profile.alias else { return UIImage.defaultJamiAvatarFor(profileName: nil, account: account) }
                let profileName = name.isEmpty ? nil : name
                return UIImage.defaultJamiAvatarFor(profileName: profileName, account: account)
            })
            .startWith(UIImage(asset: Asset.icContactPicture)!)
        }()
    lazy var accountName: Observable<String> = { [weak self] in
        return profileImageForCurrentAccount.share()
            .map({ profile in
                if let alias = profile.alias {
                    if !alias.isEmpty { return alias }
                }
                guard let account = self?.accountsService.currentAccount else {
                    return ""
                }
                return account.registeredName.isEmpty ? account.jamiId : account.registeredName
            })
            .startWith("")
        }()

    lazy var conversations: Observable<[ConversationSection]> = { [weak self] in
        guard let self = self else { return Observable.empty() }
        //get initial value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: {
            self.conversationsService
                .conversationsForCurrentAccount
                .observeOn(MainScheduler.instance)
                .subscribe(onNext: { (conversations) in
                    self.conversationsForCurrentAccount.onNext(conversations)
                })
                .disposed(by: self.tempBag)
        })

        return self.conversationsForCurrentAccount.share()
            .map({ (conversations) in
                return conversations
                    .sorted(by: { conversation1, conversations2 in
                        guard let lastMessage1 = conversation1.messages.last,
                            let lastMessage2 = conversations2.messages.last else {
                                return conversation1.messages.count > conversations2.messages.count
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
                            conversationViewModel?.conversation = BehaviorRelay<ConversationModel>(value: conversationModel)
                            if let conversation = conversationViewModel {
                                self.conversationViewModels
                                    .append(conversation)
                            }
                        }
                        return conversationViewModel
                    })
            })
            .map({ conversationsViewModels in
                return [ConversationSection(header: "", items: conversationsViewModels)]
            })
        }()

    var conversationsForCurrentAccount = PublishSubject<[ConversationModel]>()

    func reloadDataFor(accountId: String) {
        tempBag = DisposeBag()
        self.profileService.getAccountProfile(accountId: accountId)
            .subscribe(onNext: { [weak self] profile in
                self?.profileImageForCurrentAccount.onNext(profile)
            })
            .disposed(by: self.tempBag)
        self.conversationsService.conversationsForCurrentAccount
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] conversations in
                self?.conversationsForCurrentAccount.onNext(conversations)
            })
            .disposed(by: self.tempBag)
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
            })
            .disposed(by: self.disposeBag)

        self.accountsService.currentAccountChanged
            .subscribe(onNext: { [weak self] account in
                if let currentAccount = account {
                    self?.reloadDataFor(accountId: currentAccount.id)
                }
            })
            .disposed(by: self.disposeBag)

        // Observe connectivity changes
        self.networkService.connectionStateObservable
            .subscribe(onNext: { [weak self] value in
                self?.connectionState.onNext(value)
            })
            .disposed(by: self.disposeBag)
    }

    /// For FilterConversationDataSource protocol
    func conversationFound(conversation: ConversationViewModel?, name: String) {
        contactFoundConversation.accept(conversation)
    }

    func delete(conversationViewModel: ConversationViewModel) {

        if let index = self.conversationViewModels.firstIndex(where: ({ cvm in
            cvm.conversation.value == conversationViewModel.conversation.value
        })) {
            conversationViewModel.closeAllPlayers()
            let contactUri = conversationViewModel.conversation.value.participantUri
            let accountId = conversationViewModel.conversation.value.accountId
            self.contactsService
                .removeContact(withUri: contactUri,
                               ban: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversationViewModel] in
                    guard let conversationViewModel = conversationViewModel else { return }
                    self?.conversationsService
                        .clearHistory(conversation: conversationViewModel.conversation.value,
                                      keepConversation: false)
                    self?.conversationViewModels.remove(at: index)
                })
                .disposed(by: self.disposeBag)
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
                })
                .disposed(by: self.disposeBag)
        }
    }

    /// For FilterConversationDataSource protocol
    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
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
        newConversation.conversation = BehaviorRelay<ConversationModel>(value: conversation)
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
            if accountsService.needAccountMigration(accountId: accountId) {
                self.stateSubject.onNext(ConversationState.needAccountMigration(accountId: accountId))
                return
            }
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
