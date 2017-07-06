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

class ContactRequestItem {

    fileprivate let contactRequest: ContactRequestModel
    fileprivate let contactsService: ContactsService
    fileprivate let accountsService: AccountsService
    fileprivate let nameService: NameService

    let userName: Observable<String>
    let profileImageData: Data?

    init(withContactRequest contactRequest: ContactRequestModel,
         contactsService: ContactsService,
         accountsService: AccountsService,
         nameService: NameService) {

        self.contactRequest = contactRequest
        self.contactsService = contactsService
        self.accountsService = accountsService
        self.nameService = nameService

        self.userName = AppDelegate.nameService.usernameLookupStatus
            .filter({ lookupNameResponse in
                return lookupNameResponse.address == contactRequest.ringId
            })
            .map({ lookupNameResponse in
                if lookupNameResponse.state == .found {
                    return lookupNameResponse.name
                } else {
                    return lookupNameResponse.address
                }
            })

        AppDelegate.nameService.lookupAddress(withAccount: (accountsService.currentAccount?.id)!,
                                              nameserver: "",
                                              address: contactRequest.ringId)

        self.profileImageData = self.contactRequest.vCard?.imageData

    }

    func accept() -> Observable<Void> {
        let acceptCompleted = self.contactsService.accept(contactRequest: self.contactRequest)

        if let vCard = contactRequest.vCard {
            let saveVCardCompleted = self.contactsService.saveVCard(vCard: vCard, withName: contactRequest.ringId)
            return Observable<Void>.zip(acceptCompleted, saveVCardCompleted) { _, _ in
                return
            }
        } else {
            return acceptCompleted.asObservable()
        }
    }

    func discard() -> Observable<Void> {
        return self.contactsService.discard(contactRequest: self.contactRequest)
    }

    func ban() -> Observable<Void> {
        let discardCompleted = self.contactsService.discard(contactRequest: self.contactRequest)
        let removeCompleted = self.contactsService.removeContact(withRingId: contactRequest.ringId,
                                                                 ban: true)

        return Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
            return
        }
    }
}
