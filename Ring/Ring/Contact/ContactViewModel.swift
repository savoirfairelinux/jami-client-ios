/*
 * Copyright (C) 2018-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
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
    lazy var tableSection: Observable<[SectionModel<String, ContactActions>]> = {
        let jamiSettings =
            [SectionModel(model: "ProfileInfoCell",
                          items:
                            [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                              ContactActions(title: L10n.ContactPage.startVideoCall, image: Asset.videoRunning),
                              ContactActions(title: L10n.ContactPage.send, image: Asset.conversationIcon)])]
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
            guard let account = self.accountService
                    .getAccount(fromAccountId: conversation.accountId),
                  let jamiId = conversation.getParticipants().first?.jamiId else { return }
            if let contact = self.contactService.contact(withHash: jamiId) {
                if let name = contact.userName {
                    self.userName.accept(name)
                } else {
                    self.userName.accept(jamiId)
                }
                if account.type == AccountType.ring {
                    self.tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                                                [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                                                  ContactActions(title: L10n.ContactPage.startVideoCall, image: Asset.videoRunning),
                                                  ContactActions(title: L10n.ContactPage.send, image: Asset.conversationIcon),
                                                  ContactActions(title: L10n.ContactPage.leaveConversation, image: Asset.icConversationLeave),
                                                  ContactActions(title: L10n.Global.blockContact, image: Asset.blockIcon)])])
                } else {
                    self.tableSection = Observable<[SectionModel<String, ContactActions>]>
                        .just([SectionModel(model: "ProfileInfoCell",
                                            items:
                                                [ ContactActions(title: L10n.ContactPage.startAudioCall, image: Asset.callButton),
                                                  ContactActions(title: L10n.ContactPage.leaveConversation, image: Asset.icConversationLeave)])])
                }
            } else {
                self.userName.accept(jamiId)
            }
            if account.type == AccountType.ring && self.userName.value == jamiId {
                self.nameService.usernameLookupStatus
                    .filter({lookupNameResponse in
                        return lookupNameResponse.requestedName != nil &&
                            lookupNameResponse.requestedName == jamiId
                    })
                    .subscribe(onNext: { [weak self] lookupNameResponse in
                        if let name = lookupNameResponse.name, !name.isEmpty {
                            self?.userName.accept(name)
                        } else if let address = lookupNameResponse.requestedName {
                            self?.userName.accept(address)
                        }
                    })
                    .disposed(by: disposeBag)
                self.nameService.lookupAddress(withAccount: account.id, nameserver: "", address: jamiId)
            }
            let schema: URIType = account.type == .sip ? .sip : .ring
            guard let contactURI = JamiURI(schema: schema, infoHash: jamiId).uriString else { return }
            var initialProfile = Profile(uri: jamiId, alias: "", photo: "", type: schema.getString())
            if let profile = self.contactService.getProfile(uri: contactURI, accountId: conversation.accountId) {
                initialProfile = profile
            }
            self.profileService.getProfile(uri: contactURI,
                                           createIfNotexists: false,
                                           accountId: conversation.accountId)
                .startWith(initialProfile)
                .subscribe(onNext: { [weak self] profile in
                    guard let self = self else { return }
                    if let alias = profile.alias, !alias.isEmpty {
                        self.displayName.accept(alias)
                    }
                    if let data = profile.photo?.toImageData() {
                        self.profileImageData.accept(data)
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    var userName = BehaviorRelay<String>(value: "")
    var displayName = BehaviorRelay<String>(value: "")
    lazy var titleName: Observable<String> = {
        return Observable.combineLatest(userName.asObservable(),
                                        displayName.asObservable()) {(userName, displayname) in
            if displayname.isEmpty {
                return userName
            }
            return displayname
        }
    }()
    var profileImageData = BehaviorRelay<Data?>(value: nil)

    required init (with injectionBag: InjectionBag) {
        self.contactService = injectionBag.contactsService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.conversationService = injectionBag.conversationsService
        self.nameService = injectionBag.nameService
    }
    func startCall() {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        self.stateSubject.onNext(ConversationState
                                    .startCall(contactRingId: jamiId,
                                               userName: self.userName.value))
    }
    func startAudioCall() {
        guard let jamiId = self.conversation.getParticipants().first?.jamiId else { return }
        self.stateSubject.onNext(ConversationState
                                    .startAudioCall(contactRingId: jamiId,
                                                    userName: self.userName.value))
    }

    func deleteConversation() {
        let accountId = conversation.accountId
        let conversationId = conversation.id
        if conversation.isCoredialog(),
           let participantId = conversation.getParticipants().first?.jamiId {
            self.contactService
                .removeContact(withId: participantId,
                               block: false,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversation] in
                    guard let conversation = conversation,
                          let self = self else { return }
                    self.conversationService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                    self.stateSubject.onNext(ConversationState
                                                .conversationRemoved)
                })
                .disposed(by: self.disposeBag)
        } else {
            self.conversationService.removeConversation(conversationId: conversationId, accountId: accountId)
            self.stateSubject.onNext(ConversationState
                                        .conversationRemoved)
        }
    }

    func blockContact() {
        let accountId = conversation.accountId
        let conversationId = conversation.id
        if conversation.isCoredialog(),
           let participantId = conversation.getParticipants().first?.jamiId {
            self.contactService
                .removeContact(withId: participantId,
                               block: true,
                               withAccountId: accountId)
                .asObservable()
                .subscribe(onCompleted: { [weak self, weak conversation] in
                    guard let conversation = conversation,
                          let self = self else { return }
                    self.conversationService
                        .removeConversationFromDB(conversation: conversation,
                                                  keepConversation: false)
                    self.stateSubject.onNext(ConversationState
                                                .conversationRemoved)
                })
                .disposed(by: self.disposeBag)
        } else {
            self.conversationService.removeConversation(conversationId: conversationId, accountId: accountId)
            self.stateSubject.onNext(ConversationState
                                        .conversationRemoved)
        }
    }
}
