/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
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

import Foundation
import RxSwift
import RxCocoa
import SwiftyBeaver
import os

// swiftlint:disable type_body_length
class ConversationsManager {

    let log = SwiftyBeaver.self

    private let conversationService: ConversationsService
    private let contactsService: ContactsService
    private let accountsService: AccountsService
    private let nameService: NameService
    private let dataTransferService: DataTransferService
    private let callService: CallsService
    private let locationSharingService: LocationSharingService
    private let callsProvider: CallsProviderDelegate
    private let requestService: RequestsService

    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"
    private var maxSizeForAutoaccept: Int {
        return UserDefaults.standard.integer(forKey: acceptTransferLimitKey) * 1024 * 1024
    }
    private let appState = BehaviorRelay<ServiceEventType>(value: .appEnterForeground)

    // swiftlint:disable cyclomatic_complexity
    init(with conversationService: ConversationsService,
         accountsService: AccountsService,
         nameService: NameService,
         dataTransferService: DataTransferService,
         callService: CallsService,
         locationSharingService: LocationSharingService,
         contactsService: ContactsService,
         callsProvider: CallsProviderDelegate,
         requestsService: RequestsService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.callService = callService
        self.locationSharingService = locationSharingService
        self.contactsService = contactsService
        self.callsProvider = callsProvider
        self.requestService = requestsService

        ConversationsAdapter.messagesDelegate = self
        self.subscribeFileTransferEvents()
        self.subscribeCallsEvents()
        self.subscribeContactsEvents()
        // TODO: fix location sharing with a new API
        if false {
            self.subscribeLocationSharingEvent()
        }
        self.subscribeCallsProviderEvents()
        self.controlAccountsState()
    }

    /// when application is not active, accounts also should be not active. Except when when handling incoming call.
    private func controlAccountsState() {
        /// subscribe to app state changes
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        /// calls events
        let callProviderEvents = callsProvider.sharedResponseStream
            .filter({ (event) in
                return event.eventType == .callProviderCancelCall ||
                    event.eventType == .callProviderPreviewPendingCall
            })
            .map { event in
                event.eventType
            }
        let callEndedEvents = self.callService.sharedResponseStream
            .filter({ (event) in
                return  event.eventType == .callEnded
            })
            .map { event in
                event.eventType
            }
        Observable.of(callProviderEvents.asObservable(),
                      callEndedEvents.asObservable(),
                      appState
                        .asObservable())
            .merge()
            .subscribe { [weak self] eventType in
                guard let self = self else { return }
                switch eventType {
                case .appEnterBackground:
                    if !self.callsProvider.hasPendingTransactions() {
                        self.accountsService.setAccountsActive(active: false)
                    }
                case .appEnterForeground:
                    self.accountsService.setAccountsActive(active: true)
                    // reload requests, since they may be handeled by notification extension
                    // and Jami may not have up to date requests when entering foreground
                    if let currentAccount = self.accountsService.currentAccount {
                        self.requestService.updateConversationsRequests(withAccount: currentAccount.id)
                    }
                case .callProviderPreviewPendingCall:
                    self.accountsService.setAccountsActive(active: true)
                case .callEnded, .callProviderCancelCall:
                    DispatchQueue.main.async {
                        let state = UIApplication.shared.applicationState
                        if state == .background {
                            self.accountsService.setAccountsActive(active: false)
                        }
                    }
                default:
                    break
                }
            } onError: { _ in
            }
            .disposed(by: self.disposeBag)
    }

    @objc
    func appMovedToBackground() {
        appState.accept(.appEnterBackground)
    }

    @objc
    func appMovedForeground() {
        appState.accept(.appEnterForeground)
    }

    private func subscribeContactsEvents() {
        self.contactsService.sharedResponseStream
            .filter({ $0.eventType == ServiceEventType.contactAdded })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let jamiId: String = event.getEventInput(.peerUri),
                      let account = self.accountsService.getAccount(fromAccountId: accountId),
                      account.isJams
                else { return }
                self.conversationService.saveJamsConversation(for: jamiId, accountId: accountId)
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeCallsProviderEvents() {
        callsProvider.sharedResponseStream
            .filter({serviceEvent in
                guard serviceEvent.eventType == .callProviderAnswerCall ||
                        serviceEvent.eventType == .callProviderCancelCall else {
                    return false
                }
                return true
            })
            .subscribe(onNext: { [weak self] serviceEvent in
                os_log("event from call provider")
                guard let self = self,
                      let callUUID: String = serviceEvent
                        .getEventInput(ServiceEventInput.callUUID),
                      let call = self.callService.callByUUID(UUID: callUUID) else {
                    return
                }
                if serviceEvent.eventType == ServiceEventType.callProviderAnswerCall {
                    os_log("call provider answer call %@", call.callId)
                    if !self.callService.answerCall(call: call) {
                        self.callsProvider.stopCall(callUUID: call.callUUID, participant: call.paricipantHash())
                    }
                } else {
                    os_log("call provider cancel call")
                    self.callService.stopCall(call: call)
                }
            })
            .disposed(by: self.disposeBag)
        callsProvider.sharedResponseStream
            .filter({serviceEvent in
                guard serviceEvent.eventType == .callProviderUpdatedUUID else {
                    return false
                }
                return true
            })
            .subscribe(onNext: { [weak self] serviceEvent in
                guard let self = self,
                      let callUUID: String = serviceEvent.getEventInput(ServiceEventInput.callUUID),
                      let callId: String = serviceEvent.getEventInput(ServiceEventInput.callId) else {
                    return
                }
                self.callService.updateCallUUID(callId: callId, callUUID: callUUID)
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeLocationSharingEvent() {
        self.locationSharingService
            .locationServiceEventShared
            .filter({ $0.eventType == ServiceEventType.sendLocation })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let currentAccount = self.accountsService.currentAccount,
                      let (content, shouldTryToSave): (String, Bool) = event.getEventInput(ServiceEventInput.content),
                      let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let account = self.accountsService.getAccount(fromAccountId: accountId),
                      let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                else { return }

                let shouldRefresh = currentAccount.id == accountId

                self.conversationService
                    .sendLocation(withContent: content,
                                  from: account,
                                  recipientUri: peerUri,
                                  shouldRefreshConversations: shouldRefresh,
                                  shouldTryToSave: shouldTryToSave)
                    .subscribe(onCompleted: { [weak self] in
                        self?.log.debug("[LocationSharingService] Location sent")
                    })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: self.disposeBag)

        self.locationSharingService
            .locationServiceEventShared
            .filter({ $0.eventType == ServiceEventType.deleteLocation })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let currentAccount = self.accountsService.currentAccount,
                      let (incoming, shouldRefreshConversations): (Bool, Bool) = event.getEventInput(ServiceEventInput.content),
                      let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                else { return }

                let shouldRefresh = currentAccount.id == accountId && shouldRefreshConversations

                self.conversationService.deleteLocationUpdate(incoming: incoming,
                                                              peerUri: peerUri,
                                                              accountId: accountId,
                                                              shouldRefreshConversations: shouldRefresh)
                    .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .subscribe()
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeCallsEvents() {
        self.callService.sharedResponseStream
            .filter({ (event) in
                return  event.eventType == .callEnded
            })
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                guard let peerId: String = event.getEventInput(ServiceEventInput.peerUri),
                      let uuidString: String = event.getEventInput(ServiceEventInput.callUUID) else { return }
                self.callsProvider.stopCall(callUUID: UUID(uuidString: uuidString)!, participant: peerId.filterOutHost())
            })
            .disposed(by: disposeBag)
        self.callService.newMessage
            .filter({ (event) in
                return  event.eventType == ServiceEventType.newIncomingMessage
            })
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                if self.accountsService.boothMode() {
                    return
                }
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                else { return }
                guard let messageContent: String = event.getEventInput(ServiceEventInput.content) else { return }
                self.handleNewMessage(from: peerUri,
                                      to: accountId,
                                      messageId: "",
                                      message: messageContent,
                                      peerName: event.getEventInput(ServiceEventInput.name))
            })
            .disposed(by: disposeBag)

        self.callService.newMessage
            .filter({ (event) in
                return  event.eventType == ServiceEventType.newOutgoingMessage
            })
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                if self.accountsService.boothMode() {
                    return
                }
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let messageContent: String = event.getEventInput(ServiceEventInput.content),
                      let peerUri: String = event.getEventInput(ServiceEventInput.peerUri),
                      let accountURi: String = event.getEventInput(ServiceEventInput.accountUri)
                else { return }
                let message = self.conversationService.createMessage(withId: "",
                                                                     withContent: messageContent,
                                                                     byAuthor: accountURi,
                                                                     type: .text,
                                                                     incoming: false)
                self.conversationService.saveMessage(message: message,
                                                     toConversationWith: peerUri,
                                                     toAccountId: accountId,
                                                     shouldRefreshConversations: true)
                    .subscribe()
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }
    private func subscribeFileTransferEvents() {
        self.dataTransferService
            .sharedResponseStream
            .filter({ (event) in
                return  event.eventType == ServiceEventType.dataTransferCreated ||
                    event.eventType == ServiceEventType.dataTransferChanged
            })
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                if self.accountsService.boothMode() {
                    return
                }
                guard let transferId: String = event.getEventInput(ServiceEventInput.transferId),
                      let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let conversationId: String = event.getEventInput(ServiceEventInput.conversationId),
                      let messageId: String = event.getEventInput(ServiceEventInput.messageId),
                      let transferInfo = self.dataTransferService.dataTransferInfo(withId: transferId, accountId: accountId, conversationId: conversationId, isSwarm: !conversationId.isEmpty),
                      let currentAccount = self.accountsService.currentAccount else {
                    self.log.error("ConversationsManager: can't find transferInfo")
                    return
                }
                switch event.eventType {
                case .dataTransferCreated:
                    let photoIdentifier: String? = event.getEventInput(.localPhotolID)
                    self.conversationService
                        .generateDataTransferMessage(transferId: transferId,
                                                     transferInfo: transferInfo,
                                                     accountId: transferInfo.accountId,
                                                     photoIdentifier: photoIdentifier,
                                                     updateConversation: currentAccount.id == transferInfo.accountId,
                                                     conversationId: conversationId, messageId: messageId)
                        .subscribe()
                        .disposed(by: self.disposeBag)
                case .dataTransferChanged:
                    guard let eventCode: Int = event.getEventInput(ServiceEventInput.state),
                          var dtEvent = NSDataTransferEventCode(rawValue: UInt32(eventCode)) else { return }
                    if conversationId.isEmpty {
                        dtEvent = transferInfo.lastEvent
                    }
                    self.log.debug("ConversationsManager: dataTransferChanged - id:\(transferId) status:\(stringFromEventCode(with: dtEvent))")
                    var status: DataTransferStatus = .unknown
                    switch dtEvent {
                    case .closed_by_host, .closed_by_peer:
                        status = DataTransferStatus.canceled
                    case .invalid, .unsupported, .invalid_pathname, .unjoinable_peer:
                        status = DataTransferStatus.error
                    case .wait_peer_acceptance, .wait_host_acceptance:
                        status = DataTransferStatus.awaiting
                    case .ongoing:
                        status = DataTransferStatus.ongoing
                    case .finished:
                        status = DataTransferStatus.success
                    case .created:
                        break
                    @unknown default:
                        break
                    }
                    let peer = !conversationId.isEmpty ? "" : transferInfo.peer
                    self.conversationService.transferStatusChanged(status, for: transferId, conversationId: conversationId, interactionId: messageId, accountId: accountId, to: peer ?? "")
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    func prepareConversationsForAccount(accountId: String, accountURI: String) {
        self.conversationService
            .getConversationsForAccount(accountId: accountId, accountURI: accountURI)
    }

    // MARK: Message Adapter delegate
    private func handleReceivedLocationUpdate(from peerId: String, to accountId: String, messageId: String, locationJSON content: String) {
        guard let currentAccount = self.accountsService.currentAccount,
              let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }

        let type = AccountModelHelper.init(withAccount: accountForMessage).isAccountSip() ? URIType.sip : URIType.ring
        guard let peerUri = JamiURI.init(schema: type, infoHach: peerId, account: accountForMessage).uriString else { return }

        if self.conversationService.isBeginningOfLocationSharing(incoming: true, contactUri: peerUri, accountId: accountId) {
            let shouldRefresh = currentAccount.id == accountId

            // Save (if first)
            guard let uriString = JamiURI.init(schema: type,
                                               infoHach: peerUri,
                                               account: accountForMessage).uriString else { return }
            let message = self.conversationService.createLocation(withId: messageId,
                                                                  byAuthor: uriString,
                                                                  incoming: true)
            self.conversationService.saveLocation(message: message,
                                                  toConversationWith: uriString,
                                                  toAccountId: accountId,
                                                  shouldRefreshConversations: shouldRefresh,
                                                  contactUri: peerUri)
                .subscribe()
                .disposed(by: self.disposeBag)
        }

        // Tell the location sharing service
        self.locationSharingService.handleReceivedLocationUpdate(from: peerUri, to: accountId, messageId: messageId, locationJSON: content)
    }

    func handleNewMessage(from peerUri: String, to accountId: String, messageId: String, message content: String, peerName: String?) {
        guard let currentAccount = self.accountsService.currentAccount,
              let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        let shouldUpdateConversationsList = currentAccount.id == accountForMessage.id

        let type = AccountModelHelper.init(withAccount: accountForMessage)
            .isAccountSip() ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHach: peerUri,
                                           account: accountForMessage).uriString else { return }
        let message = self.conversationService.createMessage(withId: messageId,
                                                             withContent: content,
                                                             byAuthor: uriString,
                                                             type: .text,
                                                             incoming: true)
        self.conversationService.saveMessage(message: message,
                                             toConversationWith: uriString,
                                             toAccountId: accountId,
                                             shouldRefreshConversations: shouldUpdateConversationsList)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      from: accountId,
                                                      to: jamiId,
                                                      in: conversationId)
    }

    func detectingMessageTyping(_ from: String, for accountId: String, status: Int) {
        conversationService.detectingMessageTyping(from, for: accountId, status: status)
    }

    func conversationProfileUpdated(conversationId: String, accountId: String, profile: [String: String]) {
        conversationService.conversationProfileUpdated(conversationId: conversationId, accountId: accountId, profile: profile)
    }

    func conversationPreferencesUpdated(conversationId: String, accountId: String, preferences: [String: String]) {
        conversationService.conversationPreferencesUpdated(conversationId: conversationId, accountId: accountId, preferences: preferences)
    }
}

extension  ConversationsManager: MessagesAdapterDelegate {
    func conversationMemberEvent(conversationId: String, accountId: String, memberUri: String, event: Int) {
        guard let conversationEvent = ConversationMemberEvent(rawValue: event) else { return }
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        /// check if we leave conversation on another device. In this case remove conversation
        if conversationEvent == .leave,
           account.jamiId == memberUri {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        } else {
            self.conversationService.conversationMemberEvent(conversationId: conversationId, accountId: accountId, memberUri: memberUri, event: conversationEvent, accountURI: account.jamiId)
        }
    }

    func didReceiveMessage(_ message: [String: String], from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        if self.accountsService.boothMode() {
            return
        }
        if let content = message[textPlainMIMEType] {
            self.handleNewMessage(from: senderAccount,
                                  to: receiverAccountId,
                                  messageId: messageId,
                                  message: content,
                                  peerName: nil)
        } else if let content = message[geoLocationMIMEType] {
            self.handleReceivedLocationUpdate(from: senderAccount,
                                              to: receiverAccountId,
                                              messageId: messageId,
                                              locationJSON: content)
        }
    }

    func conversationReady(conversationId: String, accountId: String) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        self.conversationService.conversationReady(conversationId: conversationId, accountId: accountId, accountURI: account.jamiId)
    }
    func conversationLoaded(conversationId: String, accountId: String, messages: [[String: String]]) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        /// convert array of dictionaries to messages
        let messagesModels = messages.map { dictionary -> MessageModel in
            let newMessage = MessageModel(withInfo: dictionary, accountJamiId: account.jamiId)
            if newMessage.type == .fileTransfer {
                let progress = self.dataTransferService.getTransferProgress(withId: newMessage.daemonId, accountId: accountId, conversationId: conversationId, isSwarm: true)
                newMessage.transferStatus = progress == 0 ? .awaiting : progress == newMessage.totalSize ? .success : .ongoing
                if newMessage.transferStatus == .awaiting, newMessage.totalSize <= maxSizeForAutoaccept {
                    var filename = ""
                    self.dataTransferService.downloadFile(withId: newMessage.daemonId,
                                                          interactionID: newMessage.id,
                                                          fileName: &filename, accountID: accountId,
                                                          conversationID: conversationId)
                }
            }
            return newMessage
        }
        _ = self.conversationService.insertMessages(messages: messagesModels, accountId: accountId, conversationId: conversationId, fromLoaded: true)
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String]) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        let newMessage = MessageModel(withInfo: message, accountJamiId: account.jamiId)
        if newMessage.type == .fileTransfer {
            newMessage.transferStatus = newMessage.incoming ? .awaiting : .success
        }
        /// if new message was inserted check if we need to present notification
        if self.conversationService.insertMessages(messages: [newMessage], accountId: accountId, conversationId: conversationId, fromLoaded: false) {
            /// download if file not saved yet
            if let size = message["totalSize"],
               (newMessage.transferStatus == .awaiting || newMessage.transferStatus == .success) {

                let isReceiving = message[MessageAttributes.author.rawValue] != account.jamiId

                let isAutomaticDownloadEnabled = UserDefaults.standard.bool(forKey: automaticDownloadFilesKey)
                var isFileSizeDownloadable = false
                if maxSizeForAutoaccept == 0 {
                    isFileSizeDownloadable = true
                } else {
                    isFileSizeDownloadable = Int(size) ?? 30 * 1024 * 1024 <= maxSizeForAutoaccept
                }

                if isReceiving && isFileSizeDownloadable && isAutomaticDownloadEnabled {
                    var filename = ""
                    self.dataTransferService.downloadFile(withId: newMessage.daemonId, interactionID: newMessage.id, fileName: &filename, accountID: accountId, conversationID: conversationId)
                } else if !isReceiving {
                    var filename = ""
                    self.dataTransferService.downloadFile(withId: newMessage.daemonId, interactionID: newMessage.id, fileName: &filename, accountID: accountId, conversationID: conversationId)
                }
            }
        }
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        self.requestService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
    }

    func conversationDeclined(conversationId: String, accountId: String) {
        self.requestService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
    }
}
// swiftlint:enable type_body_length
