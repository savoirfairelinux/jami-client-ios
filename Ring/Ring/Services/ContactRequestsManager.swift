/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

final class ContactRequestsManager {

    let accountsService: NewAccountsService
    let contactsService: ContactsService
    let conversationsService: ConversationsService
    let presenceService: PresenceService

    let disposeBag = DisposeBag()

    init(with accountsService: NewAccountsService,
         contactsService: ContactsService,
         conversationsService: ConversationsService,
         presenceService: PresenceService) {
        self.accountsService = accountsService
        self.contactsService = contactsService
        self.conversationsService = conversationsService
        self.presenceService = presenceService

        self.handleNewContactsRequests()
    }

    private func handleNewContactsRequests() {
        let currentAccountObservable = self.accountsService.currentAccount().asObservable()
        let contactRequestsObservable = self.contactsService.contactRequests.asObservable()

        Observable
            .combineLatest(currentAccountObservable, contactRequestsObservable) { [unowned self] (account, requests) -> Completable in
                guard let ringId = requests.last?.ringId else {
                    return Completable.create(subscribe: { (completable) -> Disposable in
                        completable(.completed)
                        return Disposables.create()
                    })
                }
                return self.conversationsService.generateMessage(ofType: GeneratedMessageType.receivedContactRequest,
                                                                 forRindId: ringId,
                                                                 forAccount: account)
            }
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    private func handleAcceptedContactRequests() {
        self.contactsService.contactStatus
            .flatMap { [unowned self] (contactModel) -> Observable<(ContactModel, AccountModel)> in
                let contactObservable = Observable<ContactModel>.just(contactModel)
                let accountObservable = self.accountsService.getAccount(fromAccountId: contactModel.forAccountId).asObservable()
                return Observable.combineLatest(contactObservable, accountObservable)
            }
            .flatMap { [unowned self] (contact, account) -> Completable in
                return self.conversationsService.generateMessage(ofType: GeneratedMessageType.contactRequestAccepted,
                                                                 forRindId: contact.ringId,
                                                                 forAccount: account)
            }
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func accept(contactRequest: ContactRequestModel, account: AccountModel) -> Completable {
        let accountHelper = AccountModelHelper(withAccount: account)
        var completable = self.contactsService.accept(contactRequest: contactRequest, withAccount: account)
            .andThen(self.conversationsService.saveMessage(withId: "",
                                                           withContent: GeneratedMessageType.contactRequestAccepted.rawValue,
                                                           byAuthor: accountHelper.ringId!,
                                                           toConversationWith: contactRequest.ringId,
                                                           currentAccountId: account.id,
                                                           generated: true))
            .andThen(self.presenceService.subscribeBuddy(withAccountId: account.id,
                                                         withUri: contactRequest.ringId,
                                                         withFlag: true))
        if let vcard = contactRequest.vCard {
            completable = completable.andThen(self.contactsService.saveVCard(vCard: vcard,
                                                                             forContactWithRingId: contactRequest.ringId))
        }
        return completable
    }

    func discard(contactRequest: ContactRequestModel, account: AccountModel) -> Completable {
        return self.contactsService.discard(contactRequest: contactRequest,
                                            withAccount: account)
    }

    func ban(contactRequest: ContactRequestModel, account: AccountModel) -> Completable {
        let discard = self.contactsService.discard(contactRequest: contactRequest,
                                                   withAccount: account)
        let remove = self.contactsService.removeContact(withRingId: contactRequest.ringId,
                                                        ban: true,
                                                        withAccount: account)
        return discard.andThen(remove)
    }

    func send(to recipientId: String, withAccount account: AccountModel) -> Completable {
        var completable = VCardUtils.loadVCard(named: VCardFiles.myProfile.rawValue, inFolder: VCardFolders.profile.rawValue)
            .asObservable()
            .flatMap { [unowned self] (vCard) -> Completable in
                return self.contactsService.sendContactRequest(toContactRingId: recipientId,
                                                               vCard: vCard,
                                                               withAccount: account)
            }
            .asCompletable()

        if self.contactsService.contact(withRingId: recipientId) != nil {
            completable = completable.andThen(self.conversationsService.generateMessage(ofType: GeneratedMessageType.sendContactRequest,
                                                                                        forRindId: recipientId,
                                                                                        forAccount: account))
        }
        return completable
    }

}
