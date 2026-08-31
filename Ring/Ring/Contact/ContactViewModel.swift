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

enum ContactInfoAction: Equatable {
    case audioCall
    case videoCall
    case editProfile
    case sendMessage
    case leaveConversation
    case blockContact
}

struct ContactActions {
    let kind: ContactInfoAction
    let title: String
    let image: UIImage

    static func make(isJamiAccount: Bool,
                     isKnownContact: Bool,
                     canEditProfile: Bool) -> [ContactActions] {
        var actions = [ContactActions(kind: .audioCall,
                                      title: L10n.ContactPage.startAudioCall,
                                      image: UIImage(systemName: "phone")!)]
        if isJamiAccount {
            actions.append(ContactActions(kind: .videoCall,
                                          title: L10n.ContactPage.startVideoCall,
                                          image: UIImage(systemName: "video")!))
        }
        if canEditProfile {
            actions.append(ContactActions(kind: .editProfile,
                                          title: L10n.Global.edit,
                                          image: UIImage(systemName: "pencil")!))
        }
        if isJamiAccount {
            actions.append(ContactActions(kind: .sendMessage,
                                          title: L10n.ContactPage.send,
                                          image: UIImage(systemName: "message")!))
        }
        if isKnownContact {
            actions.append(ContactActions(kind: .leaveConversation,
                                          title: L10n.ContactPage.leaveConversation,
                                          image: UIImage(systemName: "rectangle.portrait.and.arrow.right")!))
            if isJamiAccount {
                actions.append(ContactActions(kind: .blockContact,
                                              title: L10n.Global.blockContact,
                                              image: UIImage(systemName: "nosign")!))
            }
        }
        return actions
    }
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
    private let nameService: NameService
    private let destructiveActionExecutor: ConversationDestructiveActionExecutor
    private let sections = BehaviorRelay<[SectionModel<String, ContactActions>]>(value: [])
    var tableSection: Observable<[SectionModel<String, ContactActions>]> {
        sections.asObservable()
    }
    var conversation: ConversationModel! {
        didSet {
            guard let account = self.accountService
                    .getAccount(fromAccountId: conversation.accountId),
                  let jamiId = conversation.getParticipants().first?.jamiId else { return }

            let contact = self.contactService.contact(withHash: jamiId)
            let actions = ContactActions.make(isJamiAccount: account.type == .ring,
                                              isKnownContact: contact != nil,
                                              canEditProfile: canEditProfile)
            sections.accept([SectionModel(model: "ProfileInfoCell", items: actions)])

            if let contact = contact {
                if let name = contact.userName {
                    self.userName.accept(name)
                } else {
                    self.userName.accept(jamiId)
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
            self.profileService.getProfile(uri: contactURI,
                                           accountId: conversation.accountId)
                .subscribe(onNext: { [weak self] profile in
                    guard let self = self else { return }
                    self.displayName.accept((profile.alias ?? "").simplified())
                    self.profileImageData.accept(profile.photo?.toImageData())
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
        self.nameService = injectionBag.nameService
        self.destructiveActionExecutor = ConversationDestructiveActionExecutor(injectionBag: injectionBag)
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

    var canEditProfile: Bool {
        guard let conversation else { return false }
        return conversation.isCoredialog() && !conversation.isOnlyLocalParticipant()
    }

    func editProfile() {
        guard canEditProfile else { return }
        stateSubject.onNext(ConversationState.editConversationProfile(conversation: conversation))
    }

    func deleteConversation() {
        destructiveActionExecutor.perform(.removeContact,
                                          on: conversation,
                                          completion: { [weak self] in self?.emitConversationRemoved() })
    }

    func blockContact() {
        destructiveActionExecutor.perform(.blockContact,
                                          on: conversation,
                                          completion: { [weak self] in self?.emitConversationRemoved() })
    }

    private func emitConversationRemoved() {
        stateSubject.onNext(ConversationState.conversationRemoved)
    }
}
