/*
 *  Copyright (C) 2018 Savoir-faire Linux Inc.
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
    let tableSection = Observable<[SectionModel<String, ContactActions>]>
        .just([SectionModel(model: "ProfileInfoCell",
                            items:
            [ ContactActions(title: L10n.Contactpage.startAudioCall, image: Asset.callButton),
              ContactActions(title: L10n.Contactpage.startVideoCall, image: Asset.videoRunning),
              ContactActions(title: L10n.Contactpage.sendMessage, image: Asset.conversationIcon),
              ContactActions(title: L10n.Contactpage.clearConversation, image: Asset.clearConversation),
              ContactActions(title: L10n.Contactpage.blockContact, image: Asset.blockIcon)])])
    var conversation: ConversationModel! {
        didSet {
            self.userName.value = conversation.recipientRingId
            if let profile = conversation.participantProfile, let alias = profile.alias, !alias.isEmpty {
                self.displayName.value = alias
            }
            if let contact = self.contactService.contact(withRingId: conversation.recipientRingId),
                let name = contact.userName {
                self.userName.value = name
            }
            self.contactService
                .getContactRequestVCard(forContactWithRingId: conversation.recipientRingId)
                .subscribe(onSuccess: { [unowned self] vCard in
                    if !VCardUtils.getName(from: vCard).isEmpty {
                        self.displayName.value = VCardUtils.getName(from: vCard)
                    }
                    guard let imageData = vCard.imageData else {
                        return
                    }
                    self.profileImageData.value = imageData
                })
                .disposed(by: self.disposeBag)
            self.profileService.getProfile(ringId: conversation.recipientRingId,
                                           createIfNotexists: false)
                .subscribe(onNext: { [unowned self] profile in
                    if let alias = profile.alias, !alias.isEmpty {
                        self.displayName.value = alias
                    }
                    if let photo = profile.photo,
                        let data = NSData(base64Encoded: photo, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data? {
                        self.profileImageData.value = data
                    }
                }).disposed(by: disposeBag)
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
    }
    func startCall() {
        self.stateSubject.onNext(ConversationState
            .startCall(contactRingId: conversation.recipientRingId,
                       userName: self.userName.value))
    }
    func startAudioCall() {
        self.stateSubject.onNext(ConversationState
            .startAudioCall(contactRingId: conversation.recipientRingId,
                            userName: self.userName.value))
    }

    func deleteConversation() {
        self.conversationService
            .deleteConversation(conversation: conversation,
                                keepContactInteraction: true)
    }

    func blockContact() {
        let contactRingId = conversation.recipientRingId
        let accountId = conversation.accountId
        let removeCompleted = self.contactService.removeContact(withRingId: contactRingId,
                                                                ban: true,
                                                                withAccountId: accountId)
        removeCompleted.asObservable()
            .subscribe(onCompleted: { [unowned self] in
                self.conversationService
                    .deleteConversation(conversation: self.conversation,
                                        keepContactInteraction: false)
            }).disposed(by: self.disposeBag)
    }
}
