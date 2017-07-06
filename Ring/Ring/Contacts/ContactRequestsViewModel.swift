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

import RxSwift
import Contacts
import SwiftyBeaver

class ContactRequestsViewModel {

    let contactsService: ContactsService
    let accountsService: AccountsService
    let contactRequestItems: Observable<[ContactRequestItem]>
    let hasInvitations: Observable<Bool>

    init(withContactsService contactsService: ContactsService,
         accountsService: AccountsService,
         nameService: NameService) {

        self.contactsService = contactsService
        self.accountsService = accountsService

        self.contactRequestItems = contactsService
            .currentAccountContactRequests
            .asObservable()
            .map({ contactRequests in
                return contactRequests
                    .sorted(by: {
                        $0.receivedDate > $1.receivedDate
                    })
                    .map({ contactRequest in
                        return ContactRequestItem(withContactRequest: contactRequest,
                                                  contactsService: contactsService,
                                                  accountsService: accountsService,
                                                  nameService: nameService)
                })
            })

        self.hasInvitations = self.contactRequestItems.map({ items in
            return !items.isEmpty
        })

    }

}
