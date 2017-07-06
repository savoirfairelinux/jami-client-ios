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
    case acceptTrustRequestFailed
    case diacardTrusRequestFailed
    case vCardSerializationFailed
    case loadVCardFailed
    case saveVCardFailed
}

class ContactsService {

    fileprivate let contactsAdapter: ContactsAdapter
    fileprivate let log = SwiftyBeaver.self

    var currentAccount: AccountModel?
    var accounts: [AccountModel]?

    let currentAccountContactRequests = Variable([ContactRequestModel]())

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

    fileprivate func loadContactRequests() {
        if let currentAccount = self.currentAccount {

            //Load trust requests from daemon
            let trustRequestsDictionaries = self.contactsAdapter.trustRequests(withAccountId: currentAccount.id)

            //Create contact requests from daemon trust requests
            if let contactsRequests = trustRequestsDictionaries?.map({ dictionary in
                return ContactRequestModel(withDictionary: dictionary)
            }) {
                for contactsRequest in contactsRequests {
                    currentAccount.contactRequests[contactsRequest.ringId] = contactsRequest
                }
                self.currentAccountContactRequests.value = contactsRequests
            }
        }
    }

    func setCurrentAccount(currentAccount: AccountModel) {
        self.currentAccount = currentAccount
        self.loadContacts()
        self.loadContactRequests()
    }

    func setAccounts(accounts: [AccountModel]) {
        self.accounts = accounts
    }

    func accept(contactRequest: ContactRequestModel) -> Observable<Void> {
        return Observable.create { observable in
            if let currentAccount = self.currentAccount {
                let sucess = self.contactsAdapter.acceptTrustRequest(fromContact: contactRequest.ringId,
                                                                     withAccountId: currentAccount.id)
                if sucess {
                    observable.on(.completed)
                } else {
                    observable.on(.error(ContactServiceError.acceptTrustRequestFailed))
                }
            } else {
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func discard(contactRequest: ContactRequestModel) -> Observable<Void> {
        return Observable.create { observable in
            if let currentAccount = self.currentAccount {
                let success = self.contactsAdapter.discardTrustRequest(fromContact: contactRequest.ringId,
                                                                      withAccountId: currentAccount.id)

                //Update the Contact request list
                currentAccount.contactRequests[contactRequest.ringId] = nil
                self.currentAccountContactRequests.value = Array(currentAccount.contactRequests.values)

                if success {
                    observable.on(.completed)
                } else {
                    observable.on(.error(ContactServiceError.diacardTrusRequestFailed))
                }
            } else {
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func sendContactRequest(toContactRingId ringId: String, vCard: CNContact) -> Observable<Void> {
        return Observable.create { observable in
            if let currentAccount = self.currentAccount {
                do {
                    let payload = try CNContactVCardSerialization.data(with: [vCard])
                    self.contactsAdapter.sendTrustRequest(toContact: ringId, payload: payload, withAccountId: currentAccount.id)
                    observable.on(.completed)
                } catch {
                    observable.on(.error(ContactServiceError.vCardSerializationFailed))
                }
            } else {
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func addContact(contact: ContactModel) -> Observable<Void> {
        return Observable.create { observable in
            if let currentAccount = self.currentAccount {
                self.contactsAdapter.addContact(withURI: contact.ringId, accountId: currentAccount.id)
                currentAccount.contacts[contact.ringId] = contact
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }
            return Disposables.create { }
        }
    }

    func removeContact(contact: ContactModel, ban: Bool) -> Observable<Void> {
        return removeContact(withRingId: contact.ringId, ban: ban)
    }

    func removeContact(withRingId ringId: String, ban: Bool) -> Observable<Void> {
        return Observable.create { observable in
            if let currentAccount = self.currentAccount {

                //Remove from contacts
                self.contactsAdapter.removeContact(withURI: ringId, accountId: currentAccount.id, ban: ban)
                currentAccount.contacts[ringId] = nil

                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }
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
                observable.on(.error(ContactServiceError.noCurrentAccountSet))
            }

            return Disposables.create { }
        }
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            do {
                //Create a the vCard
                let vCards = try CNContactVCardSerialization.contacts(with: payload)

                var contactRequest: ContactRequestModel!
                if let vCard = vCards.first {
                    contactRequest = ContactRequestModel(withRingId: senderAccount, vCard: vCard, receivedDate: receivedDate)
                } else {
                    contactRequest = ContactRequestModel(withRingId: senderAccount, vCard: nil, receivedDate: receivedDate)
                }

                //Update trust request list
                destinationAccount.contactRequests[senderAccount] = contactRequest
                self.currentAccountContactRequests.value = Array(destinationAccount.contactRequests.values)

                log.debug("Incoming trust request received from :\(senderAccount)")
            } catch {
                log.error("Unable to parse the vCard :\(error)")
            }
        } else {
            log.error("ContactService: account not found")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            let contact = ContactModel(withRingId: uri)
            destinationAccount.contacts[contact.ringId] = contact

            //Update trust request list
            destinationAccount.contactRequests[contact.ringId] = nil
            self.currentAccountContactRequests.value = Array(destinationAccount.contactRequests.values)

            log.debug("Contact added :\(uri)")
        } else {
            log.error("ContactService: account not found")
        }
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        if let destinationAccount = self.accounts?.filter({ account in
            return account.id == accountId
        }).first {
            destinationAccount.contacts[uri] = nil
            log.debug("Contact removed :\(uri)")
        } else {
            log.error("ContactService: account not found")
        }
    }
}
