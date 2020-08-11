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

enum ContactServiceError: Error {
    case acceptTrustRequestFailed
    case diacardTrusRequestFailed
    case vCardSerializationFailed
    case loadVCardFailed
    case saveVCardFailed
    case removeContactFailed
}

class ContactsService {

    fileprivate let contactsAdapter: ContactsAdapter
    fileprivate let log = SwiftyBeaver.self
    fileprivate let disposeBag = DisposeBag()

    let contactRequests = Variable([ContactRequestModel]())
    let contacts = Variable([ContactModel]())

    let contactStatus = PublishSubject<ContactModel>()

    fileprivate let responseStream = PublishSubject<ServiceEvent>()
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
        guard let contact = self.contacts.value.filter({ $0.uriString == uri }).first else {
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

    func contactRequest(withRingId ringId: String) -> ContactRequestModel? {
        guard let contactRequest = self.contactRequests.value.filter({ $0.ringId == ringId }).first else {
            return nil
        }
        return contactRequest
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
        self.contacts.value.removeAll()
        for contact in contacts {
            if self.contacts.value.firstIndex(of: contact) == nil {
                self.contacts.value.append(contact)
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
        //Load contacts from daemon
        let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: account)

        //Serialize them
        if let contacts = contactsDictionaries?.map({ contactDict in
            return ContactModel(withDictionary: contactDict)
        }) {
            self.contacts.value.removeAll()
            for contact in contacts {
                if self.contacts.value.firstIndex(of: contact) == nil {
                    self.contacts.value.append(contact)
                    self.log.debug("contact: \(String(describing: contact.userName))")
                }
            }
        }
    }

    func loadContactRequests(withAccount accountId: String) {
        self.contactRequests.value.removeAll()
        //Load trust requests from daemon
        let trustRequestsDictionaries = self.contactsAdapter.trustRequests(withAccountId: accountId)

        //Create contact requests from daemon trust requests
        if let contactRequests = trustRequestsDictionaries?.map({ dictionary in
            return ContactRequestModel(withDictionary: dictionary, accountId: accountId)
        }) {
            for contactRequest in contactRequests {
                if self.contactRequest(withRingId: contactRequest.ringId) == nil {
                    self.contactRequests.value.append(contactRequest)
                }
            }
        }
    }

    func accept(contactRequest: ContactRequestModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            let success = self.contactsAdapter.acceptTrustRequest(fromContact: contactRequest.ringId,
                                                                  withAccountId: account.id)
            if success {
                var stringImage: String?
                if let vCard = contactRequest.vCard, let image = vCard.imageData {
                    stringImage = image.base64EncodedString()
                }
                let name = VCardUtils.getName(from: contactRequest.vCard)
                let uri = JamiURI(schema: URIType.ring, infoHach: contactRequest.ringId)
                let uriString = uri.uriString ?? contactRequest.ringId
                _ = self.dbManager
                    .createOrUpdateRingProfile(profileUri: uriString,
                                               alias: name,
                                               image: stringImage,
                                               accountId: account.id)
                var event = ServiceEvent(withEventType: .contactAdded)
                event.addEventInput(.accountId, value: account.id)
                event.addEventInput(.uri, value: contactRequest.ringId)
                self.responseStream.onNext(event)
                var data = [String: Any]()
                data[ProfileNotificationsKeys.ringID.rawValue] = contactRequest.ringId
                data[ProfileNotificationsKeys.accountId.rawValue] = account.id
                NotificationCenter.default.post(name: NSNotification.Name(ProfileNotifications.contactAdded.rawValue), object: nil, userInfo: data)
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.acceptTrustRequestFailed))
            }

            return Disposables.create { }
        }
    }

    func discard(from jamiId: String, withAccountId accountId: String) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            let success = self.contactsAdapter.discardTrustRequest(fromContact: jamiId,
                                                                   withAccountId: accountId)

            //Update the Contact request list
            self.removeContactRequest(withRingId: jamiId)

            if success {
                var event = ServiceEvent(withEventType: .contactRequestDiscarded)
                event.addEventInput(.accountId, value: accountId)
                event.addEventInput(.uri, value: jamiId)
                self.responseStream.onNext(event)
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.diacardTrusRequestFailed))
            }
            return Disposables.create { }
        }
    }

    func sendContactRequest(toContactRingId ringId: String, withAccount account: AccountModel) -> Completable {
        return Completable.create { [unowned self] completable in
            do {
                var payload: Data?
                if let accountProfile = self.dbManager.accountProfile(for: account.id) {
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
                        payload = try CNContactVCardSerialization.dataWithImageAndUUID(from: vCard, andImageCompression: 40000)
                    }
                }
                self.contactsAdapter.sendTrustRequest(toContact: ringId, payload: payload, withAccountId: account.id)
                var event = ServiceEvent(withEventType: .contactAdded)
                event.addEventInput(.accountId, value: account.id)
                event.addEventInput(.uri, value: ringId)
                self.responseStream.onNext(event)
                completable(.completed)
            } catch {
                completable(.error(ContactServiceError.vCardSerializationFailed))
            }
            return Disposables.create { }
        }
    }

    func addContact(contact: ContactModel, withAccount account: AccountModel) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            self.contactsAdapter.addContact(withURI: contact.hash, accountId: account.id)
            if self.contact(withUri: contact.uriString ?? "") == nil {
                self.contacts.value.append(contact)
            }
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func removeContact(withUri uri: String, ban: Bool, withAccountId accountId: String) -> Observable<Void> {
        return Observable.create { [unowned self] observable in
            guard let hash = JamiURI
                .init(schema: URIType.ring,
                      infoHach: uri).hash else {
                observable.on(.error(ContactServiceError.removeContactFailed))
                return Disposables.create { }
            }
            self.contactsAdapter.removeContact(withURI: hash, accountId: accountId, ban: ban)
            self.removeContactRequest(withRingId: hash)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    fileprivate func removeContactRequest(withRingId ringId: String) {
        guard let contactRequestToRemove = self.contactRequests.value.filter({ $0.ringId == ringId }).first else {
            return
        }
        guard let index = self.contactRequests.value.firstIndex(where: { $0 === contactRequestToRemove }) else {
            return
        }
        self.contactRequests.value.remove(at: index)
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
                self.contacts.value = self.contacts.value
            })
            .disposed(by: self.disposeBag)
    }
}

extension ContactsService: ContactsAdapterDelegate {

    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {

        var vCard: CNContact?
        if let contactVCard = CNContactVCardSerialization.parseToVCard(data: payload) {
            vCard = contactVCard
        }

        //Update trust request list
        if self.contactRequest(withRingId: senderAccount) == nil {
            let contactRequest = ContactRequestModel(withRingId: senderAccount,
                                                     vCard: vCard,
                                                     receivedDate: receivedDate,
                                                     accountId: accountId)
            self.contactRequests.value.append(contactRequest)
            var event = ServiceEvent(withEventType: .contactRequestReceived)
            event.addEventInput(.accountId, value: accountId)
            event.addEventInput(.uri, value: senderAccount)
            event.addEventInput(.date, value: receivedDate)
            self.responseStream.onNext(event)
        } else {
            // If the contact request already exists, update it's relevant data
            if let contactRequest = self.contactRequest(withRingId: senderAccount) {
                contactRequest.vCard = vCard
                contactRequest.receivedDate = receivedDate
            }
            log.debug("Incoming trust request received from :\(senderAccount)")
        }

    }

    func contactAdded(contact uri: String, withAccountId accountId: String, confirmed: Bool) {
        //Update trust request list
        if let hash = JamiURI.init(schema: URIType.ring, infoHach: uri).hash {
            self.removeContactRequest(withRingId: hash)
        }
        // update contact status
        if let contact = self.contact(withUri: uri) {
            self.contactStatus.onNext(contact)
            if contact.confirmed != confirmed {
                contact.confirmed = confirmed
            }
            self.contactStatus.onNext(contact)
        }
            //sync contacts with daemon contacts
        else {

            let contactsDictionaries = self.contactsAdapter.contacts(withAccountId: accountId)

            //Serialize them
            if let contacts = contactsDictionaries?.map({ contactDict in
                return ContactModel(withDictionary: contactDict)
            }) {
                for contact in contacts {
                    if self.contacts.value.firstIndex(of: contact) == nil {
                        self.contacts.value.append(contact)
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

    func getContactRequestVCard(forContactWithRingId ringID: String) -> Single<CNContact> {
        return Single.create(subscribe: { single in
            if let contactRequest = self.contactRequest(withRingId: ringID) {
                if let vCard = contactRequest.vCard {
                    single(.success(vCard))
                } else {
                    single(.error(ContactServiceError.loadVCardFailed))
                }
            } else {
                single(.error(ContactServiceError.loadVCardFailed))
            }
            return Disposables.create { }
        })
    }

    func getProfileForUri(uri: String, accountId: String) -> Observable<Profile> {
        return self.dbManager.profileObservable(for: uri, createIfNotExists: false, accountId: accountId)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
    }

    func getProfile(uri: String, accountId: String) -> Profile? {
        do {
            return try self.dbManager.getProfile(for: uri, createIfNotExists: false, accountId: accountId)
        } catch {
            return nil
        }
    }

    func removeAllContacts(for accountId: String) {
        DispatchQueue.global(qos: .background).async {
            for contact in self.contacts.value {
                self.contactsAdapter.removeContact(withURI: contact.hash, accountId: accountId, ban: false)
            }
            self.contacts.value.removeAll()
            self.contactRequests.value.forEach { (request) in
                self.contactsAdapter.discardTrustRequest(fromContact: request.ringId, withAccountId: accountId)
            }
            self.contactRequests.value.removeAll()
            self.dbManager
                .clearAllHistoryFor(accountId: accountId)
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
}
