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

class ContactRequestsViewModel: ViewModel {

    let contactsService: ContactsService
    let accountsService: AccountsService
    let nameService: NameService

    fileprivate let disposeBag = DisposeBag()

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.accountsService = injectionBag.accountService
        self.nameService = injectionBag.nameService
    }

    lazy var contactRequestItems: Observable<[ContactRequestItem]> = {
        return self.contactsService.contactRequests
            .asObservable()
            .map({ [unowned self] contactRequests in
                return contactRequests
                    .filter { $0.accountId == self.accountsService.currentAccount?.id }
                    .sorted { $0.receivedDate > $1.receivedDate }
                    .map { contactRequest in
                        let item = ContactRequestItem(withContactRequest: contactRequest)
                        self.lookupUserName(withItem: item)
                        return item
                    }
            })
    }()

    lazy var hasInvitations: Observable<Bool> = {
        return self.contactsService.contactRequests
            .asObservable()
            .map({ items in
                return !items.isEmpty
            })
    }()

    func accept(withItem item: ContactRequestItem) -> Observable<Void> {
        let acceptCompleted = self.contactsService.accept(contactRequest: item.contactRequest, withAccount: self.accountsService.currentAccount!)

        if let vCard = item.contactRequest.vCard {
            let saveVCardCompleted = self.contactsService.saveVCard(vCard: vCard, forContactWithRingId: item.contactRequest.ringId)
            return Observable<Void>.zip(acceptCompleted, saveVCardCompleted) { _, _ in
                return
            }
        } else {
            return acceptCompleted.asObservable()
        }
    }

    func discard(withItem item: ContactRequestItem) -> Observable<Void> {
        return self.contactsService.discard(contactRequest: item.contactRequest,
                                            withAccount: self.accountsService.currentAccount!)
    }

    func ban(withItem item: ContactRequestItem) -> Observable<Void> {
        let discardCompleted = self.contactsService.discard(contactRequest: item.contactRequest,
                                                            withAccount: self.accountsService.currentAccount!)

        let removeCompleted = self.contactsService.removeContact(withRingId: item.contactRequest.ringId,
                                                                 ban: true,
                                                                 withAccount: self.accountsService.currentAccount!)

        return Observable<Void>.zip(discardCompleted, removeCompleted) { _, _ in
            return
        }
    }

    fileprivate func lookupUserName(withItem item: ContactRequestItem) {

        self.nameService.usernameLookupStatus.asObservable()
            .filter({ lookupNameResponse in
                return lookupNameResponse.address == item.contactRequest.ringId
            })
            .subscribe(onNext: { lookupNameResponse in
                if lookupNameResponse.state == .found && !lookupNameResponse.name.isEmpty {
                    item.userName.value = lookupNameResponse.name
                } else {
                    item.userName.value = lookupNameResponse.address
                }
            })
            .disposed(by: self.disposeBag)

        self.nameService.lookupAddress(withAccount: (accountsService.currentAccount?.id)!,
                                              nameserver: "",
                                              address: item.contactRequest.ringId)
    }
}
