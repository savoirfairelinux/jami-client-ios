/*
 *  Copyright (C) 2017-2021 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Raphaël Brulé <raphael.brule@savoirfairelinux.com>
 *  Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import os
import RxCocoa
import RxSwift
import SwiftyBeaver

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
    private let callsProvider: CallsProviderService
    private let requestService: RequestsService
    private let profileService: ProfilesService

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
         callsProvider: CallsProviderService,
         requestsService: RequestsService,
         profileService: ProfilesService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.callService = callService
        self.locationSharingService = locationSharingService
        self.contactsService = contactsService
        self.callsProvider = callsProvider
        requestService = requestsService
        self.profileService = profileService
        ProfilesAdapter.delegate = self

        ConversationsAdapter.messagesDelegate = self
        RequestsAdapter.delegate = self
        /*
         When the application starts, all conversations will be loaded.
         Conversation data should be cleaned to prevent reloading conversations
         that were updated from notifications
         */
        cleanConversationData()
        subscribeFileTransferEvents()
        subscribeCallsEvents()
        subscribeContactsEvents()
        subscribeLocationSharingEvent()
        subscribeCallsProviderEvents()
        subscribeRequestEvents()
        controlAccountsState()
    }

    /// when application is not active, accounts also should be not active. Except when when
    /// handling incoming call.
    private func controlAccountsState() {
        /// subscribe to app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        /// calls events
        let callProviderEvents = callsProvider.sharedResponseStream
            .filter { event in
                event.eventType == .callProviderCancelCall ||
                    event.eventType == .callProviderPreviewPendingCall
            }
            .map { event in
                event.eventType
            }
        let callEndedEvents = callService.sharedResponseStream
            .filter { event in
                event.eventType == .callEnded
            }
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
                    self.updateBackgroundState()
                case .appEnterForeground:
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        guard let self = self else { return }
                        self.updateForegroundState()
                    }
                case .callProviderPreviewPendingCall:
                    self.accountsService.setAccountsActive(active: true)
                    // Reload conversations updated in the background if needed.
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        guard let self = self,
                              let updatedConversations = self.getConversationData() else { return }
                        self.cleanConversationData()
                        self
                            .reloadConversationsAndRequests(
                                updatedConversations: updatedConversations
                            )
                    }
                case .callEnded, .callProviderCancelCall:
                    DispatchQueue.main.async {
                        let state = UIApplication.shared.applicationState
                        if state == .background {
                            self.updateBackgroundState()
                        }
                    }
                default:
                    break
                }
            } onError: { _ in
            }
            .disposed(by: disposeBag)
    }

    /*
     When the app is in the background, the account should not be active, and
     the notification extension should handle incoming notifications unless there is a pending call.
     */
    func updateBackgroundState() {
        if callsProvider.hasActiveCalls() { return }
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.updateCallScreenState(presenting: false)
        }
        accountsService.setAccountsActive(active: false)
    }

    func cleanConversationData() {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return
        }
        userDefaults.set([[String: String]](), forKey: Constants.updatedConversations)
    }

    func getConversationData() -> [[String: String]]? {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            return nil
        }
        return userDefaults.object(forKey: Constants.updatedConversations) as? [[String: String]]
    }

    func updateForegroundState() {
        guard let updatedConversations = getConversationData() else {
            accountsService.setAccountsActive(active: true)
            return
        }
        cleanConversationData()
        // ask daemon to reload conversations and request from file
        reloadConversationsAndRequests(updatedConversations: updatedConversations)
        accountsService.setAccountsActive(active: true)
        // get requests from the daemon
        updateRequests(updatedConversations: updatedConversations)
        // get interactions from the daemon
        reloadConversationMessages(updatedConversations: updatedConversations)
    }

    func reloadConversationsAndRequests(updatedConversations: [[String: String]]) {
        for conversationData in updatedConversations {
            if let accountId =
                conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue] {
                conversationService.reloadConversationsAndRequests(accountId: accountId)
            }
        }
    }

    func updateRequests(updatedConversations: [[String: String]]) {
        for conversationData in updatedConversations {
            if let accountId =
                conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue] {
                requestService.updateConversationsRequests(withAccount: accountId)
            }
        }
    }

    func reloadConversationMessages(updatedConversations: [[String: String]]) {
        for conversationData in updatedConversations {
            if let accountId =
                conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue],
               let currentAccountId = accountsService.currentAccount?.id,
               let conversationId =
                conversationData[Constants.NotificationUserInfoKeys.conversationID.rawValue],
               accountId == currentAccountId {
                conversationService.updateConversationMessages(conversationId: conversationId)
            }
        }
    }

    @objc
    func appMovedToBackground() {
        appState.accept(.appEnterBackground)
    }

    @objc
    func appMovedForeground() {
        appState.accept(.appEnterForeground)
    }

    private func subscribeRequestEvents() {
        requestService.sharedResponseStream
            .filter { $0.eventType == ServiceEventType.requestAccepted }
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let conversationId: String = event.getEventInput(.conversationId),
                      let account = self.accountsService.getAccount(fromAccountId: accountId)
                else { return }
                self.conversationService.conversationReady(
                    conversationId: conversationId,
                    accountId: accountId,
                    accountURI: account.jamiId
                )
            })
            .disposed(by: disposeBag)
    }

    private func subscribeContactsEvents() {
        contactsService.sharedResponseStream
            .filter { $0.eventType == ServiceEventType.contactAdded }
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let jamiId: String = event.getEventInput(.peerUri),
                      let account = self.accountsService.getAccount(fromAccountId: accountId),
                      account.isJams,
                      let currentAccount = self.accountsService.currentAccount
                else { return }
                self.conversationService.saveJamsConversation(
                    for: jamiId,
                    accountId: accountId,
                    refreshConversations: currentAccount.id == accountId
                )
            })
            .disposed(by: disposeBag)
    }

    private func subscribeCallsProviderEvents() {
        callsProvider.sharedResponseStream
            .filter { serviceEvent in
                guard serviceEvent.eventType == .callProviderAnswerCall ||
                        serviceEvent.eventType == .callProviderCancelCall
                else {
                    return false
                }
                return true
            }
            .subscribe(onNext: { [weak self] serviceEvent in
                os_log("event from call provider")
                guard let self = self,
                      let callUUID: String = serviceEvent
                        .getEventInput(ServiceEventInput.callUUID),
                      let call = self.callService.callByUUID(UUID: callUUID)
                else {
                    return
                }
                if serviceEvent.eventType == ServiceEventType.callProviderAnswerCall {
                    os_log("call provider answer call %@", call.callId)
                    if !self.callService.answerCall(call: call) {
                        self.callsProvider.stopCall(
                            callUUID: call.callUUID,
                            participant: call.paricipantHash()
                        )
                    }
                } else {
                    os_log("call provider cancel call")
                    self.callService
                        .refuse(callId: call.callId)
                        .subscribe()
                        .disposed(by: self.disposeBag)
                }
            })
            .disposed(by: disposeBag)
    }

    private func subscribeLocationSharingEvent() {
        locationSharingService
            .locationServiceEventShared
            .filter { $0.eventType == ServiceEventType.sendLocation }
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let currentAccount = self.accountsService.currentAccount,
                      let (content, shouldTryToSave): (String, Bool) = event
                        .getEventInput(ServiceEventInput.content),
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
            .disposed(by: disposeBag)
    }

    private func subscribeCallsEvents() {
        callService.sharedResponseStream
            .filter { event in
                event.eventType == .callEnded
            }
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                guard let peerId: String = event.getEventInput(ServiceEventInput.peerUri),
                      let uuidString: String = event.getEventInput(ServiceEventInput.callUUID)
                else { return }
                self.callsProvider.stopCall(
                    callUUID: UUID(uuidString: uuidString)!,
                    participant: peerId.filterOutHost()
                )
            })
            .disposed(by: disposeBag)
        callService.newMessage
            .filter { event in
                event.eventType == ServiceEventType.newIncomingMessage
            }
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                if self.accountsService.boothMode() {
                    return
                }
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                else { return }
                guard let messageContent: String = event.getEventInput(ServiceEventInput.content)
                else { return }
                self.handleNewMessage(from: peerUri,
                                      to: accountId,
                                      messageId: "",
                                      message: messageContent,
                                      peerName: event.getEventInput(ServiceEventInput.name))
            })
            .disposed(by: disposeBag)

        callService.newMessage
            .filter { event in
                event.eventType == ServiceEventType.newOutgoingMessage
            }
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
        dataTransferService
            .sharedResponseStream
            .filter { event in
                event.eventType == ServiceEventType.dataTransferCreated ||
                    event.eventType == ServiceEventType.dataTransferChanged
            }
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                if self.accountsService.boothMode() {
                    return
                }
                guard let transferId: String = event.getEventInput(ServiceEventInput.transferId),
                      let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let conversationId: String = event
                        .getEventInput(ServiceEventInput.conversationId),
                      let messageId: String = event.getEventInput(ServiceEventInput.messageId),
                      let transferInfo = self.dataTransferService.dataTransferInfo(
                        withId: transferId,
                        accountId: accountId,
                        conversationId: conversationId,
                        isSwarm: !conversationId.isEmpty
                      ),
                      let currentAccount = self.accountsService.currentAccount
                else {
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
                                                     updateConversation: currentAccount
                                                        .id == transferInfo.accountId,
                                                     conversationId: conversationId,
                                                     messageId: messageId)
                        .subscribe()
                        .disposed(by: self.disposeBag)
                case .dataTransferChanged:
                    guard let eventCode: Int = event.getEventInput(ServiceEventInput.state),
                          var dtEvent = NSDataTransferEventCode(rawValue: UInt32(eventCode))
                    else { return }
                    if conversationId.isEmpty {
                        dtEvent = transferInfo.lastEvent
                    }
                    self.log
                        .debug(
                            "ConversationsManager: dataTransferChanged - id:\(transferId) status:\(stringFromEventCode(with: dtEvent))"
                        )
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
                    self.conversationService.transferStatusChanged(
                        status,
                        for: transferId,
                        conversationId: conversationId,
                        interactionId: messageId,
                        accountId: accountId,
                        to: peer ?? ""
                    )
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    func prepareConversationsForAccount(accountId: String, accountURI: String) {
        conversationService
            .getConversationsForAccount(accountId: accountId, accountURI: accountURI)
    }

    // MARK: Message Adapter delegate

    private func handleReceivedLocationUpdate(
        from peerId: String,
        to accountId: String,
        messageId: String,
        locationJSON content: String
    ) {
        guard let accountForMessage = accountsService.getAccount(fromAccountId: accountId)
        else { return }

        let type = AccountModelHelper(withAccount: accountForMessage).isAccountSip() ? URIType
            .sip : URIType.ring
        guard let peerUri = JamiURI(schema: type, infoHash: peerId, account: accountForMessage)
                .uriString else { return }

        // Tell the location sharing service
        locationSharingService.handleReceivedLocationUpdate(
            from: peerUri,
            to: accountId,
            messageId: messageId,
            locationJSON: content
        )
    }

    func handleNewMessage(
        from peerUri: String,
        to accountId: String,
        messageId: String,
        message content: String,
        peerName _: String?
    ) {
        guard let currentAccount = accountsService.currentAccount,
              let accountForMessage = accountsService.getAccount(fromAccountId: accountId)
        else { return }
        let shouldUpdateConversationsList = currentAccount.id == accountForMessage.id

        let type = AccountModelHelper(withAccount: accountForMessage)
            .isAccountSip() ? URIType.sip : URIType.ring
        guard let uriString = JamiURI(schema: type,
                                      infoHash: peerUri,
                                      account: accountForMessage).uriString else { return }
        let message = conversationService.createMessage(withId: messageId,
                                                        withContent: content,
                                                        byAuthor: uriString,
                                                        type: .text,
                                                        incoming: true)
        conversationService.saveMessage(message: message,
                                        toConversationWith: uriString,
                                        toAccountId: accountId,
                                        shouldRefreshConversations: shouldUpdateConversationsList)
            .subscribe()
            .disposed(by: disposeBag)
    }

    func messageStatusChanged(
        _ status: MessageStatus,
        for messageId: String,
        from accountId: String,
        to jamiId: String,
        in conversationId: String
    ) {
        guard let localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId
        else { return }
        if localJamiId == jamiId {
            return
        }
        conversationService.messageStatusChanged(status,
                                                 for: messageId,
                                                 from: accountId,
                                                 to: jamiId,
                                                 in: conversationId)
    }

    func detectingMessageTyping(_ from: String, for accountId: String, status: Int) {
        conversationService.detectingMessageTyping(from, for: accountId, status: status)
    }

    func conversationProfileUpdated(
        conversationId: String,
        accountId: String,
        profile: [String: String]
    ) {
        conversationService.conversationProfileUpdated(
            conversationId: conversationId,
            accountId: accountId,
            profile: profile
        )
    }

    func conversationPreferencesUpdated(
        conversationId: String,
        accountId: String,
        preferences: [String: String]
    ) {
        conversationService.conversationPreferencesUpdated(
            conversationId: conversationId,
            accountId: accountId,
            preferences: preferences
        )
    }
}

extension ConversationsManager: MessagesAdapterDelegate {
    func conversationMemberEvent(
        conversationId: String,
        accountId: String,
        memberUri: String,
        event: Int
    ) {
        guard let conversationEvent = ConversationMemberEvent(rawValue: event) else { return }
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        /// check if we leave conversation on another device. In this case remove conversation
        if conversationEvent == .leave,
           account.jamiId == memberUri {
            conversationService.conversationRemoved(
                conversationId: conversationId,
                accountId: accountId
            )
        } else {
            conversationService.conversationMemberEvent(
                conversationId: conversationId,
                accountId: accountId,
                memberUri: memberUri,
                event: conversationEvent,
                accountURI: account.jamiId
            )
        }
    }

    func didReceiveMessage(_ message: [String: String], from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        if accountsService.boothMode() {
            return
        }
        if let content = message[textPlainMIMEType] {
            handleNewMessage(from: senderAccount,
                             to: receiverAccountId,
                             messageId: messageId,
                             message: content,
                             peerName: nil)
        } else if let content = message[geoLocationMIMEType] {
            handleReceivedLocationUpdate(from: senderAccount,
                                         to: receiverAccountId,
                                         messageId: messageId,
                                         locationJSON: content)
        }
    }

    func conversationReady(conversationId: String, accountId: String) {
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        conversationService.conversationReady(
            conversationId: conversationId,
            accountId: accountId,
            accountURI: account.jamiId
        )
    }

    func updateTransferInfoIfNeed(
        newMessage: MessageModel,
        conversationId: String,
        accountId: String
    ) {
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        if newMessage.type == .fileTransfer {
            let progress = dataTransferService.getTransferProgress(
                withId: newMessage.daemonId,
                accountId: accountId,
                conversationId: conversationId,
                isSwarm: true
            )
            newMessage.transferStatus = progress == 0 ? .awaiting : progress == newMessage
                .totalSize ? .success : .ongoing
            if newMessage.transferStatus == .awaiting &&
                (isDownloadingEnabled(for: newMessage.totalSize) || newMessage.authorId == account
                    .jamiId) {
                var filename = ""
                dataTransferService.downloadFile(withId: newMessage.daemonId,
                                                 interactionID: newMessage.id,
                                                 fileName: &filename, accountID: accountId,
                                                 conversationID: conversationId)
            }
        }
    }

    func messageLoaded(conversationId: String, accountId: String, messages: [[String: String]]) {
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        // convert array of dictionaries to messages
        let messagesModels = messages.map { dictionary -> MessageModel in
            let newMessage = MessageModel(withInfo: dictionary, localJamiId: account.jamiId)
            updateTransferInfoIfNeed(
                newMessage: newMessage,
                conversationId: conversationId,
                accountId: accountId
            )
            return newMessage
        }
        _ = conversationService.insertMessages(
            messages: messagesModels,
            accountId: accountId,
            localJamiId: account.jamiId,
            conversationId: conversationId,
            fromLoaded: true
        )
    }

    func conversationLoaded(
        conversationId: String,
        accountId: String,
        messages: [SwarmMessageWrap],
        requestId _: Int
    ) {
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        // convert array of dictionaries to messages
        let messagesModels = messages.map { wrapInfo -> MessageModel in
            let newMessage = MessageModel(with: wrapInfo, localJamiId: account.jamiId)
            updateTransferInfoIfNeed(
                newMessage: newMessage,
                conversationId: conversationId,
                accountId: accountId
            )
            return newMessage
        }
        _ = conversationService.insertMessages(
            messages: messagesModels,
            accountId: accountId,
            localJamiId: account.jamiId,
            conversationId: conversationId,
            fromLoaded: true
        )
    }

    func reactionAdded(
        conversationId: String,
        accountId: String,
        messageId: String,
        reaction: [String: String]
    ) {
        conversationService.reactionAdded(
            conversationId: conversationId,
            accountId: accountId,
            messageId: messageId,
            reaction: reaction
        )
    }

    func reactionRemoved(
        conversationId: String,
        accountId: String,
        messageId: String,
        reactionId: String
    ) {
        conversationService.reactionRemoved(
            conversationId: conversationId,
            accountId: accountId,
            messageId: messageId,
            reactionId: reactionId
        )
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        guard let jamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId
        else { return }
        conversationService.messageUpdated(
            conversationId: conversationId,
            accountId: accountId,
            message: message,
            localJamiId: jamiId
        )
    }

    func isDownloadingEnabled(for size: Int) -> Bool {
        if !UserDefaults.standard.bool(forKey: automaticDownloadFilesKey) {
            return false
        }

        if maxSizeForAutoaccept == 0 { return true }
        return Int(size) <= maxSizeForAutoaccept
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        guard let account = accountsService.getAccount(fromAccountId: accountId) else { return }
        let newMessage = MessageModel(with: message, localJamiId: account.jamiId)
        if newMessage.type == .fileTransfer {
            newMessage.transferStatus = newMessage.incoming ? .awaiting : .success
        }
        if conversationService.insertMessages(
            messages: [newMessage],
            accountId: accountId,
            localJamiId: account.jamiId,
            conversationId: conversationId,
            fromLoaded: false
        ) {
            let incoming = message.body[MessageAttributes.author.rawValue] != account.jamiId
            if incoming {
                if newMessage
                    .transferStatus != .awaiting ||
                    !isDownloadingEnabled(for: newMessage.totalSize) {
                    return
                }
            } else {
                if newMessage.transferStatus != .awaiting && newMessage.transferStatus != .success {
                    return
                }
            }
            var filename = ""
            dataTransferService.downloadFile(
                withId: newMessage.daemonId,
                interactionID: newMessage.id,
                fileName: &filename,
                accountID: accountId,
                conversationID: conversationId
            )
        }
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        requestService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        conversationService.conversationRemoved(
            conversationId: conversationId,
            accountId: accountId
        )
    }

    func conversationDeclined(conversationId: String, accountId: String) {
        requestService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        conversationService.conversationRemoved(
            conversationId: conversationId,
            accountId: accountId
        )
    }
}

extension ConversationsManager: RequestsAdapterDelegate {
    func incomingTrustRequestReceived(
        from jamiId: String,
        to accountId: String,
        conversationId: String,
        withPayload payload: Data,
        receivedDate: Date
    ) {
        guard let localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId
        else { return }
        if localJamiId == jamiId {
            // This is request from self. Should not display.
            return
        }
        requestService.incomingTrustRequestReceived(
            from: jamiId,
            to: accountId,
            conversationId: conversationId,
            withPayload: payload,
            receivedDate: receivedDate
        )
    }

    func conversationRequestReceived(
        conversationId: String,
        accountId: String,
        metadata: [String: String]
    ) {
        guard let localJamiId = accountsService.getAccount(fromAccountId: accountId)?.jamiId,
              let peerUri = metadata["from"] else { return }
        if localJamiId == peerUri {
            // This is request from self. Should not display.
            return
        }
        requestService.conversationRequestReceived(
            conversationId: conversationId,
            accountId: accountId,
            metadata: metadata
        )
    }
}

extension ConversationsManager: ProfilesAdapterDelegate {
    func profileReceived(contact uri: String, withAccountId accountId: String, path: String) {
        if let account = accountsService.getAccount(fromAccountId: accountId),
           account.jamiId == uri {
            profileService.accountProfileUpdated(accountId: accountId)
        } else {
            profileService.profileReceived(contact: uri, withAccountId: accountId, path: path)
        }
    }
}

// swiftlint:enable type_body_length
