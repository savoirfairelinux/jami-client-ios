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
    case noCurrentAccountSet
}

class ContactsService {

    fileprivate let contactsAdapter: ContactsAdapter
    fileprivate let log = SwiftyBeaver.self
    var currentAccount: AccountModel?
    var accounts: [AccountModel]?

    init(withContactsAdapter contactsAdapter: ContactsAdapter) {
        self.contactsAdapter = contactsAdapter
        ContactsAdapter.delegate = self
    }

    fileprivate func loadContacts() {
        if let currentAccount = self.currentAccount {

            //Load contacts from daemon
            let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: currentAccount.id)

            //Serialize them
            if let contacts = contactsDictionaries?.map({ contactDict in
                return ContactModel(withDictionary: contactDict)
            }) {
                for contact in contacts {
                    currentAccount.contacts[contact.ringId] = contact
                }
            }
        }
    }

    fileprivate func loadTrustRequests() {
        if let currentAccount = self.currentAccount {

            //Load trust requests from daemon
            let trustRequestsDictionaries = self.contactsAdapter.trustRequests(withAccountId: currentAccount.id)

            //Serialize them
            if let trustRequests = trustRequestsDictionaries?.map({ trusrRequestDict in
                return TrustRequest(withDictionary: trusrRequestDict)
            }) {
                for trustRequest in trustRequests {
                    currentAccount.trustRequests[trustRequest.ringId] = trustRequest
                }
            }
        }
    }

    func setCurrentAccount(currentAccount: AccountModel) {
        self.currentAccount = currentAccount
        self.loadContacts()
        self.loadTrustRequests()
    }

    func setAccounts(accounts: [AccountModel]) {
        self.accounts = accounts
    }

    func accept(trustRequest: TrustRequest) -> Single<Bool> {
        return Single.create { single in
            if let currentAccount = self.currentAccount {
                let result = self.contactsAdapter.acceptTrustRequest(fromContact: trustRequest.ringId,
                                                                     withAccountId: currentAccount.id)
                single(.success(result))
            } else {
                single(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func discard(trustRequest: TrustRequest) -> Single<Bool> {
        return Single.create { single in
            if let currentAccount = self.currentAccount {
                let result = self.contactsAdapter.discardTrustRequest(fromContact: trustRequest.ringId,
                                                                      withAccountId: currentAccount.id)
                single(.success(result))
            } else {
                single(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func sendTrustRequest(toContact contact: ContactModel, vCard: CNContact) -> Completable {
        return Completable.create { completable in
            if let currentAccount = self.currentAccount {
                do {
                    let payload = try CNContactVCardSerialization.data(with: [vCard])
                    self.contactsAdapter.sendTrustRequest(toContact: contact.ringId, payload: payload, withAccountId: currentAccount.id)
                } catch {
                    self.log.error("Unable to serialize the vCard : \(error)")
                }
                completable(.completed)
            } else {
                completable(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func addContact(contact: ContactModel) -> Completable {
        return Completable.create(subscribe: { completable in
            if let currentAccount = self.currentAccount {
                self.contactsAdapter.addContact(withURI: contact.ringId, accountId: currentAccount.id)
                currentAccount.contacts[contact.ringId] = contact
                completable(.completed)
            } else {
                completable(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        })
    }

    func removeContact(contact: ContactModel, ban: Bool) -> Completable {
        return Completable.create(subscribe: { completable in
            if let currentAccount = self.currentAccount {
                self.contactsAdapter.removeContact(withURI: contact.ringId, accountId: currentAccount.id, ban: ban)
                currentAccount.contacts[contact.ringId] = nil
                completable(.completed)
            } else {
                completable(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        })
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            do {
                let vCard = try CNContactVCardSerialization.contacts(with: payload)
                let trustRequest = TrustRequest(withRingId: senderAccount, vCard: vCard.first!, receivedDate: receivedDate)
                destinationAccount.trustRequests[senderAccount] = trustRequest
                log.debug("Incoming trust request received from :\(senderAccount)")
            } catch {
                log.error("Unable to serialize the vCard :\(error)")
            }
        } else {
            log.error("ContactService: no accounts list set")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            let contact = ContactModel(withRingId: uri)
            destinationAccount.contacts[contact.ringId] = contact
            log.debug("Contact added :\(uri)")
        } else {
            log.error("ContactService: no accounts list set")
        }
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            destinationAccount.contacts[uri] = nil
            log.debug("Contact removed :\(uri)")
        } else {
            log.error("ContactService: no accounts list set")
        }
    }
}
