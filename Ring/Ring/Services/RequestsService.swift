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

import SwiftyBeaver
import RxSwift
import RxRelay

/*
 This class manages both: conversation and contact request
 Depending on conversation type and swarm support on another side we could have next scenarios:
 - receive only a contact request. When the other side does not support swarm.
 - receive only a conversation request. When the other side does support swarm and we already added contact for the peer.
 - receive both: a conversation request and a contact request. When the other side does support swarm and we do not have contact for the peer. In this case, we will keep only a conversation request.
 */
class RequestsService {

    // MARK: private members
    private let requestsAdapter: RequestsAdapter
    private let log = SwiftyBeaver.self
    private let disposeBag = DisposeBag()

    // MARK: observable requests
    let requests = BehaviorRelay(value: [RequestModel]())
    let dbManager: DBManager

    // MARK: initial loading

    init(withRequestsAdapter requestsAdapter: RequestsAdapter, dbManager: DBManager) {
        self.dbManager = dbManager
        self.requestsAdapter = requestsAdapter
        RequestsAdapter.delegate = self
        /**
         after accepting the request stays in synchronization until other contact became online and conversation synchronized.
         When it happens conversationReady signal is emitted. And we could remove the request.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(self.conversationReady(_:)),
                                               name: NSNotification.Name(rawValue: ConversationNotifications.conversationReady.rawValue),
                                               object: nil)
    }

    /**
     Called when application starts and when  account changed
     */
    func loadRequests(withAccount accountId: String) {
        self.requests.accept([])
        var currentRequests = self.requests.value
        // Load conversation requests from daemon
        let conversationRequestsDictionaries = self.requestsAdapter.getSwarmRequests(forAccount: accountId)
        if let conversationRequests = conversationRequestsDictionaries?.map({ dictionary in
            return RequestModel(withDictionary: dictionary, accountId: accountId, type: .conversation)
        }) {
            currentRequests.append(contentsOf: conversationRequests)
        }
        // Load trust requests from daemon
        let trustRequestsDictionaries = self.requestsAdapter.trustRequests(withAccountId: accountId)
        if let contactRequests = trustRequestsDictionaries?.map({ dictionary in
            return RequestModel(withDictionary: dictionary, accountId: accountId, type: .contact)
        }) {
            for contactRequest in contactRequests {
                // check if we have conversation request for peer. If so we do not need contact request
                if !currentRequests.filter({ $0.conversationId == contactRequest.conversationId }).isEmpty {
                    continue
                }
                currentRequests.append(contactRequest)
            }
        }
        self.requests.accept(currentRequests)
    }

    // MARK: NotificationCenter action
    @objc
    private func conversationReady(_ notification: NSNotification) {
        guard let conversationId = notification.userInfo?[ConversationNotificationsKeys.conversationId.rawValue] as? String else {
            return
        }
        guard let accountId = notification.userInfo?[ConversationNotificationsKeys.accountId.rawValue] as? String else {
            return
        }
        if let index = self.requests.value.firstIndex(where: { request in
            request.accountId == accountId && request.conversationId == conversationId
        }) {
            var values = requests.value
            let request = values.remove(at: index)
            self.requests.accept(values)
            if request.participants.count == 1, let participant = request.participants.first?.jamiId {
            self.createProfile(with: "ring:" + participant, alias: request.name, photo: request.avatar.base64EncodedString(), accountId: request.accountId)
            }
        }
       // createProfile(with contactUri: String, alias: String, photo: String, accountId: String)
      //  self.createProfile(with contactUri: String, alias: String, photo: String, accountId: String)
    }

    // MARK: Private helpers

    private func getRequest(withId conversationId: String, accountId: String) -> RequestModel? {
        guard let request = self.requests.value.filter({ $0.conversationId == conversationId && $0.accountId == accountId }).first else {
            return nil
        }
        return request
    }

    private func removeRequest(withJamiId jamiId: String, accountId: String) {
        guard let index = self.requests.value.firstIndex(where: { $0.participants.first?.jamiId == jamiId && $0.accountId == accountId }) else {
            return
        }
        var values = self.requests.value
        values.remove(at: index)
        self.requests.accept(values)
    }

    private func removeRequest(with conversationId: String, accountId: String) {
        guard let index = self.requests.value.firstIndex(where: { $0.conversationId == conversationId && $0.accountId == accountId }) else {
            return
        }
        var values = self.requests.value
        values.remove(at: index)
        self.requests.accept(values)
    }

    private func hasConversationRequestForParticipant(partisipant: ConversationParticipant?) -> Bool {
        let requests = self.requests.value.filter({ $0.participants.first == partisipant && $0.type == .conversation && $0.conversationType == .oneToOne })
        return !requests.isEmpty
    }

    private func hasContactRequestForParticipant(partisipant: ConversationParticipant?) -> Bool {
        let requests = self.requests.value.filter({ $0.participants.first == partisipant && $0.type == .contact })
        return !requests.isEmpty
    }

    // MARK: Request actions
    /**
     acceptContactRequest called for contact requests or for one-to-one conversation  requests when a peer is not added to contacts yet
     */
    func acceptContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            let success = self.requestsAdapter.acceptTrustRequest(fromContact: jamiId,
                                                                  withAccountId: accountId)
            if success {
                if let request = self.requests.value.filter({ $0.participants.first?.jamiId == jamiId && $0.accountId == accountId
                }).first {
                    request.synchronizing.accept(true)
                }
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.acceptTrustRequestFailed))
            }

            return Disposables.create { }
        }
    }

    func acceptConverversationRequest(conversationId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            self.requestsAdapter.acceptConversationRequest(accountId, conversationId: conversationId)
            if let request = self.requests.value.filter({ $0.conversationId == conversationId && $0.accountId == accountId
            }).first {
                request.synchronizing.accept(true)
            }
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    /**
     discardContactRequest called for contact requests or for one-to-one conversation  requests when a peer is not added to contacts yet
     */
    func discardContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            let success = self.requestsAdapter.discardTrustRequest(fromContact: jamiId,
                                                                   withAccountId: accountId)
            if success {
                self.removeRequest(withJamiId: jamiId, accountId: accountId)
                observable.on(.completed)
            } else {
                observable.on(.error(ContactServiceError.diacardTrusRequestFailed))
            }
            return Disposables.create { }
        }
    }

    func discardConverversationRequest(conversationId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            self.requestsAdapter.declineConversationRequest(accountId, conversationId: conversationId)
            self.removeRequest(with: conversationId, accountId: accountId)
            observable.on(.completed)
            return Disposables.create { }
        }
    }
    func createProfile(with contactUri: String, alias: String, photo: String, accountId: String) -> Profile? {
        do {
            return try self.dbManager.getProfile(for: contactUri, createIfNotExists: true, accountId: accountId, alias: alias, photo: photo)
        } catch {
            return nil
        }
    }
}

extension RequestsService: RequestsAdapterDelegate {
    func incomingTrustRequestReceived(from jamiId: String, to accountId: String, conversationId: String, withPayload payload: Data, receivedDate: Date) {
        // check if request already added
        if self.getRequest(withId: conversationId, accountId: accountId) != nil { return }
        let request = RequestModel(with: jamiId, accountId: accountId, withPayload: payload, receivedDate: receivedDate, type: .contact, conversationId: conversationId)
        var values = self.requests.value
        values.append(request)
        self.requests.accept(values)
    }
    /**
     add conversation request. If  a contact request exists for same conversation remove it.
     */
    func conversationRequestReceived(conversationId: String, accountId: String, metadata: [String: String]) {
        let conversationRequest = RequestModel(withDictionary: metadata, accountId: accountId, type: .conversation, conversationId: conversationId)
        var values = self.requests.value
        // check if request already added
        if let request = self.getRequest(withId: conversationId, accountId: accountId) {
            if request.type == .contact {
                if let index = values.firstIndex(where: { request in
                    request.conversationId == conversationRequest.conversationId && request.type == .contact
                }) {
                    values.remove(at: index)
                }
            } else { return }
        }
        self.log.debug("received conversation request for conversation: \(conversationId)")
        values.append(conversationRequest)
        self.requests.accept(values)
    }
}
