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

import Reusable
import RxCocoa
import RxDataSources
import RxSwift
import UIKit

struct ContactActions {
    let title: String
    let image: ImageAsset
}

class ContactViewModel: ViewModel, Stateable {
    private let disposeBag = DisposeBag()

    // MARK: - Rx Stateable

    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = self.stateSubject.asObservable()

    private let contactService: ContactsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let conversationService: ConversationsService
    private let nameService: NameService
    lazy var tableSection: Observable<[SectionModel<String, ContactActions>]> = {
        let jamiSettings =
            [SectionModel(model: "ProfileInfoCell",
                          items:
                            [
                                ContactActions(
                                    title: L10n.ContactPage.startAudioCall,
                                    image: Asset.callButton
                                ),
                                ContactActions(
                                    title: L10n.ContactPage.startVideoCall,
                                    image: Asset.videoRunning
                                ),
                                ContactActions(
                                    title: L10n.ContactPage.sendMessage,
                                    image: Asset.conversationIcon
                                )
                            ])]
        let sipSettings =
            [SectionModel(model: "ProfileInfoCell",
                          items:
                            [ContactActions(
                                title: L10n.ContactPage.startAudioCall,
                                image: Asset.callButton
                            )])]
        guard let account = self.accountService.currentAccount,
              account.type == AccountType.ring
        else {
            return Observable<[SectionModel<String, ContactActions>]>
                .just(sipSettings)
        }
        return Observable<[SectionModel<String, ContactActions>]>
            .just(jamiSettings)
    }()

    var conversation: ConversationModel! {
        didSet {
            guard let account = accountService
                    .getAccount(fromAccountId: conversation.accountId),
                  let jamiId = conversation.getParticipants().first?.jamiId else { return }
            if let contact = contactService.contact(withHash: jamiId) {
                if let name = contact.userName {
                    userName.accept(name)
                } else {
                    userName.accept(jamiId)
                }
                if account.type == AccountType.ring {
                    tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                                                [
                                                    ContactActions(
                                                        title: L10n.ContactPage.startAudioCall,
                                                        image: Asset.callButton
                                                    ),
                                                    ContactActions(
                                                        title: L10n.ContactPage.startVideoCall,
                                                        image: Asset.videoRunning
                                                    ),
                                                    ContactActions(
                                                        title: L10n.ContactPage.sendMessage,
                                                        image: Asset.conversationIcon
                                                    ),
                                                    ContactActions(
                                                        title: L10n.ContactPage.removeConversation,
                                                        image: Asset.icConversationRemove
                                                    ),
                                                    ContactActions(
                                                        title: L10n.Global.blockContact,
                                                        image: Asset.blockIcon
                                                    )
                                                ])])
                } else {
                    tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                                                [
                                                    ContactActions(
                                                        title: L10n.ContactPage.startAudioCall,
                                                        image: Asset.callButton
                                                    ),
                                                    ContactActions(
                                                        title: L10n.ContactPage.removeConversation,
                                                        image: Asset.icConversationRemove
                                                    )
                                                ])])
                }
            } else {
                userName.accept(jamiId)
            }
            if account.type == AccountType.ring && userName.value == jamiId {
                nameService.usernameLookupStatus
                    .filter { lookupNameResponse in
                        lookupNameResponse.address != nil &&
                            lookupNameResponse.address == jamiId
                    }
                    .subscribe(onNext: { [weak self] lookupNameResponse in
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self?.userName.accept(name)
                        } else if let address = lookupNameResponse.address {
                            self?.userName.accept(address)
                        }
                    })
                    .disposed(by: disposeBag)
                nameService.lookupAddress(withAccount: account.id, nameserver: "", address: jamiId)
            }
            let schema: URIType = account.type == .sip ? .sip : .ring
            guard let contactURI = JamiURI(schema: schema, infoHash: jamiId).uriString
            else { return }
            var initialProfile = Profile(
                uri: jamiId,
                alias: "",
                photo: "",
                type: schema.getString()
            )
            if let profile = contactService.getProfile(
                uri: contactURI,
                accountId: conversation.accountId
            ) {
                initialProfile = profile
            }
            profileService.getProfile(uri: contactURI,
                                      createIfNotexists: false,
                                      accountId: conversation.accountId)
                .startWith(initialProfile)
                .subscribe(onNext: { [weak self] profile in
                    guard let self = self else { return }
                    if let alias = profile.alias, !alias.isEmpty {
                        self.displayName.accept(alias)
                    }
                    if let photo = profile.photo,
                       let data = NSData(
                        base64Encoded: photo,
                        options: NSData.Base64DecodingOptions.ignoreUnknownCharacters
                       ) as Data? {
                        self.profileImageData.accept(data)
                    }
                })
                .disposed(by: disposeBag)
        }
    }

    var userName = BehaviorRelay<String>(value: "")
    var displayName = BehaviorRelay<String>(value: "")
    lazy var titleName: Observable<String> = Observable.combineLatest(userName.asObservable(),
                                                                      displayName.asObservable(
                                                                      )) { userName, displayname in
        if displayname.isEmpty {
            return userName
        }
        return displayname
    }

    var profileImageData = BehaviorRelay<Data?>(value: nil)

    required init(with injectionBag: InjectionBag) {
        contactService = injectionBag.contactsService
        profileService = injectionBag.profileService
        accountService = injectionBag.accountService
        conversationService = injectionBag.conversationsService
        nameService = injectionBag.nameService
    }

    func startCall() {
        guard let jamiId = conversation.getParticipants().first?.jamiId else { return }
        stateSubject.onNext(ConversationState
                                .startCall(contactRingId: jamiId,
                                           userName: userName.value))
    }

    func startAudioCall() {
        guard let jamiId = conversation.getParticipants().first?.jamiId else { return }
        stateSubject.onNext(ConversationState
                                .startAudioCall(contactRingId: jamiId,
                                                userName: userName.value))
    }

    func deleteConversation() {
        let accountId = conversation.accountId
        let conversationId = conversation.id
        if conversation.isCoredialog(),
           let participantId = conversation.getParticipants().first?.jamiId {
            contactService
                .removeContact(withId: participantId,
                               ban: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversation] in
                    guard let conversation = conversation,
                          let self = self else { return }
                    self.conversationService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                    self.stateSubject.onNext(ConversationState
                                                .returnToSmartList)
                })
                .disposed(by: disposeBag)
        } else {
            conversationService.removeConversation(
                conversationId: conversationId,
                accountId: accountId
            )
            stateSubject.onNext(ConversationState
                                    .returnToSmartList)
        }
    }

    func blockContact() {
        let accountId = conversation.accountId
        let conversationId = conversation.id
        if conversation.isCoredialog(),
           let participantId = conversation.getParticipants().first?.jamiId {
            contactService
                .removeContact(withId: participantId,
                               ban: true,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversation] in
                    guard let conversation = conversation,
                          let self = self else { return }
                    self.conversationService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                    self.stateSubject.onNext(ConversationState
                                                .returnToSmartList)
                })
                .disposed(by: disposeBag)
        } else {
            conversationService.removeConversation(
                conversationId: conversationId,
                accountId: accountId
            )
            stateSubject.onNext(ConversationState
                                    .returnToSmartList)
        }
    }
}
