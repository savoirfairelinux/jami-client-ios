/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

import Reusable
import RxSwift

class BlockListViewModel: ViewModel {

    let contactService: ContactsService
    let accountService: AccountsService
    let nameService: NameService
    let disposeBag = DisposeBag()

    lazy var currentAccountId: String? = {
        return self.accountService.currentAccount?.id
    }()

    lazy var blockedContactsItems: Observable<[BannedContactItem]> = {
        return self.contacts.asObservable().map({ [weak self] contacts in
            var bannedItems = [BannedContactItem]()
            _ = contacts.filter {contact in contact.banned}
                .map ({ contact in
                    let items = self?.initialItems.filter({ item in
                        return item.contact.hash == contact.hash
                    })
                    if let first = items?.first {
                        bannedItems.append(first)
                    }
                })
            return bannedItems
        })
    }()

    lazy var contacts: Variable<[ContactModel]> = {
        return self.contactService.contacts
    }()

    lazy var contactListNotEmpty: Observable<Bool> = {
        return self.contacts.asObservable().map({ contacts in
            return contacts.filter {contact in contact.banned}
        }).map({ contacts in
            return !contacts.isEmpty
        })
    }()

    // create list of banned items with photo and name
    lazy var initialItems: [BannedContactItem] = {
        guard let accountId = currentAccountId else {return [BannedContactItem]()}
        return self.contactService.contacts.value
            .filter({ contact in contact.banned})
            .map { contact in
                var item = BannedContactItem(withContact: contact)
                if let uri = contact.uriString {
                    self.contactService.getProfileForUri(uri: uri,
                                                         accountId: accountId)
                        .subscribe(onNext: { (profile) in
                            item.displayName = profile.alias
                            guard let photo = profile.photo else {
                                return
                            }
                            guard let data = NSData(base64Encoded: photo,
                                                    options: NSData.Base64DecodingOptions
                                                        .ignoreUnknownCharacters) as Data? else {
                                                            return
                            }
                            item.image = data
                        }).disposed(by: self.disposeBag)
                }
                if contact.userName == nil || contact.userName! == "" {
                    self.nameService.usernameLookupStatus.single()
                        .filter({ lookupNameResponse in
                            return lookupNameResponse.address != nil &&
                                lookupNameResponse.address == contact.hash
                        })
                        .subscribe(onNext: { [weak self] lookupNameResponse in
                            if let name = lookupNameResponse.name, !name.isEmpty {
                                contact.userName = name
                            }
                        }).disposed(by: self.disposeBag)
                    self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: contact.hash)
                }
                return item
        }
    }()

    required init(with injectionBag: InjectionBag) {
        self.contactService = injectionBag.contactsService
        self.accountService = injectionBag.accountService
        self.nameService = injectionBag.nameService
    }

    func unbanContact(contact: ContactModel) {
        guard let account = self.accountService.currentAccount else {
            return
        }
        self.contactService.unbanContact(contact: contact, account: account)
    }
}
