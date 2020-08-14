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

class ContactPickerViewModel: Stateable, ViewModel {
    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    var currentCallId = ""
    lazy var conferensableItems: Observable<[ContactPickerSection]> = {
        return Observable
            .combineLatest(self.contactsService.contacts.asObservable(),
                           self.callService.calls.asObservable()) {(contacts, calls) -> [ContactPickerSection] in
                            var sections = [ContactPickerSection]()
                            guard let currentCall = self.callService.call(callID: self.currentCallId) else { return sections }
                            var callURIs = [String]()
                            var callItems = [ConferencableItem]()
                            var contactItems = [ConferencableItem]()
                            var conferences = [String: [Contact]]()
                            calls.values.forEach { call in
                                guard let account = self.accountService.getAccount(fromAccountId: call.accountId) else { return }
                                let type = account.type == AccountType.ring ? URIType.ring : URIType.sip
                                let uri = JamiURI.init(schema: type, infoHach: call.participantUri, account: account)
                                guard let uriString = uri.uriString else { return }
                                guard let hashString = uri.hash else { return }
                                callURIs.append(uriString)
                                if currentCall.participantsCallId.contains(call.callId) ||
                                    call.callId == self.currentCallId {
                                    return
                                }
                                if call.state != .current || call.state != .hold || call.state != .unhold {
                                    return
                                }
                                let profile = self.contactsService.getProfile(uri: uriString, accountId: call.accountId)
                                var contact = Contact(contactUri: uriString,
                                                      accountId: call.accountId,
                                                      registrName: call.registeredName,
                                                      presService: self.presenceService,
                                                      contactProfile: profile)
                                contact.hash = hashString
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
                            guard let currentAccount = self.accountService.currentAccount else {
                                return sections
                            }
                            contacts.forEach { contact in
                                guard let contactUri = contact.uriString else { return }
                                if callURIs.contains(contactUri) {
                                    return
                                }
                                let profile = self.contactsService.getProfile(uri: contactUri, accountId: currentAccount.id)
                                var contactToAdd = Contact(contactUri: contactUri,
                                                           accountId: currentAccount.id,
                                                           registrName: contact.userName ?? "",
                                                           presService: self.presenceService,
                                                           contactProfile: profile)

                                contactToAdd.hash = contact.hash
                                let contactItem = ConferencableItem(conferenceID: "", contacts: [contactToAdd])
                                contactItems.append(contactItem)
                            }
                            if !contactItems.isEmpty {
                                sections.append(ContactPickerSection(header: "contacts", items: contactItems))
                            }
                            return sections
            }
    }()

    lazy var searchResultItems: Observable<[ContactPickerSection]> = {
        return search
            .startWith("")
            .distinctUntilChanged()
            .withLatestFrom(self.conferensableItems) { (search, targets) in (search, targets) }
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
                            return mutableContact.firstLine.lowercased().contains(searchLowercased) ||
                                mutableContact.secondLine.lowercased()
                                    .contains(searchLowercased) ||
                                mutableContact.hash.lowercased()
                                    .contains(searchLowercased)
                        }
                        mutabeItem.contacts = newContacts
                        return mutabeItem
                    }.filter { (item: ConferencableItem) -> Bool in
                        return !item.contacts.isEmpty
                    }
                    sectionVariable.items = newItems
                    return sectionVariable
                }.filter { (section: ContactPickerSection) -> Bool in
                        return !section.items.isEmpty
                }
                return result
            })
    }()

    let search = PublishSubject<String>()
    private let disposeBag = DisposeBag()

    private let contactsService: ContactsService
    private let callService: CallsService
    private let profileService: ProfilesService
    private let accountService: AccountsService
    private let presenceService: PresenceService
    private let videoService: VideoService

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.callService = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.presenceService = injectionBag.presenceService
        self.videoService = injectionBag.videoService
    }

    func addContactToConference(contact: ConferencableItem) {
        guard let contactToAdd = contact.contacts.first else { return }
        guard let account = self.accountService.getAccount(fromAccountId: contactToAdd.accountID) else { return }
        guard let call = self.callService.call(callID: currentCallId) else { return }
        if contact.conferenceID.isEmpty {
            if self.videoService.getEncodingAccelerated() {
                self.callService.hold(callId: currentCallId).subscribe().disposed(by: disposeBag)
                self.videoService.disableHardwareForConference()
                self.callService.unhold(callId: currentCallId).subscribe().disposed(by: disposeBag)
            }
            self.callService
                .callAndAddParticipant(participant: contactToAdd.uri,
                                       toCall: currentCallId,
                                       withAccount: account,
                                       userName: contactToAdd.registeredName,
                                       isAudioOnly: call.isAudioOnly)
                .subscribe().disposed(by: self.disposeBag)
            return
        }
        guard let secondCall = self.callService.call(callID: contact.conferenceID) else { return }
        if call.participantsCallId.count == 1 {
            self.callService.joinCall(firstCall: call.callId, secondCall: secondCall.callId)
        } else {
            self.callService.joinConference(confID: contact.conferenceID, callID: currentCallId)
        }
    }
}
