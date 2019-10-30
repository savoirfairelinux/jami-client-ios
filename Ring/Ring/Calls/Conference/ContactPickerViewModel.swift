//
//  ContactPickerViewModel.swift
//  Ring
//
//  Created by kate on 2019-11-01.
//  Copyright © 2019 Savoir-faire Linux. All rights reserved.
//

import RxSwift
import SwiftyBeaver

class ContactPickerViewModel: Stateable, ViewModel {
    private let log = SwiftyBeaver.self

    // MARK: - Rx Stateable
    private let stateSubject = PublishSubject<State>()
    lazy var state: Observable<State> = {
        return self.stateSubject.asObservable()
    }()
    lazy var conferensableItems: Observable<[ContactPickerSection]> = {
        return Observable.combineLatest(self.contactsService.contacts.asObservable(),
                                        self.callService.calls.asObservable()) {(contacts, calls) -> [ContactPickerSection] in
                                            var callURIs = [String]()
                                            var callItems = [ConferencableItem]()
                                            var contactItems = [ConferencableItem]()
                                            var conferences = [String: [Contact]]()
                                            calls.values.forEach { call in
                                                callURIs.append(call.participantUri)
                                                var contact = Contact(contactUri: call.participantUri, accountId: call.accountId, name: call.displayName, profService: self.profileService)
                                                if call.conferenceId == call.callId {
                                                    let confItem = ConferencableItem(conferenceID: call.conferenceId, contacts: [contact])
                                                    callItems.append(confItem)
                                                } else if var conf = conferences[call.conferenceId] {
                                                    conf.append(contact)
                                                } else {
                                                    var contacts = [Contact]()
                                                    contacts.append(contact)
                                                    conferences[call.conferenceId] = contacts
                                                }
                                            }
                                            conferences.keys.forEach { conferenceID in
                                                guard let confContacts = conferences[conferenceID] else { return }
                                                let conferenceItem = ConferencableItem(conferenceID: conferenceID, contacts: confContacts)
                                                callItems.append(conferenceItem)
                                            }
                                            var sections = [ContactPickerSection]()
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
                                                guard let contactUri = contact.uriString else {return}
                                                if callURIs.contains(contactUri) {
                                                    return
                                                }
                                                var contactToAdd = Contact(contactUri: contactUri, accountId: currentAccount.id, name: contact.userName ?? "", profService: self.profileService)
                                                contactToAdd.presenceStatus = self.presenceService
                                                    .contactPresence[contactUri]?.asObservable()
                                                let contactItem = ConferencableItem(conferenceID: "", contacts: [contactToAdd])
                                                contactItems.append(contactItem)
                                            }
                                            if !contactItems.isEmpty {
                                                sections.append(ContactPickerSection(header: "contaxcts", items: contactItems))
                                            }
                                            return sections
        }
    }()

    lazy var searchResultItems: Observable<[ContactPickerSection]> = {
        return search
            .startWith("")
            .distinctUntilChanged()
            .withLatestFrom(self.conferensableItems) { (search, targets) in (search, targets)}
            .map({ (arg) -> [ContactPickerSection] in
                let (search, targets) = arg
                targets.forEach { section in
                    section.items.forEach { item in
                        _ = item.contacts.filter { contact in
                            return (contact.displayName.contains(" \(search)") || contact.uri.contains(" \(search)"))
                        }
                    }
                }
                return targets
            })
        //.asDriver(onErrorJustReturn: [])
    }()

    let search = PublishSubject<String>()
    fileprivate let disposeBag = DisposeBag()
//
//    //Services
    fileprivate let contactsService: ContactsService
    fileprivate let callService: CallsService
    fileprivate let profileService: ProfilesService
    fileprivate let accountService: AccountsService
    fileprivate let presenceService: PresenceService

    required init(with injectionBag: InjectionBag) {
        self.contactsService = injectionBag.contactsService
        self.callService = injectionBag.callService
        self.profileService = injectionBag.profileService
        self.accountService = injectionBag.accountService
        self.presenceService = injectionBag.presenceService
    }
    
    func addContactToConference() {
        
    }
}
