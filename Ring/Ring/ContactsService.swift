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

import UIKit
import RxSwift

class ContactsService: ContactsAdapterDelegate {

    let disposeBag = DisposeBag()

    let contactFound = PublishSubject<ContactModel>()

    let contactsAdapter: ContactsAdapter

    let nameService = AppDelegate.nameService

    fileprivate var currentSearchText: String?

    fileprivate var contacts = [ContactModel]()

    init(withContactsAdapter contactsAdapter: ContactsAdapter) {
        self.contactsAdapter = contactsAdapter
        ContactsAdapter.delegate = self

        //Observe username lookup
        self.nameService.usernameLookupStatus.subscribe(onNext: { usernameLookupStatus in
            if usernameLookupStatus.state == .found && (usernameLookupStatus.name == self.currentSearchText || usernameLookupStatus.address == self.currentSearchText) {

                //Create new contact
                let contact = ContactModel(withRingId: usernameLookupStatus.address)
                contact.userName = usernameLookupStatus.name
                self.contactFound.onNext(contact)
            }
        }).addDisposableTo(disposeBag)
    }

    func add(contact: ContactModel, forAccountId accountId: String) {
        self.contacts.append(contact)
    }

    func contacts(forAccountId accountId: String) -> [ContactModel] {
        return self.contacts
    }

    func searchContact(withText text: String) {

        self.currentSearchText = text

        //Search from local contacts
        let foundContacts = self.contacts.filter({ contact in
            if let userName = contact.userName {
                return contact.ringId.contains(text) || userName.contains(text)
            } else {
                return contact.ringId.contains(text)
            }
        })

        //Lookup from Name Sevice if not found
        if foundContacts.count == 0 {
            lookupContact(withText: text)
        } else {
            self.contactFound.onNext(foundContacts.first!)
        }
    }

    func lookupContact(withText text: String) {
        if text.isValidRingId() {
            self.nameService.lookupAddress(withAccount: "", nameserver: "", address: text)
        } else {
            self.nameService.lookupName(withAccount: "", nameserver: "", name: text)
        }
    }

    //MARK: Contacts Adapter delegate

    func addedContact(withURI uri: String, forAccountId accountId: String, confirmed: Bool) {

    }
}
