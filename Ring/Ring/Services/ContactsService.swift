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

class ContactsService: ContactsAdapterDelegate {

    fileprivate let contactsAdapter :ContactsAdapter
    fileprivate var contacts = [ContactModel]()
    fileprivate var trustRequest = [TrustRequest]()

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
        let payload = try! CNContactVCardSerialization.data(with: [vCard])
        self.contactsAdapter.sendTrustRequest(toContact: contact.ringId, payload: payload, withAccountId: account.id)
    }

    func addContact(withURI uri: String, account: AccountModel) /* -> Completable */ {
        self.contactsAdapter.addContact(withURI: uri, accountId: account.id)

        //TODO: Add to list?

        let ringId = ContactHelper.ringId(fromURI: uri)

        self.contacts.append(ContactModel(withRingId: ringId!))
    }

    func removeContact(withURI uri: String, account: AccountModel, ban: Bool) /* -> Completable */ {
        self.contactsAdapter.removeContact(withURI: uri, accountId: account.id, ban: ban)

        //TODO: Remove from list?
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

    //MARK: Contacts Adapter Delegate

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        do {
            let vCard = try CNContactVCardSerialization.contacts(with: payload)
            let trustRequest = TrustRequest(withRingId: senderAccount, vCard: vCard.first!, receivedDate: receivedDate)
            self.trustRequest.append(trustRequest)
        } catch {
            print("Unable to serialize the vCard : \(error)")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        if let ringId = ContactHelper.ringId(fromURI: uri) {
            let contact = ContactModel(withRingId: ringId)
            self.contacts.append(contact)
            print("Contact added... ")
        }
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        let ringId = ContactHelper.ringId(fromURI: uri)
        if let indexOfContactToRemove = self.contacts.index(where: { contact in
            return contact.ringId == ringId
        }) {
            self.contacts.remove(at: indexOfContactToRemove)
            print("Contact removed... ")
        }
    }
}
