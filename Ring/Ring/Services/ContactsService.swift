/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

import Contacts
import SwiftyBeaver
import RxSwift
import RxRelay

enum ContactServiceError: Error {
    case vCardSerializationFailed
    case loadVCardFailed
    case saveVCardFailed
    case removeContactFailed
}

class ContactsService {

    private let contactsAdapter: ContactsAdapter
    private let log = SwiftyBeaver.self
    private let disposeBag = DisposeBag()

    let contacts = BehaviorRelay(value: [ContactModel]())
    let contactStatus = PublishSubject<ContactModel>()

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    let dbManager: DBManager

    // MARK: initial loading

    init(withContactsAdapter contactsAdapter: ContactsAdapter, dbManager: DBManager) {
        self.contactsAdapter = contactsAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dbManager = dbManager
        ContactsAdapter.delegate = self
    }

    /**
     Called when application starts and when  account changed
     */
    func loadContacts(withAccount account: AccountModel) {
        if AccountModelHelper.init(withAccount: account).isAccountSip() {
            self.loadSipContacts(withAccount: account)
            return
        }
        loadJamiContacts(withAccount: account.id)
    }

    private func loadSipContacts(withAccount account: AccountModel) {
        guard let profiles = self.dbManager
            .getProfilesForAccount(accountId: account.id) else { return }
        let contacts = profiles.map({ profile in
            return ContactModel(withUri: JamiURI.init(schema: URIType.sip, infoHach: profile.uri))
        })
        self.contacts.accept([])
        for contact in contacts {
            if self.contacts.value.firstIndex(of: contact) == nil {
                var values = self.contacts.value
                values.append(contact)
                self.contacts.accept(values)
                self.log.debug("contact: \(String(describing: contact.userName))")
            }
        }
    }

    private func loadJamiContacts(withAccount account: String) {
        // Load contacts from daemon
        let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: account)

        // Serialize them
        if let contacts = contactsDictionaries?.map({ contactDict in
            return ContactModel(withDictionary: contactDict)
        }) {
            self.contacts.accept([])
            for contact in contacts {
                if self.contacts.value.firstIndex(of: contact) == nil {
                    var values = self.contacts.value
                    values.append(contact)
                    self.contacts.accept(values)
                    self.log.debug("contact: \(String(describing: contact.userName))")
                }
            }
        }
    }

    // MARK: contact getter

    func contact(withUri uri: String) -> ContactModel? {
        guard let contact = self.contacts.value.filter({ $0.uriString == uri }).first else {
            return nil
        }
        return contact
    }

    func contact(withHash hash: String) -> ContactModel? {
        guard let contact = self.contacts.value.filter({ $0.hash == hash }).first else {
            return nil
        }
        return contact
    }

    // MARK: contacts management unban/remove

    func removeContact(withId jamiId: String, ban: Bool, withAccountId accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            self.contactsAdapter.removeContact(withURI: jamiId, accountId: accountId, ban: ban)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func unbanContact(contact: ContactModel, account: AccountModel) {
        self.contactsAdapter.addContact(withURI: contact.hash, accountId: account.id)
        if let existingContact = self.contact(withUri: contact.uriString ?? "") {
            existingContact.banned = false
        } else {
            var values = self.contacts.value
            values.append(contact)
            self.contacts.accept(values)
            self.contactStatus.onNext(contact)
        }
    }

    func removeAllContacts(for accountId: String) {
        DispatchQueue.global(qos: .background).async {
            for contact in self.contacts.value {
                self.contactsAdapter.removeContact(withURI: contact.hash, accountId: accountId, ban: false)
            }
            self.contacts.accept([])
            self.dbManager
                .clearAllHistoryFor(accountId: accountId)
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }

    // MARK: get contact profile
    func getProfileForUri(uri: String, accountId: String) -> Observable<Profile> {
        return self.dbManager.profileObservable(for: uri, createIfNotExists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func getProfile(uri: String, accountId: String) -> Profile? {
        do {
            return try self.dbManager.getProfile(for: uri, createIfNotExists: false, accountId: accountId)
        } catch {
            return nil
        }
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        // update contact status
        if let contact = self.contact(withUri: uri) {
            if contact.confirmed != confirmed {
                contact.confirmed = confirmed
            }
            self.contactStatus.onNext(contact)
        }
            // sync contacts with daemon contacts
        else {
            let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: accountId)
            // Serialize them
            if let contacts = contactsDictionaries?.map({ contactDict in
                return ContactModel(withDictionary: contactDict)
            }) {
                for contact in contacts {
                    if self.contacts.value.firstIndex(of: contact) == nil {
                        var values = self.contacts.value
                        values.append(contact)
                        self.contacts.accept(values)
                        self.contactStatus.onNext(contact)
                    }
                }
            }
        }
        log.debug("Contact added :\(uri)")
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        guard let contactToRemove = self.contacts.value.filter({ $0.hash == uri }).first else {
            return
        }
        contactToRemove.banned = banned
        self.contactStatus.onNext(contactToRemove)
        log.debug("Contact removed :\(uri)")
    }

}
