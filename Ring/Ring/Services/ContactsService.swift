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

    init(withContactsAdapter contactsAdapter: ContactsAdapter) {
        self.contactsAdapter = contactsAdapter
        ContactsAdapter.delegate = self
    }

    func trustRequests(withAccountId accountId: String) -> [TrustRequest]? /* ->Observable */ {

        guard let trustRequestDictionaries = self.contactsAdapter.trustRequests(withAccountId: accountId) else {
            return nil
        }

        return trustRequestDictionaries.map({ trd in
            return TrustRequest(withDictionary: trd)
        })
    }

    func sendTrustRequest(toContact contact: ContactModel, vCard: CNContact, withAccount account: AccountModel) {
        let payload = try! CNContactVCardSerialization.data(with: [vCard])
        self.contactsAdapter.sendTrustRequest(toContact: contact.ringId, payload: payload, withAccountId: account.id)
    }

    //MARK: Contacts Adapter Delegate

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        do {
            let vCard = try CNContactVCardSerialization.contacts(with: payload)
            let tr = TrustRequest(withRingId: senderAccount, vCard: vCard.first!, receivedDate: receivedDate)
        } catch {
            print("Unable to serialize the vCard : \(error)")
        }
    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {

    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {

    }
}
