/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
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

import UIKit
import Reusable
import RxSwift
import RxCocoa
import RxDataSources

struct ContactActions {
    let title: String
    let image: ImageAsset
}

class ContactViewModel: ViewModel, Stateable {
    private let disposeBag = DisposeBag()
    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    private let contactService: ContactsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let conversationService: ConversationsService
    private let nameService: NameService
    lazy var tableSection: Observable<[SectionModel<String, ContactActions>]>  = {
        let jamiSettings =
            [SectionModel(model: "ProfileInfoCell",
                          items:
                [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                  ContactActions(title: L10n.ContactPage.startVideoCall, image: Asset.videoRunning),
                  ContactActions(title: L10n.ContactPage.sendMessage, image: Asset.conversationIcon)])]
        let sipSettings =
            [SectionModel(model: "ProfileInfoCell",
                          items:
                [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton)])]
        guard let account = self.accountService.currentAccount,
            account.type == AccountType.ring else {
                return Observable<[SectionModel<String, ContactActions>]>
                    .just(sipSettings)
        }
        return Observable<[SectionModel<String, ContactActions>]>
            .just(jamiSettings)
    }()
    var conversation: ConversationModel! {
        didSet {
            if let profile = conversation.participantProfile, let alias = profile.alias, !alias.isEmpty {
                self.displayName.value = alias
            }
            guard let account = self.accountService
                .getAccount(fromAccountId: conversation.accountId) else { return }
            if let contact = self.contactService.contact(withUri: conversation.participantUri),
                let name = contact.userName {
                self.userName.value = name
            } else {
                self.userName.value = conversation.hash
            }
            if account.type == AccountType.ring {
                self.nameService.usernameLookupStatus
                    .filter({ [weak self] lookupNameResponse in
                        return lookupNameResponse.address != nil &&
                            lookupNameResponse.address == self?.conversation.participantUri
                    })
                    .subscribe(onNext: { [weak self] lookupNameResponse in
                        guard let self = self else { return }
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self.userName.value = name
                        } else if let address = lookupNameResponse.address {
                            self.userName.value = address
                        }
                    })
                    .disposed(by: disposeBag)
                self.nameService.lookupAddress(withAccount: account.id, nameserver: "", address: conversation.hash)
            }
            // add option block contact and clear conversation if contact exists
            if self.contactService.contact(withUri: conversation.participantUri) != nil {
                if account.type == AccountType.ring {
                    self.tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                            [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                              ContactActions(title: L10n.ContactPage.startVideoCall, image: Asset.videoRunning),
                              ContactActions(title: L10n.ContactPage.sendMessage, image: Asset.conversationIcon),
                              ContactActions(title: L10n.ContactPage.clearConversation, image: Asset.clearConversation),
                              ContactActions(title: L10n.ContactPage.removeConversation, image: Asset.icConversationRemove),
                              ContactActions(title: L10n.ContactPage.blockContact, image: Asset.blockIcon)])])
                } else {
                    self.tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                            [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                              ContactActions(title: L10n.ContactPage.clearConversation, image: Asset.clearConversation),
                              ContactActions(title: L10n.ContactPage.removeConversation, image: Asset.icConversationRemove)])])
                }
            }
            self.contactService
                .getContactRequestVCard(forContactWithRingId: conversation.participantUri)
                .subscribe(onSuccess: { [weak self] vCard in
                    guard let self = self else { return }
                    if !VCardUtils.getName(from: vCard).isEmpty {
                        self.displayName.value = VCardUtils.getName(from: vCard)
                    }
                    guard let imageData = vCard.imageData else { return }
                    self.profileImageData.value = imageData
                })
                .disposed(by: self.disposeBag)
            self.profileService.getProfile(uri: conversation.participantUri,
                                           createIfNotexists: false,
                                           accountId: conversation.accountId)
                .subscribe(onNext: { [weak self] profile in
                    guard let self = self else { return }
                    if let alias = profile.alias, !alias.isEmpty {
                        self.displayName.value = alias
                    }
                    if let photo = profile.photo,
                        let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                        self.profileImageData.value = data
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    var userName = Variable<String>("")
    var displayName = Variable<String>("")
    lazy var titleName: Observable<String> = {
        return Observable.combineLatest(userName.asObservable(),
                                        displayName.asObservable()) {(userName, displayname) in
                                            if displayname.isEmpty {
                                                return userName
                                            }
                                            return displayname
        }
    }()
    var profileImageData = Variable<Data?>(nil)

    required init (with injectionBag: InjectionBag) {
        self.contactService = injectionBag.contactsService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
    }
    func startCall() {
        self.stateSubject.onNext(ConversationState
            .startCall(contactRingId: conversation.participantUri,
                       userName: self.userName.value))
    }
    func startAudioCall() {
        self.stateSubject.onNext(ConversationState
            .startAudioCall(contactRingId: conversation.participantUri,
                            userName: self.userName.value))
    }

    func deleteConversation() {
        self.conversationService
            .clearHistory(conversation: conversation,
                          keepConversation: false)
    }

    func clearConversation() {
        self.conversationService
            .clearHistory(conversation: conversation,
                          keepConversation: true)
    }

    func blockContact() {
        let contactRingId = conversation.participantUri
        let accountId = conversation.accountId
        let removeCompleted = self.contactService.removeContact(withUri: contactRingId,
                                                                ban: true,
                                                                withAccountId: accountId)
        removeCompleted.asObservable()
            .subscribe(onCompleted: { [weak self] in
                guard let self = self else { return }
                self.conversationService
                    .clearHistory(conversation: self.conversation,
                                  keepConversation: false)
            })
            .disposed(by: self.disposeBag)
    }
}
