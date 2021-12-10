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
    private let callsProvider: CallsProviderDelegate
    private let requestService: RequestsService

    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"
    private let maxSizeForAutoaccept = 20 * 1024 * 1024
    private let notificationHandler = LocalNotificationsHelper()

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
        self.subscribeLocationSharingEvent()
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

    private func subscribeLocationSharingEvent() {
        self.locationSharingService
            .locationServiceEventShared
            .filter({ $0.eventType == ServiceEventType.stopLocationSharing })
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                var data = [String: String]()
                data[NotificationUserInfoKeys.messageContent.rawValue] = event.getEventInput(ServiceEventInput.content)
                data[NotificationUserInfoKeys.participantID.rawValue] = event.getEventInput(ServiceEventInput.peerUri)
                data[NotificationUserInfoKeys.accountID.rawValue] = event.getEventInput(ServiceEventInput.accountId)

                guard let contactUri = data[NotificationUserInfoKeys.participantID.rawValue],
                      let hash = JamiURI(schema: URIType.ring, infoHach: contactUri).hash else { return }

                DispatchQueue.main.async { [weak self] in
                    self?.searchNameAndPresentNotification(data: data, hash: hash)
                }
            })
            .disposed(by: self.disposeBag)

        self.locationSharingService
            .locationServiceEventShared
            .filter({ $0.eventType == ServiceEventType.sendLocation })
            .subscribe(onNext: { [weak self] event in
                guard let self = self,
                      let currentAccount = self.accountsService.currentAccount,
                      let (content, shouldTryToSave): (String, Bool) = event.getEventInput(ServiceEventInput.content),
                      let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                      let account = self.accountsService.getAccount(fromAccountId: accountId),
                      let conversationId: String = event.getEventInput(ServiceEventInput.conversationId)
                      else { return }

                let shouldRefresh = currentAccount.id == accountId

                self.conversationService
                    .sendLocation(withContent: content,
                                  from: account,
                                  conversationId: conversationId,
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
                    let messageContent: String = event.getEventInput(ServiceEventInput.content),
                    let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                    else { return }
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
                        .subscribe(onCompleted: {
                            guard let transferInfo = self.dataTransferService
                                    .dataTransferInfo(withId: transferId, accountId: accountId, conversationId: conversationId, isSwarm: false) else { return }
                            self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: transferInfo.accountId, conversationId: conversationId)
                        })
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
                            self.createTransferNotification(info: transferInfo, conversationId: conversationId, accountId: accountId)
                            self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: accountId, conversationId: conversationId)
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
        .subscribe()
        .disposed(by: self.disposeBag)
    }

    // MARK: Message Adapter delegate
    private func handleReceivedLocationUpdate(from peerId: String, to accountId: String, messageId: String, locationJSON content: String) {
        guard let currentAccount = self.accountsService.currentAccount,
            let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId),
            let conversation = conversationService.getConversationForParticipant(jamiId: peerId, accontId: accountId) else { return }

        let type = AccountModelHelper.init(withAccount: accountForMessage).isAccountSip() ? URIType.sip : URIType.ring
        guard let peerUri = JamiURI.init(schema: type, infoHach: peerId, account: accountForMessage).uriString else { return }

        if self.conversationService.isBeginningOfLocationSharing(incoming: true, contactUri: peerUri, accountId: accountId) {
            self.presentNotification(from: peerUri, to: accountForMessage, message: L10n.Notifications.locationSharingStarted, peerName: nil)

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
        self.locationSharingService.handleReceivedLocationUpdate(from: peerUri, to: accountId, messageId: messageId, locationJSON: content, conversationId: conversation.id)
    }

    func handleNewMessage(from peerUri: String, to accountId: String, messageId: String, message content: String, peerName: String?) {
        guard let currentAccount = self.accountsService.currentAccount,
            let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        self.presentNotification(from: peerUri, to: accountForMessage, message: content, peerName: peerName)
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

    private func presentNotification(from peerUri: String, to account: AccountModel, message content: String, peerName: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                UIApplication.shared.applicationState != .active,
                AccountModelHelper.init(withAccount: account).isAccountRing(),
                self.accountsService.getCurrentProxyState(accountID: account.id) else { return }
            var data = [String: String]()
            data [NotificationUserInfoKeys.messageContent.rawValue] = content
            data [NotificationUserInfoKeys.participantID.rawValue] = peerUri
            data [NotificationUserInfoKeys.accountID.rawValue] = account.id
            if let name = peerName {
                data [NotificationUserInfoKeys.name.rawValue] = name
                self.notificationHandler.presentMessageNotification(data: data)
                return
            }
            guard let hash = JamiURI(schema: URIType.ring, infoHach: peerUri).hash else { return }
            DispatchQueue.global(qos: .background).async {
                self.searchNameAndPresentNotification(data: data, hash: hash)
            }
        }
    }

    func createTransferNotification(info: NSDataTransferInfo, conversationId: String, accountId: String) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId),
            AccountModelHelper.init(withAccount: account).isAccountRing(),
            self.accountsService.getCurrentProxyState(accountID: accountId) else { return }
        var message = L10n.Notifications.newFile + " "
        if let path = info.path {
            if let name = path.split(separator: "/").last {
                message += name
            } else {
                message += info.path
            }
        }
        if !conversationId.isEmpty {
            guard let conversation = self.conversationService.getConversationForId(conversationId: conversationId, accountId: accountId),
                  let jamiId = conversation.getParticipants().first?.jamiId else { return }
            self.presentNotification(from: jamiId, to: account, message: message, peerName: "")
        } else if let peerId = info.peer, let name = info.displayName {
            self.presentNotification(from: peerId, to: account, message: message, peerName: name)
        }
    }

    func searchNameAndPresentNotification(data: [String: String], hash: String) {
        var data = data
        var accountId = ""
        if let getAccountFromDictionary = data[NotificationUserInfoKeys.accountID.rawValue] {
            accountId = getAccountFromDictionary
        }
        self.nameService.usernameLookupStatus.single()
            .filter({ lookupNameResponse in
                return lookupNameResponse.address != nil &&
                    lookupNameResponse.address == hash
            })
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    data [NotificationUserInfoKeys.name.rawValue] = name
                    self?.notificationHandler.presentMessageNotification(data: data)
                } else if let address = lookupNameResponse.address {
                    data [NotificationUserInfoKeys.name.rawValue] = address
                    self?.notificationHandler.presentMessageNotification(data: data)
                }
            })
            .disposed(by: self.disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: hash)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      from: accountId,
                                                      to: jamiId,
                                                      in: conversationId)
    }

    func autoAcceptTransfer(transferInfo: NSDataTransferInfo, transferId: String, accountId: String, conversationId: String) {
        // for swarm we download message when receive interaction
        if !conversationId.isEmpty { return }
        if transferInfo.flags != 1 || transferInfo.totalSize > maxSizeForAutoaccept ||
            (transferInfo.lastEvent != .wait_peer_acceptance && transferInfo.lastEvent != .wait_host_acceptance) {
            return
        }
        guard let conversation = self.conversationService.getConversationForParticipant(jamiId: transferInfo.peer, accontId: accountId) else { return }
        var filename = ""
        if self.dataTransferService.acceptTransfer(withId: transferId,
                                                   fileName: &filename, accountID: accountId,
                                                   conversationID: conversation.id, name: "") != .success {
            self.log.debug("ConversationsManager: accept transfer failed")
        }
    }

    func detectingMessageTyping(_ from: String, for accountId: String, status: Int) {
        conversationService.detectingMessageTyping(from, for: accountId, status: status)
    }
}

extension  ConversationsManager: MessagesAdapterDelegate {
    func conversationMemberEvent(conversationId: String, accountId: String, memberUri: String, event: Int) {
        let conversationEvent = ConversationMemberEvent(rawValue: event)
        /// check if we leave conversation on another device. In this case remove conversation
        if conversationEvent == .leave,
           let account = self.accountsService.getAccount(fromAccountId: accountId),
           account.jamiId == memberUri {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
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
                /// check if we need to download file for transfer
                if let transferInfo = self.dataTransferService.dataTransferInfo(withId: newMessage.daemonId, accountId: accountId, conversationId: conversationId, isSwarm: true) {
                    newMessage.transferStatus = transferInfo.bytesProgress == 0 ? .awaiting : transferInfo.bytesProgress == transferInfo.totalSize ? .success : .ongoing
                    let image = self.dataTransferService.getImage(for: newMessage.daemonId, maxSize: 200, accountID: accountId, conversationID: conversationId, isSwarm: true)
                    if newMessage.transferStatus == .awaiting, transferInfo.totalSize <= maxSizeForAutoaccept, image == nil {
                        var filename = ""
                        self.dataTransferService.downloadFile(withId: newMessage.daemonId,
                                                              interactionID: newMessage.id,
                                                              fileName: &filename, accountID: accountId,
                                                              conversationID: conversationId)
                    }
                } else {
                    newMessage.transferStatus = .success
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
        if newMessage.type == .location {
            self.handleReceivedLocationUpdate(from: newMessage.authorId,
                                              to: accountId,
                                              messageId: newMessage.id,
                                              locationJSON: newMessage.content)

        }
        /// if new message was inserted check if we need to present notification
        if self.conversationService.insertMessages(messages: [newMessage], accountId: accountId, conversationId: conversationId, fromLoaded: false) {
            /// check if file saved
            let image = self.dataTransferService.getImage(for: newMessage.daemonId, maxSize: 200, accountID: accountId, conversationID: conversationId, isSwarm: true)
            /// download if file not saved yet
            if let size = message["totalSize"],
               image == nil,
               (newMessage.transferStatus == .awaiting || newMessage.transferStatus == .success),
               Int(size) ?? 30 * 1024 * 1024 <= maxSizeForAutoaccept {
                var filename = ""
                self.dataTransferService.downloadFile(withId: newMessage.daemonId, interactionID: newMessage.id, fileName: &filename, accountID: accountId, conversationID: conversationId)
            }
            if let type = message[MessageAttributes.type.rawValue],
               let body = message[MessageAttributes.body.rawValue],
               let peer = message[MessageAttributes.author.rawValue],
               peer != account.jamiId,
               type == MessageType.text.rawValue {
                self.presentNotification(from: peer, to: account, message: body, peerName: peer)
            }
        }
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        guard let conversation = self.conversationService.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        if conversation.type != .oneToOne {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
            return
        }
        if let participant = conversation.getParticipants().first,
           self.contactsService.contactExists(withHash: participant.jamiId, accountId: accountId) {
            self.conversationService.saveLegacyConversation(conversation: conversation, isExisting: true)
        } else {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        }
    }

    func conversationDeclined(conversationId: String, accountId: String) {
        self.requestService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
    }
}
// swiftlint:enable type_body_length
