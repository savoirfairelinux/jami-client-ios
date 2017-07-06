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

class ContactsService {

    fileprivate let contactsAdapter: ContactsAdapter
    fileprivate var contacts = [ContactModel]()
    fileprivate var trustRequest = [TrustRequest]()

    fileprivate let log = SwiftyBeaver.self

    init(withContactsAdapter contactsAdapter: ContactsAdapter) {
        self.contactsAdapter = contactsAdapter
        ContactsAdapter.delegate = self

        //TODO: Load contacts from daemon

        //TODO: Load trust requests from daemon
    }

    func trustRequests(withAccountId accountId: String) -> /* -> Observable<[TrustRequest]?> */ [TrustRequest] {

        guard let trustRequestDictionaries = self.contactsAdapter.trustRequests(withAccountId: accountId) else {
            return [TrustRequest]()
        }

        return trustRequestDictionaries.map({ trd in
            return TrustRequest(withDictionary: trd)
        })
    }

    func accept(trustRequest: TrustRequest, withAccount account: AccountModel) -> /* -> Observable<Bool> */ Bool {
        return self.contactsAdapter.acceptTrustRequest(fromContact: trustRequest.ringId, withAccountId: account.id)
    }

    func discard(trustRequest: TrustRequest, withAccount account: AccountModel) -> /* -> Observable<Bool> */ Bool {
        return self.contactsAdapter.discardTrustRequest(fromContact: trustRequest.ringId, withAccountId: account.id)
    }

    func sendTrustRequest(toContact contact: ContactModel, vCard: CNContact, withAccount account: AccountModel) /* -> Completable */ {
        do {
            let payload = try CNContactVCardSerialization.data(with: [vCard])
            self.contactsAdapter.sendTrustRequest(toContact: contact.ringId, payload: payload, withAccountId: account.id)
        } catch {
            log.error("Unable to serialize the vCard : \(error)")
        }
    }

    func addContact(contact: ContactModel, account: AccountModel) /* -> Completable */ {
        self.contactsAdapter.addContact(withURI: contact.ringId, accountId: account.id)
        self.contacts.append(contact)
    }

    func removeContact(contact: ContactModel, account: AccountModel, ban: Bool) /* -> Completable */ {
        self.contactsAdapter.removeContact(withURI: contact.ringId, accountId: account.id, ban: ban)
        self.removeContactFromLocalList(withRingId: contact.ringId)
    }

    func contact(withRingId ringId: String, account: AccountModel) -> /* -> Observable<Bool> */ ContactModel? {
        if let contact = self.contacts.filter({ contact in
            return contact.ringId == ringId
        }).first {
            return contact
        } else {
            return nil
        }
    }

    fileprivate func removeContactFromLocalList(withRingId ringId: String) {
        if let indexOfContactToRemove = self.contacts.index(where: { contact in
            return contact.ringId == ringId
        }) {
            self.contacts.remove(at: indexOfContactToRemove)
            log.debug("Contact removed... ")
        }
    }

}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        do {
            let vCard = try CNContactVCardSerialization.contacts(with: payload)
            let trustRequest = TrustRequest(withRingId: senderAccount, vCard: vCard.first!, receivedDate: receivedDate)
            self.trustRequest.append(trustRequest)
            log.debug("Incoming trust request received from :\(senderAccount)")
        } catch {
            log.error("Unable to serialize the vCard : \(error)")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        let contact = ContactModel(withRingId: uri)
        self.contacts.append(contact)
        log.debug("Contact added :\(uri)")
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        self.removeContactFromLocalList(withRingId: uri)
        log.debug("Contact removed :\(uri)")
    }
}
