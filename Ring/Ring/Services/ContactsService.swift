/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import Contacts
import SwiftyBeaver
import RxSwift
import RxRelay

enum ContactServiceError: Error {
    case acceptTrustRequestFailed
    case diacardTrusRequestFailed
    case vCardSerializationFailed
    case loadVCardFailed
    case saveVCardFailed
    case removeContactFailed
}

class ContactsService {

    private let contactsAdapter: ContactsAdapter
    private let log = SwiftyBeaver.self
    private let disposeBag = DisposeBag()

    let contacts = BehaviorRelay(value: [ContactModel]())

    let contactStatus = PublishSubject<ContactModel>()

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>
    let dbManager: DBManager

    init(withContactsAdapter contactsAdapter: ContactsAdapter, dbManager: DBManager) {
        self.contactsAdapter = contactsAdapter
        self.responseStream.disposed(by: disposeBag)
        self.sharedResponseStream = responseStream.share()
        self.dbManager = dbManager
        ContactsAdapter.delegate = self
    }

    func contact(withUri uri: String) -> ContactModel? {
        guard let contact = self.contacts.value.filter({ $0.hash == uri }).first else {
            return nil
        }
        return contact
    }

    func contact(withHash hash: String) -> ContactModel? {
        guard let contact = self.contacts.value.filter({ $0.hash == hash }).first else {
            return nil
        }
        return contact
    }

    func loadContacts(withAccount account: AccountModel) {
        if AccountModelHelper.init(withAccount: account).isAccountSip() {
            self.loadSipContacts(withAccount: account)
            return
        }
        loadJamiContacts(withAccount: account.id)
    }

    func loadSipContacts(withAccount account: AccountModel) {
        guard let profiles = self.dbManager
            .getProfilesForAccount(accountId: account.id) else { return }
        let contacts = profiles.map({ profile in
            return ContactModel(withUri: JamiURI.init(schema: URIType.sip, infoHach: profile.uri))
        })
        self.contacts.accept([])
        for contact in contacts {
            if self.contacts.value.firstIndex(of: contact) == nil {
                var values = self.contacts.value
                values.append(contact)
                self.contacts.accept(values)
                self.log.debug("contact: \(String(describing: contact.userName))")
            }
        }
    }

    func saveContactsForLinkedAccount(accountId: String) {
        loadJamiContacts(withAccount: accountId)
        self.contacts.value.forEach { (contact) in
            guard let uriString = contact.uriString else { return }
            dbManager.createConversationsFor(contactUri: uriString, accountId: accountId)
        }
    }

    func loadJamiContacts(withAccount account: String) {
        // Load contacts from daemon
        let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: account)

        // Serialize them
        if let contacts = contactsDictionaries?.map({ contactDict in
            return ContactModel(withDictionary: contactDict)
        }) {
            self.contacts.accept([])
            for contact in contacts {
                if self.contacts.value.firstIndex(of: contact) == nil {
                    var values = self.contacts.value
                    values.append(contact)
                    self.contacts.accept(values)
                    self.log.debug("contact: \(String(describing: contact.userName))")
                }
            }
        }
    }

    func sendContactRequest(toContactRingId ringId: String, withAccount accountId: String) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create { } }
            do {
                var payload: Data?
                if let accountProfile = self.dbManager.accountProfile(for: accountId) {
                    let vCard = CNMutableContact()
                    var cardChanged = false
                    if let name = accountProfile.alias {
                        vCard.familyName = name
                        cardChanged = true
                    }
                    if let photo = accountProfile.photo {
                        vCard.imageData = NSData(base64Encoded: photo,
                                                 options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as Data?
                        cardChanged = true
                    }
                    if cardChanged {
                        payload = try CNContactVCardSerialization.dataWithImageAndUUID(from: vCard, andImageCompression: 40000, encoding: .utf8)
                    }
                }
                self.contactsAdapter.sendTrustRequest(toContact: ringId, payload: payload, withAccountId: accountId)
//                var event = ServiceEvent(withEventType: .contactAdded)
//                event.addEventInput(.accountId, value: accountId)
//                event.addEventInput(.uri, value: ringId)
//                self.responseStream.onNext(event)
                completable(.completed)
            } catch {
                completable(.error(ContactServiceError.vCardSerializationFailed))
            }
            return Disposables.create { }
        }
    }

    func addContact(contact: ContactModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            self.contactsAdapter.addContact(withURI: contact.hash, accountId: account.id)
            if self.contact(withUri: contact.uriString ?? "") == nil {
                var values = self.contacts.value
                values.append(contact)
                self.contacts.accept(values)
            }
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func removeContact(withUri uri: String, ban: Bool, withAccountId accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            guard let hash = JamiURI
                .init(schema: URIType.ring,
                      infoHach: uri).hash else {
                observable.on(.error(ContactServiceError.removeContactFailed))
                return Disposables.create { }
            }
            self.contactsAdapter.removeContact(withURI: hash, accountId: accountId, ban: ban)
           // self.removeContactRequest(withRingId: hash)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    private func removeContactRequest(withRingId ringId: String) {
//        guard let contactRequestToRemove = self.contactRequests.value.filter({ $0.ringId == ringId }).first else {
//            return
//        }
//        guard let index = self.contactRequests.value.firstIndex(where: { $0 === contactRequestToRemove }) else {
//            return
//        }
//        var values = self.contactRequests.value
//        values.remove(at: index)
//        self.contactRequests.accept(values)
    }

    func unbanContact(contact: ContactModel, account: AccountModel) {
        contact.banned = false
        self.addContact(contact: contact,
                        withAccount: account)
            .subscribe( onCompleted: {
                var event = ServiceEvent(withEventType: .contactAdded)
                event.addEventInput(.accountId, value: account.id)
                event.addEventInput(.uri, value: contact.hash)
                self.responseStream.onNext(event)
                self.contactStatus.onNext(contact)
                self.contacts.accept(self.contacts.value)
            })
            .disposed(by: self.disposeBag)
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {

//        var vCard: CNContact?
//        if let contactVCard = CNContactVCardSerialization.parseToVCard(data: payload) {
//            vCard = contactVCard
//        }
//        // check if contact exists
//        let validContact = self.contacts.value.filter { contact in
//            contact.hash == senderAccount && !contact.banned
//        }.first
//        if validContact != nil {
//            return
//        }
//        // Update trust request list
//        if self.contactRequest(withRingId: senderAccount) == nil {
//            let contactRequest = ContactRequestModel(withRingId: senderAccount,
//                                                     vCard: vCard,
//                                                     receivedDate: receivedDate,
//                                                     accountId: accountId)
//            var values = self.contactRequests.value
//            values.append(contactRequest)
//            self.contactRequests.accept(values)
////            var event = ServiceEvent(withEventType: .contactRequestReceived)
////            event.addEventInput(.accountId, value: accountId)
////            event.addEventInput(.uri, value: senderAccount)
////            event.addEventInput(.date, value: receivedDate)
////            self.responseStream.onNext(event)
//        } else {
//            // If the contact request already exists, update it's relevant data
//            if let contactRequest = self.contactRequest(withRingId: senderAccount) {
//                contactRequest.vCard = vCard
//                contactRequest.receivedDate = receivedDate
//            }
//            log.debug("Incoming trust request received from :\(senderAccount)")
//        }

    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        // Update trust request list
//        if let hash = JamiURI.init(schema: URIType.ring, infoHach: uri).hash {
//            self.removeContactRequest(withRingId: hash)
//        }
        // update contact status
        if let contact = self.contact(withUri: uri) {
            self.contactStatus.onNext(contact)
            if contact.confirmed != confirmed {
                contact.confirmed = confirmed
            }
            self.contactStatus.onNext(contact)
        }
            // sync contacts with daemon contacts
        else {

            let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: accountId)

            // Serialize them
            if let contacts = contactsDictionaries?.map({ contactDict in
                return ContactModel(withDictionary: contactDict)
            }) {
                for contact in contacts {
                    if self.contacts.value.firstIndex(of: contact) == nil {
                        var values = self.contacts.value
                        values.append(contact)
                        self.contacts.accept(values)
                        contactStatus.onNext(contact)
                    }
                }
            }

        }
        log.debug("Contact added :\(uri)")
    }

    func contactRemoved(contact uri: String, withAccountId accountId: String, banned: Bool) {
        guard let contactToRemove = self.contacts.value.filter({ $0.hash == uri }).first else {
            return
        }
        contactToRemove.banned = banned
        self.contactStatus.onNext(contactToRemove)
        log.debug("Contact removed :\(uri)")
    }

//    func getContactRequestVCard(forContactWithRingId ringID: String) -> Single<CNContact> {
//        return Single.create(subscribe: { single in
//            if let contactRequest = self.contactRequest(withRingId: ringID) {
//                if let vCard = contactRequest.vCard {
//                    single(.success(vCard))
//                } else {
//                    single(.failure(ContactServiceError.loadVCardFailed))
//                }
//            } else {
//                single(.failure(ContactServiceError.loadVCardFailed))
//            }
//            return Disposables.create { }
//        })
//    }

    func getProfileForUri(uri: String, accountId: String) -> Observable<Profile> {
        return self.dbManager.profileObservable(for: uri, createIfNotExists: false, accountId: accountId)
            .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func getProfile(uri: String, accountId: String) -> Profile? {
        do {
            return try self.dbManager.getProfile(for: uri, createIfNotExists: false, accountId: accountId)
        } catch {
            return nil
        }
    }

    func createProfile(with contactUri: String, alias: String, photo: String, accountId: String) -> Profile? {
        do {
            return try self.dbManager.getProfile(for: contactUri, createIfNotExists: true, accountId: accountId, alias: alias, photo: photo)
        } catch {
            return nil
        }
    }

    func removeAllContacts(for accountId: String) {
        DispatchQueue.global(qos: .background).async {
            for contact in self.contacts.value {
                self.contactsAdapter.removeContact(withURI: contact.hash, accountId: accountId, ban: false)
            }
            self.contacts.accept([])
//            self.contactRequests.value.forEach { (request) in
//                self.contactsAdapter.discardTrustRequest(fromContact: request.ringId, withAccountId: accountId)
//            }
//            self.contactRequests.accept([])
            self.dbManager
                .clearAllHistoryFor(accountId: accountId)
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
}
