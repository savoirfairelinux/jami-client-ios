/*
 *  Copyright (C) 2019 Savoir-faire Linux Inc.
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

import RxSwift
import SwiftyBeaver
import RxRelay

class ContactPickerViewModel: ViewModel {
    private let log = SwiftyBeaver.self

    private var contactsOnly: Bool { self.currentCallId.isEmpty }
    var contactSelectedCB: ((_ contact: [ConferencableItem]) -> Void)?
    var loading = BehaviorRelay(value: true)
    var conversationSelectedCB: ((_ conversaionIds: [String]) -> Void)?
    let injectionBag: InjectionBag

    var currentCallId = ""
    lazy var conferensableItems: Observable<[ContactPickerSection]> = {
        if contactsOnly {
            return self.contactsService.contacts
                .asObservable()
                .map { [weak self] contacts in
                    var sections = [ContactPickerSection]()
                    self?.addContactsToContactPickerSections(contacts: contacts, sections: &sections)
                    self?.loading.accept(false)
                    return sections
                }
        }
        return Observable
            .combineLatest(self.contactsService.contacts.asObservable(),
                           self.callService.calls.observable) {[weak self] (contacts, calls) -> [ContactPickerSection] in
                var sections = [ContactPickerSection]()
                guard let self = self else { return sections }
                guard let currentCall = self.callService.call(callID: self.currentCallId) else { return sections }
                let callURIs = self.addCallsToContactPickerSections(calls: calls, sections: &sections)
                self.addContactsToContactPickerSections(contacts: contacts, sections: &sections, urlToExclude: callURIs)
                self.loading.accept(false)
                return sections
            }
    }()

    lazy var searchResultItems: Observable<[ContactPickerSection]> = {
        return Observable
            .combineLatest(search
                            .startWith("")
                            .distinctUntilChanged(), self.conferensableItems) { (search, targets) in (search, targets) }
            .map({ (arg) -> [ContactPickerSection] in
                var (search, targets) = arg
                if search.isEmpty {
                    return targets
                }
                let result = targets.map {(section: ContactPickerSection) -> ContactPickerSection in
                    var sectionVariable = section
                    let newItems = section.items.map { (item: ConferencableItem) -> ConferencableItem in
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
                    .filter { (item: ConferencableItem) -> Bool in
                        return !item.contacts.isEmpty
                    }
                    sectionVariable.items = newItems
                    return sectionVariable
                }
                .filter { (section: ContactPickerSection) -> Bool in
                    return !section.items.isEmpty
                }
                return result
            })
    }()

    lazy var conversationsSearchResultItems: Observable<[ConversationPickerSection]> = {
        return Observable
            .combineLatest(search
                            .startWith("")
                            .distinctUntilChanged(), self.conversations) { (search, targets) in (search, targets) }
            .map({ (arg) -> [ConversationPickerSection] in
                var (search, targets) = arg
                if search.isEmpty {
                    return targets
                }
                let result = targets.map {(section: ConversationPickerSection) -> ConversationPickerSection in
                    var sectionVariable = section
                    let newItems = section.items.filter { item in
                        item.contains(searchQuery: search)
                    }
                    sectionVariable.items = newItems
                    return sectionVariable
                }
                .filter { (section: ConversationPickerSection) -> Bool in
                    return !section.items.isEmpty
                }
                return result
            })
    }()

    lazy var conversations: Observable<[ConversationPickerSection]> = { [weak self] in
        guard let self = self else { return Observable.empty() }
        var conversationInfos = self.conversationsService
            .conversations
            .value
            .compactMap({ conversationModel in
                return SwarmInfo(injectionBag: self.injectionBag,
                                 conversation: conversationModel)
            })
        if conversationInfos.isEmpty {
            conversationInfos = [SwarmInfo]()
        }
        self.loading.accept(false)
        let section = ConversationPickerSection(items: conversationInfos)
        return Observable.just([section])
    }()

    let search = PublishSubject<String>()
    private let disposeBag = DisposeBag()

    private let contactsService: ContactsService
    private let conversationsService: ConversationsService
    private let callService: CallsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let presenceService: PresenceService
    private let videoService: VideoService
    private let nameService: NameService

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.callService = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.presenceService = injectionBag.presenceService
        self.videoService = injectionBag.videoService
        self.nameService = injectionBag.nameService
        self.conversationsService = injectionBag.conversationsService
        self.injectionBag = injectionBag
    }

    func contactSelected(contacts: [ConferencableItem]) {
        if contacts.isEmpty { return }
        if contactSelectedCB != nil {
            contactSelectedCB!(contacts)
        }
    }

    func conversationSelected(conversaionIds: [String]) {
        if conversaionIds.isEmpty { return }
        if conversationSelectedCB != nil {
            conversationSelectedCB!(conversaionIds)
        }
    }
}

// MARK: - ContactPickerSections
extension ContactPickerViewModel {
    func addContactsToContactPickerSections(contacts: [ContactModel], sections: inout [ContactPickerSection], urlToExclude: [String] = [String]()) {
        guard let currentAccount = self.accountService.currentAccount else {
            return
        }
        var contactItems = [ConferencableItem]()
        contacts.forEach { contact in
            guard let contactUri = contact.uriString else { return }
            if urlToExclude.contains(contactUri) {
                return
            }
            let contactToAdd = Contact(contactUri: contactUri,
                                       accountId: currentAccount.id,
                                       registeredName: contact.userName ?? "",
                                       presService: self.presenceService,
                                       nameService: self.nameService,
                                       hash: contact.hash,
                                       profileService: self.profileService)
            let contactItem = ConferencableItem(conferenceID: "", contacts: [contactToAdd])
            contactItems.append(contactItem)
        }
        if !contactItems.isEmpty {
            sections.append(ContactPickerSection(header: "contacts", items: contactItems))
        }
    }

    func addCallsToContactPickerSections(calls: [String: CallModel], sections: inout [ContactPickerSection]) -> [String] {
        var callURIs = [String]()
        guard let currentCall = self.callService.call(callID: self.currentCallId) else {
            return callURIs
        }
        var callItems = [ConferencableItem]()
        var conferences = [String: [Contact]]()
        calls.values.forEach { call in
            guard let account = self.accountService.getAccount(fromAccountId: call.accountId) else { return }
            let type = account.type == AccountType.ring ? URIType.ring : URIType.sip
            let uri = JamiURI.init(schema: type, infoHash: call.callUri, account: account)
            guard let uriString = uri.uriString else { return }
            guard let hashString = uri.hash else { return }
            callURIs.append(uriString)
            if currentCall.participantsCallId.contains(call.callId) ||
                call.callId == self.currentCallId {
                return
            }
            if call.state != .current && call.state != .hold && call.state != .unhold {
                return
            }
            let contact = Contact(contactUri: uriString,
                                  accountId: call.accountId, registeredName: call.registeredName,
                                  presService: self.presenceService,
                                  nameService: self.nameService,
                                  hash: hashString,
                                  profileService: self.profileService)
            if call.participantsCallId.count == 1 {
                let confItem = ConferencableItem(conferenceID: call.callId, contacts: [contact])
                callItems.append(confItem)
            } else if var conf = conferences[call.callId] {
                conf.append(contact)
            } else {
                var contacts = [Contact]()
                contacts.append(contact)
                conferences[call.callId] = contacts
            }
        }
        conferences.keys.forEach { conferenceID in
            guard let confContacts = conferences[conferenceID] else { return }
            let conferenceItem = ConferencableItem(conferenceID: conferenceID, contacts: confContacts)
            callItems.append(conferenceItem)
        }
        if !callItems.isEmpty {
            callItems.sort(by: { (first, second) -> Bool in
                return first.contacts.count > second.contacts.count
            })
            sections.append(ContactPickerSection(header: "calls", items: callItems))
        }
        return callURIs
    }
}
