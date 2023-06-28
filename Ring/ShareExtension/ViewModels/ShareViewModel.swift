/*
 * Copyright (C) 2023 Savoir-faire Linux Inc. *
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details. *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

import RxSwift
import SwiftyBeaver

class ShareViewModel {
    private let log = SwiftyBeaver.self

    private let daemonService = ShareAdapterService(withAdapter: ShareAdapter())
    private let nameService = ShareNameService(withNameRegistrationAdapter: ShareAdapter())
    lazy var injectionBag: ShareInjectionBag = {
        return ShareInjectionBag(withDaemonService: self.daemonService, nameService: nameService)
    }()

    var contactSelectedCB: ((_ contact: [ShareConferencableItem]) -> Void)?

    lazy var conferensableItems: Observable<[ShareContactPickerSection]> = {
        return Observable
            .just([])
    }()

    lazy var searchResultItems: Observable<[ShareContactPickerSection]> = {
        return search
            .startWith("")
            .distinctUntilChanged()
            .withLatestFrom(self.conferensableItems) { (search, targets) in (search, targets) }
            .map({ (arg) -> [ShareContactPickerSection] in
                var (search, targets) = arg
                if search.isEmpty {
                    return targets
                }
                let result = targets.map {(section: ShareContactPickerSection) -> ShareContactPickerSection in
                    var sectionVariable = section
                    let newItems = section.items.map { (item: ShareConferencableItem) -> ShareConferencableItem in
                        var mutabeItem = item
                        let newContacts = item.contacts.filter { contact in
                            var mutableContact = contact
                            let searchLowercased = search.lowercased()
                            return mutableContact.firstLine.value.lowercased().contains(searchLowercased) ||
                                mutableContact.secondLine.lowercased()
                                .contains(searchLowercased) ||
                                mutableContact.hash.lowercased()
                                .contains(searchLowercased)
                        }
                        mutabeItem.contacts = newContacts
                        return mutabeItem
                    }
                    .filter { (item: ShareConferencableItem) -> Bool in
                        return !item.contacts.isEmpty
                    }
                    sectionVariable.items = newItems
                    return sectionVariable
                }
                .filter { (section: ShareContactPickerSection) -> Bool in
                    return !section.items.isEmpty
                }
                return result
            })
    }()

    let search = PublishSubject<String>()
    private let disposeBag = DisposeBag()

    required init() {
        self.daemonService.start()
        _ = self.daemonService.loadAccounts()

        // Subscribe to the conversations property and update conferensableItems
        daemonService.conversations
            .subscribe(onNext: { _ in

            })
            .disposed(by: disposeBag)

        //            .map { conversationsList in
        //                var sections = [ShareContactPickerSection]()
        //                for conversations in conversationsList {
        //                    let items = conversations.map({ conversation in
        //                        var item = ShareConversationViewModel(with: self.injectionBag)
        //                        item.setConversation(conversation)
        //                        return item
        //                    })
        //                    sections.append(ShareContactPickerSection(header: "1", items: []))
        //                }
        //                return sections
        //            }
        //            .bind(to: conferensableItems)
        //            .disposed(by: disposeBag)
    }

    func contactSelected(contacts: [ShareConferencableItem]) {
        if contacts.isEmpty { return }
        if contactSelectedCB != nil {
            contactSelectedCB!(contacts)
        }
    }

    func startDaemon() {
        self.daemonService.start()
    }

    func stopDaemon() {
        self.daemonService.stop()
    }
}

// MARK: - ContactPickerSections
extension ShareViewModel {
    //        func addContactsToContactPickerSections(contacts: [ConversationTableViewCell], sections: inout [ShareContactPickerSection], urlToExclude: [String] = [String]()) {
    //            guard let currentAccount = self.daemonService.currentAccount else {
    //                return
    //            }
    //            var contactItems = [ShareConferencableItem]()
    //            contacts.forEach { contact in
    //                guard let contactUri = contact.uriString else { return }
    //                if urlToExclude.contains(contactUri) {
    //                    return
    //                }
    //                let profile = self.daemonService.getProfile(uri: contactUri, accountId: currentAccount.id)
    //                var contactToAdd = ShareContact(contactUri: contactUri,
    //                                           accountId: currentAccount.id,
    //                                           registeredName: contact.userName ?? "",
    //                                           contactProfile: profile,
    //                                           hash: contact.hash)
    //                if contact.userName == nil || contact.userName! == "" {
    //                    self.nameService.usernameLookupStatus.single()
    //                        .filter({[weak contact] lookupNameResponse in
    //                            return lookupNameResponse.address != nil &&
    //                                lookupNameResponse.address == contact?.hash
    //                        })
    //                        .take(1)
    //                        .subscribe(onNext: {[weak contactToAdd] lookupNameResponse in
    //                            if let name = lookupNameResponse.name, !name.isEmpty {
    //                                contactToAdd?.registeredNameFound(name: name)
    //                            }
    //                        })
    //                        .disposed(by: self.disposeBag)
    //                    self.nameService.lookupAddress(withAccount: currentAccount.id, nameserver: "", address: contact.hash)
    //                }
    //                let contactItem = ShareConferencableItem(conferenceID: "", contacts: [contactToAdd])
    //                contactItems.append(contactItem)
    //            }
    //            if !contactItems.isEmpty {
    //                sections.append(ShareContactPickerSection(header: "contacts", items: contactItems))
    //            }
    //        }
}
