/*
 *  Copyright (C) 2021 Savoir-faire Linux Inc.
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

import RxRelay
import RxSwift
import SwiftyBeaver

/*
 This class manages both: conversation and contact request
 Depending on conversation type and swarm support on another side we could have next scenarios:
 - receive only a contact request. When the other side does not support swarm.
 - receive only a conversation request. When the other side does support swarm and we already added contact for the peer.
 - receive both: a conversation request and a contact request. When the other side does support swarm and we do not have contact for the peer. In this case, we will keep only a conversation request.
 This class responsible for saving contacts vcard when contact request accepted or sent
 */

enum RequestServiceError: Error {
    case acceptTrustRequestFailed
    case diacardTrusRequestFailed
}

class RequestsService {
    // MARK: private members

    private let requestsAdapter: RequestsAdapter
    private let log = SwiftyBeaver.self
    private let disposeBag = DisposeBag()

    // MARK: observable requests

    let requests = BehaviorRelay(value: [RequestModel]())
    let dbManager: DBManager

    private let responseStream = PublishSubject<ServiceEvent>()
    var sharedResponseStream: Observable<ServiceEvent>

    // MARK: initial loading

    init(withRequestsAdapter requestsAdapter: RequestsAdapter, dbManager: DBManager) {
        self.dbManager = dbManager
        self.requestsAdapter = requestsAdapter
        sharedResponseStream = responseStream.share()
        /**
         after accepting the request stays in synchronization until other contact became online and conversation synchronized.
         When it happens conversationReady signal is emitted. And we could remove the request.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(conversationReady(_:)),
                                               name: NSNotification
                                                .Name(rawValue: ConversationNotifications
                                                        .conversationReady.rawValue),
                                               object: nil)
    }

    func updateConversationsRequests(withAccount accountId: String) {
        let conversationRequestsDictionaries = requestsAdapter
            .getSwarmRequests(forAccount: accountId)
        if let conversationRequests = conversationRequestsDictionaries?.map({ dictionary in
            RequestModel(withDictionary: dictionary, accountId: accountId, type: .conversation)
        })
        .filter({ newModel in
            !self.requests.value.contains { existingModel in
                existingModel.conversationId == newModel.conversationId
            }
        }), !conversationRequests.isEmpty {
            var value = requests.value
            value.append(contentsOf: conversationRequests)
            requests.accept(value)
        }
    }

    /**
     Called when application starts and when  account changed
     */
    func loadRequests(withAccount accountId: String, accountURI _: String) {
        requests.accept([])
        var currentRequests = requests.value
        // Load conversation requests from daemon
        let conversationRequestsDictionaries = requestsAdapter
            .getSwarmRequests(forAccount: accountId)
        if let conversationRequests = conversationRequestsDictionaries?.map({ dictionary in
            RequestModel(withDictionary: dictionary, accountId: accountId, type: .conversation)
        }) {
            currentRequests.append(contentsOf: conversationRequests)
        }
        // Load trust requests from daemon
        let trustRequestsDictionaries = requestsAdapter.trustRequests(withAccountId: accountId)
        if let contactRequests = trustRequestsDictionaries?.map({ dictionary in
            RequestModel(withDictionary: dictionary, accountId: accountId, type: .contact)
        }) {
            var contactsId = [String]()
            let contactsDictionaries = requestsAdapter.contacts(withAccountId: accountId)
            if let contacts = contactsDictionaries?.map({ contactDict in
                ContactModel(withDictionary: contactDict)
            }) {
                for contact in contacts {
                    contactsId.append(contact.hash)
                }
            }
            for contactRequest in contactRequests where contactRequest.conversationId.isEmpty {
                // check if we have conversation request. If so we do not need contact request
                if !currentRequests
                    .filter({
                                $0.conversationId == contactRequest.conversationId && $0
                                    .accountId == contactRequest.accountId }).isEmpty {
                    continue
                }
                if !currentRequests
                    .filter({
                                $0.participants == contactRequest.participants && $0
                                    .accountId == accountId && $0.participants.count == 1 })
                    .isEmpty {
                    continue
                }
                /// check if contact request already accepted
                if contactsId.contains(contactRequest.participants.first?.jamiId ?? "") {
                    return
                }
                currentRequests.append(contactRequest)
            }
        }
        requests.accept(currentRequests)
    }

    // MARK: NotificationCenter action

    @objc
    private func conversationReady(_ notification: NSNotification) {
        guard let conversationId = notification
                .userInfo?[ConversationNotificationsKeys.conversationId.rawValue] as? String
        else {
            return
        }
        guard let accountId = notification
                .userInfo?[ConversationNotificationsKeys.accountId.rawValue] as? String
        else {
            return
        }
        if let index = requests.value.firstIndex(where: { request in
            request.accountId == accountId && request.conversationId == conversationId
        }) {
            var values = requests.value
            _ = values.remove(at: index)
            requests.accept(values)
        }
    }

    func getRequest(withId conversationId: String, accountId: String) -> RequestModel? {
        guard let request = requests.value
                .filter({ $0.conversationId == conversationId && $0.accountId == accountId }).first
        else {
            return nil
        }
        return request
    }

    // MARK: Private helpers

    private func getRequest(withJamiId participantId: String, accountId: String) -> RequestModel? {
        guard let request = requests.value
                .filter({
                            $0.participants.first?.jamiId == participantId && $0
                                .accountId == accountId && $0
                                .participants.count == 1 }).first
        else {
            return nil
        }
        return request
    }

    private func removeRequest(withJamiId jamiId: String, accountId: String) {
        guard let index = requests.value
                .firstIndex(where: {
                    $0.participants.first?.jamiId == jamiId && $0.accountId == accountId
                })
        else {
            return
        }
        var values = requests.value
        values.remove(at: index)
        requests.accept(values)
    }

    private func removeRequest(with conversationId: String, accountId: String) {
        guard let index = requests.value
                .firstIndex(where: {
                    $0.conversationId == conversationId && $0.accountId == accountId
                })
        else {
            return
        }
        var values = requests.value
        values.remove(at: index)
        requests.accept(values)
    }

    private func hasConversationRequestForParticipant(partisipant: ConversationParticipant?)
    -> Bool {
        let requests = self.requests.value
            .filter {
                $0.participants.first == partisipant && $0.type == .conversation && $0
                    .conversationType == .oneToOne
            }
        return !requests.isEmpty
    }

    private func hasContactRequestForParticipant(partisipant: ConversationParticipant?) -> Bool {
        let requests = self.requests.value
            .filter { $0.participants.first == partisipant && $0.type == .contact }
        return !requests.isEmpty
    }

    // MARK: Request actions

    /**
     acceptContactRequest called for contact requests.
     In case of success it will save profile for contact
     */
    func acceptContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create {} }
            let success = self.requestsAdapter.acceptTrustRequest(fromContact: jamiId,
                                                                  withAccountId: accountId)
            if success {
                if let request = self.requests.value
                    .filter({ $0.participants.first?.jamiId == jamiId && $0.accountId == accountId
                    }).first {
                    /// save profile
                    let photo = (request.avatar != nil) ? request.avatar!.base64EncodedString() : ""
                    let participantURI = JamiURI(schema: .ring, infoHash: jamiId)
                    _ = self.createProfile(
                        with: participantURI.uriString!,
                        alias: request.name,
                        photo: photo,
                        accountId: request.accountId
                    )
                    self.removeRequest(withJamiId: jamiId, accountId: accountId)
                    if request.conversationId.isEmpty {
                        /// emit event so message could be generated for db
                        var event = ServiceEvent(withEventType: .contactAdded)
                        event.addEventInput(.accountId, value: accountId)
                        event.addEventInput(.uri, value: jamiId)
                        self.responseStream.onNext(event)
                    }
                }
                observable.on(.completed)
            } else {
                observable.on(.error(RequestServiceError.acceptTrustRequestFailed))
            }

            return Disposables.create {}
        }
    }

    func requestAccepted(conversationId: String, withAccount accountId: String) {
        var event = ServiceEvent(withEventType: .requestAccepted)
        event.addEventInput(.accountId, value: accountId)
        event.addEventInput(.conversationId, value: conversationId)
        responseStream.onNext(event)
    }

    func acceptConverversationRequest(conversationId: String,
                                      withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create {} }
            let request = self.getRequest(withId: conversationId, accountId: accountId)
            if let request = request,
               request.conversationType == .oneToOne ||
                request.conversationType == .nonSwarm,
               let jamiId = request.participants.first?.jamiId {
                /// save profile
                let photo = (request.avatar != nil) ? request.avatar!.base64EncodedString() : ""
                let participantURI = JamiURI(schema: .ring, infoHash: jamiId)
                _ = self.createProfile(
                    with: participantURI.uriString!,
                    alias: request.name,
                    photo: photo,
                    accountId: request.accountId
                )
            }
            self.requestsAdapter.acceptConversationRequest(
                accountId,
                conversationId: conversationId
            )
            self.removeRequest(with: conversationId, accountId: accountId)
            self.requestAccepted(conversationId: conversationId, withAccount: accountId)
            observable.on(.completed)
            return Disposables.create {}
        }
    }

    /**
     discardContactRequest called for contact requests or for one-to-one conversation  requests when a peer is not added to contacts yet
     */
    func discardContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create {} }
            let success = self.requestsAdapter.discardTrustRequest(fromContact: jamiId,
                                                                   withAccountId: accountId)
            if success {
                self.removeRequest(withJamiId: jamiId, accountId: accountId)
                if let request = self.requests.value
                    .filter({ $0.participants.first?.jamiId == jamiId && $0.accountId == accountId
                    }).first, request.conversationId.isEmpty {
                    /// emit event so message could be generated for db
                    var event = ServiceEvent(withEventType: .contactRequestDiscarded)
                    event.addEventInput(.accountId, value: accountId)
                    event.addEventInput(.uri, value: jamiId)
                    self.responseStream.onNext(event)
                }
                observable.on(.completed)
            } else {
                observable.on(.error(RequestServiceError.diacardTrusRequestFailed))
            }
            return Disposables.create {}
        }
    }

    func discardConverversationRequest(conversationId: String,
                                       withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create {} }
            self.requestsAdapter.declineConversationRequest(
                accountId,
                conversationId: conversationId
            )
            self.removeRequest(with: conversationId, accountId: accountId)
            observable.on(.completed)
            return Disposables.create {}
        }
    }

    /**
     In case of success profile for contact will be saved
     */
    func sendContactRequest(
        to jamiId: String,
        withAccountId accountId: String,
        avatar: String? = nil,
        alias: String
    ) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else { return Disposables.create {} }
            do {
                var payload: Data?
                if let accountProfile = self.dbManager.accountProfile(for: accountId) {
                    var cardChanged = accountProfile.alias != nil || accountProfile.photo != nil
                    if cardChanged {
                        payload = try VCardUtils.dataWithImageAndUUID(from: accountProfile)
                    }
                }
                self.requestsAdapter.sendTrustRequest(
                    toContact: jamiId,
                    payload: payload,
                    withAccountId: accountId
                )
                let participantURI = JamiURI(schema: .ring, infoHash: jamiId)
                let photo = avatar ?? ""
                _ = self.createProfile(
                    with: participantURI.uriString!,
                    alias: alias,
                    photo: photo,
                    accountId: accountId
                )
                completable(.completed)
            } catch {
                completable(.error(ContactServiceError.vCardSerializationFailed))
            }
            return Disposables.create {}
        }
    }

    // MARK: database actions

    private func createProfile(
        with contactUri: String,
        alias: String,
        photo: String,
        accountId: String
    ) -> Profile? {
        do {
            return try dbManager.getProfile(
                for: contactUri,
                createIfNotExists: true,
                accountId: accountId,
                alias: alias,
                photo: photo
            )
        } catch {
            return nil
        }
    }

    private func getProfile(with contactUri: String, accountId: String) -> Profile? {
        do {
            return try dbManager.getProfile(
                for: contactUri,
                createIfNotExists: false,
                accountId: accountId
            )
        } catch {
            return nil
        }
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        if let index = requests.value.firstIndex(where: { request in
            request.conversationId == conversationId && request.accountId == accountId
        }) {
            var values = requests.value
            values.remove(at: index)
            requests.accept(values)
        }
    }
}

extension RequestsService: RequestsAdapterDelegate {
    /**
     incomingTrustRequestReceived signal emmited for a newly received contact request
     */
    func incomingTrustRequestReceived(
        from jamiId: String,
        to accountId: String,
        conversationId: String,
        withPayload payload: Data,
        receivedDate: Date
    ) {
        /// do not add request if it already accepted
        var contactsId = [String]()
        let contactsDictionaries = requestsAdapter.contacts(withAccountId: accountId)
        if let contacts = contactsDictionaries?.map({ contactDict in
            ContactModel(withDictionary: contactDict)
        }) {
            for contact in contacts {
                contactsId.append(contact.hash)
            }
        }
        let request = RequestModel(
            with: jamiId,
            accountId: accountId,
            withPayload: payload,
            receivedDate: receivedDate,
            type: .contact,
            conversationId: conversationId
        )
        /// check if contact request already accepted
        if contactsId.contains(request.participants.first?.jamiId ?? "") {
            return
        }
        /// add a request if it not added yet.
        if conversationId.isEmpty {
            if getRequest(withJamiId: jamiId, accountId: accountId) != nil { return }
        } else if getRequest(withId: conversationId, accountId: accountId) != nil { return }
        var values = requests.value
        values.append(request)
        requests.accept(values)
        if conversationId.isEmpty {
            // emit event so message could be generated for db
            var event = ServiceEvent(withEventType: .contactRequestReceived)
            event.addEventInput(.accountId, value: accountId)
            event.addEventInput(.uri, value: jamiId)
            event.addEventInput(.date, value: receivedDate)
            responseStream.onNext(event)
        }
    }

    func conversationRequestReceived(
        conversationId: String,
        accountId: String,
        metadata: [String: String]
    ) {
        /// add a conversation request. If a contact request exists for same conversation remove it.
        let conversationRequest = RequestModel(
            withDictionary: metadata,
            accountId: accountId,
            type: .conversation,
            conversationId: conversationId
        )
        if let request = getRequest(withId: conversationId, accountId: accountId) {
            request.updatefrom(dictionary: metadata)
            request.type = .conversation
            return
        }
        var values = requests.value
        values.append(conversationRequest)
        requests.accept(values)
    }
}
