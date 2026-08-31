/*
 * Copyright (C) 2017-2025 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
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
    private let callService: CallService
    private let callsManager: CallsManager
    private let locationSharingService: LocationSharingService
    private let requestService: RequestsService
    private let profileService: ProfilesService
    private let presenceService: PresenceService

    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"
    private var maxSizeForAutoaccept: Int {
        return UserDefaults.standard.integer(forKey: acceptTransferLimitKey) * 1024 * 1024
    }
    private let appState: BehaviorRelay<ServiceEventType>
    private var pendingCallBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let postCallSyncTimeout: TimeInterval = 3
    private var pendingPostCallSync: PendingPostCallSync?
    private var postCallSyncTimeoutWork: DispatchWorkItem?

    // swiftlint:disable cyclomatic_complexity
    init(with conversationService: ConversationsService,
         accountsService: AccountsService,
         nameService: NameService,
         dataTransferService: DataTransferService,
         callService: CallService,
         callsManager: CallsManager,
         locationSharingService: LocationSharingService,
         contactsService: ContactsService,
         requestsService: RequestsService,
         profileService: ProfilesService,
         presenceService: PresenceService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.callService = callService
        self.callsManager = callsManager
        self.locationSharingService = locationSharingService
        self.contactsService = contactsService
        self.requestService = requestsService
        self.profileService = profileService
        self.presenceService = presenceService
        self.appState = BehaviorRelay<ServiceEventType>(
            value: UIApplication.shared.applicationState == .background ? .appEnterBackground : .appEnterForeground)
        ProfilesAdapter.delegate = self

        ConversationsAdapter.messagesDelegate = self
        RequestsAdapter.delegate = self
        /*
         When the application starts, all conversations will be loaded.
         Conversation data should be cleaned to prevent reloading conversations
         that were updated from notifications
         */
        self.cleanConversationData()
        self.subscribeFileTransferEvents()
        self.subscribeCallsEvents()
        self.subscribeContactsEvents()
        self.subscribeLocationSharingEvent()
        self.subscribeRequestEvents()
        self.subscribeProfileEvents()
        self.controlAccountsState()
    }

    // When the application is inactive, the accounts should also be inactive. Except when when handling incoming call.
    private func controlAccountsState() {
        // Subscribe to app state changes
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        // calls events
        let callProviderEvents = callService.sharedResponseStream
            .filter({ (event) in
                return event.eventType == .callProviderPreviewPendingCall
            })
        let callEndedEvents = self.callService.sharedResponseStream
            .filter({ (event) in
                return  event.eventType == .callEnded
            })

        appState
            .asObservable()
            .subscribe(onNext: { [weak self] eventType in
                guard let self = self else { return }
                switch eventType {
                case .appEnterBackground:
                    self.updateBackgroundState()
                case .appEnterForeground:
                    // Cancel before the hop so the timeout cannot deactivate the foreground account.
                    self.cancelPostCallSync()
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let self = self else { return }
                        self.updateForegroundState()
                    }
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        Observable.of(callProviderEvents.asObservable(),
                      callEndedEvents.asObservable())
            .merge()
            .subscribe(onNext: { [weak self] serviceEvent in
                guard let self = self else { return }
                switch serviceEvent.eventType {
                case .callProviderPreviewPendingCall:
                    // Prevent the previous timeout from deactivating the new call.
                    self.cancelPostCallSync()
                    self.accountsService.setAccountsActive(active: true)
                    self.beginPendingCallBackgroundTask()
                    if let payload: [String: String] = serviceEvent.getEventInput(.content),
                       !payload.isEmpty {
                        self.accountsService.pushNotificationReceived(data: payload)
                    }
                    // Reload conversations updated in the background if required.
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        guard let self = self,
                              let updatedConversations = self.getConversationData() else { return }
                        self.cleanConversationData()
                        let accountIds = extractAccountIds(from: updatedConversations)
                        self.reloadConversationsAndRequests(accountIds: accountIds)
                    }
                case .callEnded:
                    DispatchQueue.main.async {
                        guard UIApplication.shared.applicationState != .active else {
                            self.endPendingCallBackgroundTask()
                            return
                        }
                        let peerUri: String = serviceEvent.getEventInput(.peerUri) ?? ""
                        self.awaitPostCallSync(accountId: serviceEvent.getEventInput(.accountId) ?? "",
                                               peerHash: ProfilePathHelper.jamiHash(from: peerUri))
                    }
                default:
                    break
                }
            }, onError: { _ in
            })
            .disposed(by: self.disposeBag)
    }

    /*
     When the app is in the background, the account should not be active, and
     the notification extension should handle incoming notifications unless there is a pending call.
     */
    func updateBackgroundState() {
        if self.callsManager.hasActiveCalls() { return }
        if self.pendingPostCallSync != nil { return }
        self.releaseAccount()
    }

    // The call screen state has to be reset with the account, otherwise the
    // extension keeps deferring to an app that no longer owns the account.
    private func releaseAccount() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.updateCallScreenState(presenting: false)
        }
        self.accountsService.setAccountsActive(active: false)
    }

    /*
     A VoIP push activates the account while the app is in the background. If iOS
     suspends the app before the pending call is resolved, the account would be
     carried over as active into the suspended state: the next foreground
     setAccountsActive(true) would then be a no-op in the daemon (no
     re-registration, stale connectivity), and the notification extension could
     not own the account. Keep the app alive briefly so the account can be
     released before suspension.
     */
    private func beginPendingCallBackgroundTask() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.pendingCallBackgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.pendingCallBackgroundTask)
                self.pendingCallBackgroundTask = .invalid
            }
            self.pendingCallBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "pending-call-account") { [weak self] in
                self?.handlePendingCallTaskExpiration()
            }
        }
    }

    // A CallKit-only placeholder must not block the handoff, but an ongoing call
    // confirmed by the daemon still needs the account.
    private func handlePendingCallTaskExpiration() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.cancelPostCallSync()
            if !self.callService.hasOngoingCalls {
                self.releaseAccount()
            }
            if self.pendingCallBackgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.pendingCallBackgroundTask)
                self.pendingCallBackgroundTask = .invalid
            }
        }
    }

    private func endPendingCallBackgroundTask() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.pendingCallBackgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(self.pendingCallBackgroundTask)
            self.pendingCallBackgroundTask = .invalid
        }
    }

    // The peer sends the final call-history commit over the call connection,
    // so keep it alive until the commit arrives or the wait expires.
    private func awaitPostCallSync(accountId: String, peerHash: String) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.beginPendingCallBackgroundTask()
            self.postCallSyncTimeoutWork?.cancel()
            self.pendingPostCallSync = PendingPostCallSync(accountId: accountId,
                                                           peerHash: peerHash)
            let timeoutWork = DispatchWorkItem { [weak self] in
                self?.finishPostCallSync()
            }
            self.postCallSyncTimeoutWork = timeoutWork
            DispatchQueue.main.asyncAfter(deadline: .now() + self.postCallSyncTimeout,
                                          execute: timeoutWork)
        }
    }

    private func finishPostCallSync() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.postCallSyncTimeoutWork?.cancel()
            self.postCallSyncTimeoutWork = nil
            self.pendingPostCallSync = nil
            if UIApplication.shared.applicationState != .active {
                self.updateBackgroundState()
            }
            self.endPendingCallBackgroundTask()
        }
    }

    private func cancelPostCallSync() {
        onMain { [weak self] in
            guard let self = self else { return }
            self.postCallSyncTimeoutWork?.cancel()
            self.postCallSyncTimeoutWork = nil
            self.pendingPostCallSync = nil
        }
    }

    private func confirmPostCallSyncIfNeeded(accountId: String, message: MessageModel) {
        onMain { [weak self] in
            guard let self = self,
                  let pending = self.pendingPostCallSync,
                  pending.isConfirmed(by: message, from: accountId) else { return }
            self.finishPostCallSync()
        }
    }

    // Preserve ordering between cancellation and an already-due timeout.
    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
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
        self.endPendingCallBackgroundTask()
        guard let updatedConversations = self.getConversationData() else {
            self.accountsService.setAccountsActive(active: true)
            return
        }
        self.cleanConversationData()
        // ask daemon to reload conversations and request from file
        let accountIds = extractAccountIds(from: updatedConversations)
        self.reloadConversationsAndRequests(accountIds: accountIds)
        self.accountsService.setAccountsActive(active: true)
        // get requests from the daemon
        self.updateRequests(accountIds: accountIds)
        // get interactions from the daemon
        self.reloadConversationMessages(updatedConversations: updatedConversations)
    }

    func extractAccountIds(from conversations: [[String: String]]) -> Set<String> {
        var accountIds = Set<String>()
        for conversationData in conversations {
            if let accountId = conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue] {
                accountIds.insert(accountId)
            }
        }
        return accountIds
    }

    func reloadConversationsAndRequests(accountIds: Set<String>) {
        for accountId in accountIds {
            self.conversationService.reloadConversationsAndRequests(accountId: accountId)
        }
    }

    func updateRequests(accountIds: Set<String>) {
        for accountId in accountIds {
            self.requestService.updateConversationsRequests(withAccount: accountId)
        }
    }

    func reloadConversationMessages(updatedConversations: [[String: String]]) {
        for conversationData in updatedConversations {
            if let accountId = conversationData[Constants.NotificationUserInfoKeys.accountID.rawValue],
               let currentAccountId = self.accountsService.currentAccount?.id,
               let conversationId = conversationData[Constants.NotificationUserInfoKeys.conversationID.rawValue],
               accountId == currentAccountId {
                self.conversationService.updateConversationMessages(conversationId: conversationId)
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
        self.requestService.sharedResponseStream
            .filter({ $0.eventType == ServiceEventType.requestAccepted })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let conversationId: String = event.getEventInput(.conversationId),
                      let account = self.accountsService.getAccount(fromAccountId: accountId)
                else { return }
                let type: ConversationType = event.getEventInput(.conversationType) ?? .invitesOnly
                self.conversationService.addConversationFromAcceptedRequest(conversationId: conversationId, accountId: accountId, accountURI: account.jamiId, type: type)
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeProfileEvents() {
        self.requestService.sharedResponseStream
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let peerUri: String = event.getEventInput(.peerUri)
                else { return }
                switch event.eventType {
                case .contactRequestAdded:
                    self.profileService.invitationReceived(uri: peerUri, accountId: accountId)
                case .contactRequestSent:
                    self.profileService.invitationSent(uri: peerUri, accountId: accountId)
                case .contactRequestAccepted:
                    guard let profile: Profile = event.getEventInput(.profile) else { return }
                    self.profileService.invitationAccepted(profile, accountId: accountId)
                case .contactRequestRemoved:
                    self.profileService.peerDiscarded(uri: peerUri, accountId: accountId)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        self.contactsService.sharedResponseStream
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId) else { return }
                switch event.eventType {
                case .allContactsRemoved:
                    self.profileService.accountContactsCleared(accountId: accountId)
                case .contactRemoved:
                    guard let peerUri: String = event.getEventInput(.peerUri) else { return }
                    self.profileService.peerDiscarded(uri: peerUri, accountId: accountId)
                default:
                    break
                }
            })
            .disposed(by: self.disposeBag)

        self.conversationService.sharedResponseStream
            .filter({ $0.eventType == ServiceEventType.conversationRemoved })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let peerUri: String = event.getEventInput(.peerUri)
                else { return }
                self.profileService.conversationDeleted(uri: peerUri, accountId: accountId)
            })
            .disposed(by: self.disposeBag)
    }

    private func subscribeContactsEvents() {
        self.contactsService.sharedResponseStream
            .filter({ $0.eventType == ServiceEventType.contactAdded })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let accountId: String = event.getEventInput(.accountId),
                      let jamiId: String = event.getEventInput(.peerUri),
                      let account = self.accountsService.getAccount(fromAccountId: accountId),
                      let currentAccount = self.accountsService.currentAccount,
                      account == currentAccount,
                      let contact = self.contactsService.contact(withHash: jamiId)
                else { return }
                if !contact.banned {
                    self.presenceService.subscribeBuddy(withAccountId: accountId, withJamiId: jamiId, withFlag: true)
                }
                guard account.isJams, !contact.conversationId.isEmpty else { return }
                self.conversationService.addSwarmConversationId(conversationId: contact.conversationId, accountId: accountId, jamiId: jamiId)
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
    }

    private func subscribeCallsEvents() {
        // CallKit teardown on call end is owned by CallKitService;
        // only in-call messages are handled here.
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
                    self.log.error("ConversationsManager: unable to find transferInfo")
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
        guard let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }

        let type = AccountModelHelper.init(withAccount: accountForMessage).isAccountSip() ? URIType.sip : URIType.ring
        guard let peerUri = JamiURI.init(schema: type, infoHash: peerId, account: accountForMessage).uriString else { return }

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
                                           infoHash: peerUri,
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
        guard let localJamiId = self.accountsService.getAccount(fromAccountId: accountId)?.jamiId else { return }
        if localJamiId == jamiId {
            return
        }
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      from: accountId,
                                                      to: jamiId,
                                                      in: conversationId)
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
        // Check if we leave the conversation on another device. In this case remove conversation.
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
        guard let currentAccount = self.accountsService.currentAccount else { return }
        if account == currentAccount {
            self.conversationService.conversationReady(conversationId: conversationId, accountId: accountId, accountURI: account.jamiId)
        }
    }

    func updateTransferInfoIfNeed(newMessage: MessageModel, conversationId: String, accountId: String) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        if newMessage.type == .fileTransfer {
            let progress = self.dataTransferService.getTransferProgress(withId: newMessage.daemonId, accountId: accountId, conversationId: conversationId, isSwarm: true)
            newMessage.transferStatus = progress == 0 ? .awaiting : progress == newMessage.totalSize ? .success : .ongoing
            if newMessage.transferStatus == .awaiting &&
                (isDownloadingEnabled(for: newMessage.totalSize) || newMessage.authorId == account.jamiId) {
                var filename = ""
                self.dataTransferService.downloadFile(withId: newMessage.daemonId,
                                                      interactionID: newMessage.id,
                                                      fileName: &filename, accountID: accountId,
                                                      conversationID: conversationId)
            }
        }

    }

    func conversationLoaded(conversationId: String, accountId: String, messages: [SwarmMessageWrap], requestId: Int) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        // Convert array of dictionaries to messages.
        let messagesModels = messages.map { wrapInfo -> MessageModel in
            let newMessage = MessageModel(with: wrapInfo, localJamiId: account.jamiId)
            updateTransferInfoIfNeed(newMessage: newMessage, conversationId: conversationId, accountId: accountId)
            return newMessage
        }
        _ = self.conversationService.insertMessages(messages: messagesModels, accountId: accountId, localJamiId: account.jamiId, conversationId: conversationId, fromLoaded: true)
    }

    func reactionAdded(conversationId: String, accountId: String, messageId: String, reaction: [String: String]) {
        self.conversationService.reactionAdded(conversationId: conversationId, accountId: accountId, messageId: messageId, reaction: reaction)
    }

    func composingStatusChanged(accountId: String, conversationId: String, from: String, status: Int) {
        self.conversationService.composingStatusChanged(accountId: accountId, conversationId: conversationId, from: from, status: status)
    }

    func reactionRemoved(conversationId: String, accountId: String, messageId: String, reactionId: String) {
        self.conversationService.reactionRemoved(conversationId: conversationId, accountId: accountId, messageId: messageId, reactionId: reactionId)
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        guard let jamiId = self.accountsService.getAccount(fromAccountId: accountId)?.jamiId else { return }
        self.conversationService.messageUpdated(conversationId: conversationId, accountId: accountId, message: message, localJamiId: jamiId)
    }

    func isDownloadingEnabled(for size: Int) -> Bool {
        if !UserDefaults.standard.bool(forKey: automaticDownloadFilesKey) {
            return false
        }

        if maxSizeForAutoaccept == 0 { return true}
        return Int(size) <= maxSizeForAutoaccept
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        let newMessage = MessageModel(with: message, localJamiId: account.jamiId)
        self.confirmPostCallSyncIfNeeded(accountId: accountId, message: newMessage)
        if newMessage.type == .fileTransfer {
            newMessage.transferStatus = newMessage.incoming ? .awaiting : .success
        }
        if self.conversationService.insertMessages(messages: [newMessage], accountId: accountId, localJamiId: account.jamiId, conversationId: conversationId, fromLoaded: false) {
            let incoming = message.body[MessageAttributes.author.rawValue] != account.jamiId
            if incoming {
                if newMessage.transferStatus != .awaiting || !isDownloadingEnabled(for: newMessage.totalSize) {
                    return
                }
            } else {
                if newMessage.transferStatus != .awaiting && newMessage.transferStatus != .success {
                    return
                }
            }
            var filename = ""
            self.dataTransferService.downloadFile(withId: newMessage.daemonId, interactionID: newMessage.id, fileName: &filename, accountID: accountId, conversationID: conversationId)
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

    func activeCallsChanged(conversationId: String, accountId: String, calls: [[String: String]]) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else {
            return
        }
        self.callService.activeCallsChanged(conversationId: conversationId, calls: calls, account: account)
    }
}

extension  ConversationsManager: RequestsAdapterDelegate {
    func incomingTrustRequestReceived(from jamiId: String, to accountId: String, conversationId: String, withPayload payload: Data, receivedDate: Date) {
        guard let localJamiId = self.accountsService.getAccount(fromAccountId: accountId)?.jamiId else { return }
        if localJamiId == jamiId {
            // This is request from self. Should not display.
            return
        }
        self.requestService.incomingTrustRequestReceived(from: jamiId, to: accountId, conversationId: conversationId, withPayload: payload, receivedDate: receivedDate)
    }

    func conversationRequestReceived(conversationId: String, accountId: String, metadata: [String: String]) {
        guard let localJamiId = self.accountsService.getAccount(fromAccountId: accountId)?.jamiId,
              let peerUri = metadata["from"] else { return }
        if localJamiId == peerUri {
            // This is request from self. Should not display.
            return
        }
        self.requestService.conversationRequestReceived(conversationId: conversationId, accountId: accountId, metadata: metadata)

    }
}

extension ConversationsManager: ProfilesAdapterDelegate {
    func profileReceived(contact uri: String, withAccountId accountId: String, path: String) {
        if let account = self.accountsService.getAccount(fromAccountId: accountId),
           account.jamiId == uri {
            self.profileService.accountProfileUpdated(accountId: accountId)
        } else {
            self.profileService.profileReceived(contact: uri, withAccountId: accountId, path: path)
        }
    }
}
// swiftlint:enable type_body_length
