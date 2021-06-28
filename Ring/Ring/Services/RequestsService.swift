//
//  RequestsService.swift
//  Ring
//
//  Created by kateryna on 2021-07-07.
//  Copyright © 2021 Savoir-faire Linux. All rights reserved.
//

import Contacts
import SwiftyBeaver
import RxSwift
import RxRelay

class RequestsService {
    private let requestsAdapter: RequestsAdapter
    private let log = SwiftyBeaver.self
    private let disposeBag = DisposeBag()
    private let dbManager: DBManager

    let requests = BehaviorRelay(value: [RequestModel]())

    init(withRequestsAdapter requestsAdapter: RequestsAdapter, dbManager: DBManager) {
        self.requestsAdapter = requestsAdapter
        self.dbManager = dbManager
        RequestsAdapter.delegate = self
    }

    private func contactRequest(withRingId ringId: String) -> RequestModel? {
        guard let contactRequest = self.requests.value.filter({ $0.participants.first?.uri == ringId && $0.type == .contact }).first else {
            return nil
        }
        return contactRequest
    }

    private func conversationRequest(withId conversationId: String) -> RequestModel? {
        guard let conversationRequest = self.requests.value.filter({ $0.conversationId == conversationId && $0.type == .conversation }).first else {
            return nil
        }
        return conversationRequest
    }

    private func contactRequest(withParticipant partisipant: ConversationParticipant?) -> RequestModel? {
        guard let contactRequest = self.requests.value.filter({ $0.participants.first == partisipant && $0.type == .contact }).first else {
            return nil
        }
        return contactRequest
    }

    private func removeContactRequest(withJamiId jamiId: String, accountId: String) {
        guard let index = self.requests.value.firstIndex(where: { $0.participants.first?.uri == jamiId && $0.type == .contact && $0.accountId == accountId }) else {
            return
        }
        var values = self.requests.value
        values.remove(at: index)
        self.requests.accept(values)
    }

    private func removeConversationRequest(withId conversationId: String, accountId: String) {
        guard let index = self.requests.value.firstIndex(where: { $0.conversationId == conversationId && $0.type == .conversation && $0.accountId == accountId }) else {
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

    func loadRequests(withAccount accountId: String) {
        self.requests.accept([])
        var currentRequests = self.requests.value
        // Load conversation requests from daemon
        let conversationRequestsDictionaries = self.requestsAdapter.getSwarmRequests(forAccount: accountId)
        if let conversationRequests = conversationRequestsDictionaries?.map({ dictionary in
            return RequestModel(withDictionary: dictionary, accountId: accountId, type: .contact)
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
                if !currentRequests.filter({ $0.participants.first == contactRequest.participants.first && $0.type == .conversation && $0.conversationType == .oneToOne }).isEmpty {
                    continue
                }
                currentRequests.append(contactRequest)
            }
        }
        self.requests.accept(currentRequests)
    }

    func acceptContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self, let request = self.contactRequest(withRingId: jamiId) else { return Disposables.create { } }
            let success = self.requestsAdapter.acceptTrustRequest(fromContact: jamiId,
                                                                  withAccountId: accountId)
            if success {
                self.removeContactRequest(withJamiId: jamiId, accountId: accountId)
                let stringImage = request.avatar.base64EncodedString()
                let name = request.name
                let uri = JamiURI(schema: URIType.ring, infoHach: jamiId)
                let uriString = uri.uriString ?? jamiId
                _ = self.dbManager
                    .createOrUpdateRingProfile(profileUri: uriString,
                                               alias: name,
                                               image: stringImage,
                                               accountId: accountId)
                var data = [String: Any]()
                data[ProfileNotificationsKeys.ringID.rawValue] = jamiId
                data[ProfileNotificationsKeys.accountId.rawValue] = accountId
                NotificationCenter.default.post(name: NSNotification.Name(ProfileNotifications.contactAdded.rawValue), object: nil, userInfo: data)
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
            self.removeConversationRequest(withId: conversationId, accountId: accountId)
            observable.on(.completed)
            return Disposables.create { }
        }
    }

    func discardContactRequest(jamiId: String, withAccount accountId: String) -> Observable<Void> {
        return Observable.create { [weak self] observable in
            guard let self = self else { return Disposables.create { } }
            let success = self.requestsAdapter.discardTrustRequest(fromContact: jamiId,
                                                                   withAccountId: accountId)
            if success {
                self.removeContactRequest(withJamiId: jamiId, accountId: accountId)
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
            self.removeConversationRequest(withId: conversationId, accountId: accountId)
            observable.on(.completed)
            return Disposables.create { }
        }
    }
}

extension RequestsService: RequestsAdapterDelegate {
    func incomingTrustRequestReceived(from senderAccount: String, to accountId: String, withPayload payload: Data, receivedDate: Date) {
        // check if contact request already added
        if self.contactRequest(withRingId: senderAccount) != nil { return }
        // check if conversation request is added for peer
        if self.hasConversationRequestForParticipant(partisipant: ConversationParticipant(uri: senderAccount)) { return }
        // add contact request
        let request = RequestModel(with: senderAccount, accountId: accountId, withPayload: payload, receivedDate: receivedDate, type: .contact)
        var values = self.requests.value
        values.append(request)
        self.requests.accept(values)
    }

    func conversationRequestReceived(conversationId: String, accountId: String, metadata: [String: String]) {
        // check if conversation request already added
        if self.conversationRequest(withId: conversationId) != nil { return }
        let conversationRequest = RequestModel(withDictionary: metadata, accountId: accountId, type: .conversation, conversationId: conversationId)
        var values = self.requests.value
        if conversationRequest.participants.count == 1 {
            // remove contact request for peer if exists
            if let index = values.firstIndex(where: { request in
                request.participants.first == conversationRequest.participants.first && request.type == .contact
            }) {
                values.remove(at: index)
            }
        }
        self.log.debug("received conversation request for conversation: \(conversationId)")
        values.append(conversationRequest)
        self.requests.accept(values)
    }
}
