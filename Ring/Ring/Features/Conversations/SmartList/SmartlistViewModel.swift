/*
 *  Copyright (C) 2017-2023 Savoir-faire Linux Inc.
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
import RxRelay

let smartListAccountSize: CGFloat = 28
let smartListAccountMargin: CGFloat = 4

class SmartlistViewModel: Stateable, ViewModel, FilterConversationDataSource {

    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()

    private let disposeBag = DisposeBag()
    private var tempBag = DisposeBag()

    // Services
    private let conversationsService: ConversationsService
    private let nameService: NameService
    private let accountsService: AccountsService
    private let contactsService: ContactsService
    private let networkService: NetworkService
    private let profileService: ProfilesService
    private let callService: CallsService
    private let requestsService: RequestsService

    var currentAccount: AccountModel? { self.accountsService.currentAccount }

    var searching = PublishSubject<Bool>()

    private var contactFoundConversation = BehaviorRelay<ConversationViewModel?>(value: nil)

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

    var donationBannerVisible = BehaviorRelay(value: false)

    /// For FilterConversationDataSource protocol
    var conversationViewModels = [ConversationViewModel]()

    func networkConnectionState() -> ConnectionType {
        return self.networkService.connectionState.value
    }

    let injectionBag: InjectionBag
    // Values need to be updated when selected account changed
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
                let size = smartListAccountSize - (smartListAccountMargin * 3)
                if let photo = profile.photo,
                   let data = NSData(base64Encoded: photo,
                                     options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?,
                   let image = UIImage(data: data) {
                    return image
                }
                return UIImage.defaultJamiAvatarFor(profileName: profile.alias, account: self?.accountsService.currentAccount, size: size)
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

    var accountInfoToShare: [Any]? {
        return self.accountsService.accountInfoToShare
    }

    func reloadDataFor(accountId: String) {
        tempBag = DisposeBag()
        self.profileService.getAccountProfile(accountId: accountId)
            .subscribe(onNext: { [weak self] profile in
                self?.profileImageForCurrentAccount.onNext(profile)
            })
            .disposed(by: self.tempBag)
    }

    lazy var currentAccountChanged: Observable<AccountModel?> = {
        return self.accountsService.currentAccountChanged.asObservable()
    }()

    let conversationsModel: ConversationsViewModel

    required init(with injectionBag: InjectionBag) {
        self.conversationsService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
        self.accountsService = injectionBag.accountService
        self.contactsService = injectionBag.contactsService
        self.networkService = injectionBag.networkService
        self.profileService = injectionBag.profileService
        self.callService = injectionBag.callService
        self.requestsService = injectionBag.requestsService
        self.injectionBag = injectionBag
        self.conversationsModel = ConversationsViewModel(injectionBag: injectionBag, stateSubject: self.stateSubject)
        self.updateDonationBunnerVisiblity()

        self.callService.newCall
            .asObservable()
            .observe(on: MainScheduler.instance)
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

    func getDonationBunnerVisiblity() -> Bool {
        return PreferenceManager.isDateWithinCampaignPeriod() && PreferenceManager.isCampaignEnabled()
    }

    func updateDonationBunnerVisiblity() {
        self.donationBannerVisible.accept(getDonationBunnerVisiblity())
    }

    func temporaryDisableDonationCampaign() {
        PreferenceManager.temporarilyDisableDonationCampaign()
        self.donationBannerVisible.accept(getDonationBunnerVisiblity())
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

    func showAccountSettings() {
        self.stateSubject.onNext(ConversationState.showAccountSettings)
    }

    func closeAllPlayers() {
//        self.conversationViewModels.forEach { conversationModel in
//            conversationModel.closeAllPlayers()
//        }
    }

    func isSipAccount() -> Bool {
        guard let account = self.currentAccount else { return false }
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

    func showQRCode() {
        self.stateSubject.onNext(ConversationState.qrCode)
    }
    func createGroup() {
        self.stateSubject.onNext(ConversationState.createSwarm)
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
            self.accountsService.updateCurrentAccount(account: account)
            UserDefaults.standard.set(accountId, forKey: self.accountsService.selectedAccountID)
        }
    }

    func showDialpad() {
        self.stateSubject.onNext(ConversationState.showDialpad(inCall: false))
    }

    func showGeneralSettings() {
        self.stateSubject.onNext(ConversationState.showGeneralSettings)
    }

    func openAboutJami() {
        self.stateSubject.onNext(ConversationState.openAboutJami)
    }
}

extension SmartlistViewModel: FilterConversationDelegate {
    func temporaryConversationCreated(conversation: ConversationViewModel?) {
        self.contactFoundConversation.accept(conversation)
    }

    func showConversation(withConversationViewModel conversationViewModel: ConversationViewModel) {
        self.stateSubject.onNext(ConversationState.conversationDetail(conversationViewModel:
                                                                        conversationViewModel))
    }
}
