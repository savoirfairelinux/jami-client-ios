/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
 *
 *  Author: Silbino Gonçalves Matado <silbino.gmatado@savoirfairelinux.com>
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

enum ContactServiceError: Error {
    case acceptTrustRequestFailed
    case diacardTrusRequestFailed
    case vCardSerializationFailed
    case loadVCardFailed
    case saveVCardFailed
}

class ContactsService {

    fileprivate let contactsAdapter: ContactsAdapter
    fileprivate let log = SwiftyBeaver.self

    let contactRequests = Variable([ContactRequestModel]())
    let contacts = Variable([ContactModel]())

    init(withContactsAdapter contactsAdapter: ContactsAdapter) {
        self.contactsAdapter = contactsAdapter
        ContactsAdapter.delegate = self
    }

    func contact(withRingId ringId: String) -> ContactModel? {
        guard let contact = self.contacts.value.filter({ $0.ringId == ringId }).first else {
            return nil
        }

        return contact
    }

    func contactRequest(withRingId ringId: String) -> ContactRequestModel? {
        guard let contact = self.contactRequests.value.filter({ $0.ringId == ringId }).first else {
            return nil
        }

        return contact
    }

    func loadContacts(withAccount account: AccountModel) {
        //Load contacts from daemon
        let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: account.id)

        //Serialize them
        if let contacts = contactsDictionaries?.map({ contactDict in
            return ContactModel(withDictionary: contactDict)
        }) {
            for contact in contacts {
                self.contacts.value.append(contact)
            }
        }
    }

    func loadContactRequests(withAccount account: AccountModel) {
        //Load trust requests from daemon
        let trustRequestsDictionaries = self.contactsAdapter.trustRequests(withAccountId: account.id)

        //Create contact requests from daemon trust requests
        if let contactRequests = trustRequestsDictionaries?.map({ dictionary in
            return ContactRequestModel(withDictionary: dictionary, accountId: account.id)
        }) {
            for contactRequest in contactRequests {
                self.contactRequests.value.append(contactRequest)
            }
        }
    }

    func accept(contactRequest: ContactRequestModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            let success = self.contactsAdapter.acceptTrustRequest(fromContact: contactRequest.ringId,
                                                                 withAccountId: account.id)
            if success {
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.acceptTrustRequestFailed))
            }

            return Disposables.create { }
        }
    }

    func discard(contactRequest: ContactRequestModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            let success = self.contactsAdapter.discardTrustRequest(fromContact: contactRequest.ringId,
                                                                   withAccountId: account.id)

            //Update the Contact request list
            self.removeContactRequest(withRingId: contactRequest.ringId)

            if success {
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.diacardTrusRequestFailed))
            }
            return Disposables.create { }
        }
    }

    func sendContactRequest(toContactRingId ringId: String, vCard: CNContact, withAccount account: AccountModel) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                let payload = try CNContactVCardSerialization.data(with: [vCard])
                self.contactsAdapter.sendTrustRequest(toContact: ringId, payload: payload, withAccountId: account.id)
                completable(.completed)
            } catch {
                completable(.error(ContactServiceError.vCardSerializationFailed))
            }
            return Disposables.create { }
        }
    }

    func addContact(contact: ContactModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            self.contactsAdapter.addContact(withURI: contact.ringId, accountId: account.id)
            self.contacts.value.append(contact)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func removeContact(contact: ContactModel, ban: Bool, withAccount account: AccountModel) -> Observable<Void> {
        return removeContact(withRingId: contact.ringId, ban: ban, withAccount: account)
    }

    func removeContact(withRingId ringId: String, ban: Bool, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            self.contactsAdapter.removeContact(withURI: ringId, accountId: account.id, ban: ban)
            self.removeContactRequest(withRingId: ringId)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func loadVCard(named name: String) -> Single<CNContact> {
        return Single.create(subscribe: { single in
            if let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    if let data = FileManager.default.contents(atPath: directoryURL.appendingPathComponent(name).absoluteString) {
                        let vCard = try CNContactVCardSerialization.contacts(with: data).first!
                        single(.success(vCard))
                    }
                } catch {
                    single(.error(ContactServiceError.loadVCardFailed))
                }
            } else {
                single(.error(ContactServiceError.loadVCardFailed))
            }

            return Disposables.create { }
        })
    }

    func saveVCard(vCard: CNContact, withName name: String) -> Observable<Void> {
        return Observable.create { observable in
            if let directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    let data = try CNContactVCardSerialization.data(with: [vCard])
                    try data.write(to: directoryURL.appendingPathComponent(name))
                    observable.on(.completed)
                } catch {
                    observable.on(.error(ContactServiceError.saveVCardFailed))
                }
            } else {
                observable.on(.error(ContactServiceError.saveVCardFailed))
            }

            return Disposables.create { }
        }
    }

    fileprivate func removeContactRequest(withRingId ringId: String) {
        guard let contactRequestToRemove = self.contactRequests.value.filter({ $0.ringId == ringId}).first else {
            return
        }
        guard let index = self.contactRequests.value.index(where: { $0 === contactRequestToRemove }) else {
            return
        }
        self.contactRequests.value.remove(at: index)
    }

    fileprivate func removeContact(withRingId ringId: String) {
        guard let contactToRemove = self.contacts.value.filter({ $0.ringId == ringId}).first else {
            return
        }
        guard let index = self.contacts.value.index(where: { $0 === contactToRemove }) else {
            return
        }
        self.contacts.value.remove(at: index)
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        do {
            //Update trust request list
            if self.contactRequest(withRingId: senderAccount) == nil {
                let vCards = try CNContactVCardSerialization.contacts(with: payload)
                let contactRequest = ContactRequestModel(withRingId: senderAccount,
                                                         vCard: vCards.first,
                                                         receivedDate: receivedDate,
                                                         accountId: accountId)
                self.contactRequests.value.append(contactRequest)
            }

            log.debug("Incoming trust request received from :\(senderAccount)")
        } catch {
            log.error("Unable to parse the vCard :\(error)")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        //Update trust request list
        self.removeContactRequest(withRingId: uri)
        log.debug("Contact added :\(uri)")
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        self.removeContact(withRingId: uri)
        log.debug("Contact removed :\(uri)")
    }
}
