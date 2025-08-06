/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
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

import UIKit
import SwiftUI
import RxSwift

class BlockedContactsRowVM: ObservableObject, Identifiable, AvatarViewDataModel {

    @Published var profileImage: UIImage?
    @Published var profileName = ""
    @Published var username: String?

    let profileService: ProfilesService
    let nameService: NameService
    let contactsService: ContactsService
    let presenceService: PresenceService
    let account: AccountModel
    let contact: ContactModel
    let id: String

    let avatarSize: CGFloat = Constants.defaultAvatarSize

    let disposeBag = DisposeBag()

    init(contact: ContactModel, account: AccountModel, injectionBag: InjectionBag) {
        self.profileService = injectionBag.profileService
        self.nameService = injectionBag.nameService
        self.contactsService = injectionBag.contactsService
        self.presenceService = injectionBag.presenceService
        self.account = account
        self.contact = contact
        self.id = contact.hash

        self.getProfile()
        self.getRegisteredName()
    }

    private func getProfile() {
        if let uri = contact.uriString {
            self.profileService.getProfile(uri: uri, createIfNotexists: false, accountId: account.id)
                .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self ](profile) in
                    guard let self = self else { return }
                    // The view size is avatarSize. Create a larger image for better resolution.
                    if let avatar = profile.photo,
                       let image = avatar.createImage(size: self.avatarSize * 2) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.profileImage = image
                        }
                    }
                    if let alias = profile.alias {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.profileName = alias
                        }
                    }
                })
                .disposed(by: self.disposeBag)
        }
    }

    private func getRegisteredName() {
        if let registeredName = contact.userName, !registeredName.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.username = registeredName
            }
        } else {
            self.nameService.usernameLookupStatus.single()
                .filter({ [weak self] lookupNameResponse in
                    guard let self = self else { return false }
                    return lookupNameResponse.requestedName != nil &&
                        lookupNameResponse.requestedName == self.contact.hash
                })
                .subscribe(onNext: {[weak self] lookupNameResponse in
                    guard let self = self else { return }
                    if let name = lookupNameResponse.name, !name.isEmpty {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.username = name
                            contact.userName = name
                        }
                    }
                })
                .disposed(by: self.disposeBag)
            self.nameService.lookupAddress(withAccount: account.id, nameserver: "", address: contact.hash)
        }
    }

    func unblock() {
        self.contactsService.unbanContact(contact: contact, account: account)
        self.presenceService.subscribeBuddy(withAccountId: account.id,
                                            withJamiId: contact.hash,
                                            withFlag: true)
    }
}

class BlockedContactsVM: ObservableObject {
    @Published var blockedContacts = [BlockedContactsRowVM]()
    let contactService: ContactsService
    let injectionBag: InjectionBag
    let disposeBag = DisposeBag()
    let account: AccountModel

    init(account: AccountModel, injectionBag: InjectionBag) {
        self.account = account
        self.injectionBag = injectionBag
        self.contactService = injectionBag.contactsService
        self.loadBannedContacts()
    }

    func loadBannedContacts() {
        self.contactService.contacts
            .startWith(self.contactService.contacts.value)
            .map { [weak self] contacts -> [BlockedContactsRowVM] in
                contacts.compactMap { contact -> BlockedContactsRowVM? in
                    guard let self = self, contact.banned else {
                        return nil
                    }
                    return BlockedContactsRowVM(contact: contact, account: self.account, injectionBag: self.injectionBag)
                }
            }
            .subscribe(onNext: { [weak self] blockedContactsRows in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.blockedContacts = blockedContactsRows
                }
            })
            .disposed(by: disposeBag)

        self.contactService.sharedResponseStream
            .filter({ $0.eventType == ServiceEventType.contactAdded })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      self.account.id == accountId
                else { return }
                let bannedContacts = self.contactService.contacts.value.compactMap { contact -> BlockedContactsRowVM? in
                    guard contact.banned else {
                        return nil
                    }
                    return BlockedContactsRowVM(contact: contact, account: self.account, injectionBag: self.injectionBag)
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.blockedContacts = bannedContacts
                }

            })
            .disposed(by: self.disposeBag)
    }
}
