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
    private let videoService: VideoService

    private let disposeBag = DisposeBag()
    private let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"
    private let maxSizeForAutoaccept = 20 * 1024 * 1024
    private let notificationHandler = LocalNotificationsHelper()

    // swiftlint:disable cyclomatic_complexity
    init(with conversationService: ConversationsService, accountsService: AccountsService, nameService: NameService,
         dataTransferService: DataTransferService, callService: CallsService, locationSharingService: LocationSharingService, contactsService: ContactsService, callsProvider: CallsProviderDelegate, videoService: VideoService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.callService = callService
        self.locationSharingService = locationSharingService
        self.contactsService = contactsService
        self.callsProvider = callsProvider
        self.videoService = videoService

        ConversationsAdapter.messagesDelegate = self
        self.subscribeFileTransferEvents()
        self.subscribeCallsEvents() // in call messages for non swarm conversations
       // self.subscribeLocationSharingEvent()
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
        self.callService.sharedResponseStream.filter { event in
            event.eventType == .callEnded
        }.subscribe { event in
            guard let accountID: String = event.getEventInput(.accountId) else {
                return
            }

            guard let jamiId: String = event.getEventInput(.uri) else {
                return
            }
            guard let call = self.callService.call(participantHash: jamiId.filterOutHost(), accountID: accountID) else { return }
            self.callsProvider.stopCall(callUUID: call.callUUID)
            self.videoService.stopCapture()
            self.videoService.setCameraOrientation(orientation: UIDevice.current.orientation)
        } onError: { _ in

        }.disposed(by: disposeBag)

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
                guard let transferId: UInt64 = event.getEventInput(ServiceEventInput.transferId),
                    let transferInfo = self.dataTransferService.getTransferInfo(withId: transferId),
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
                                                     updateConversation: currentAccount.id == transferInfo.accountId )
                        .subscribe(onCompleted: {
                            guard let transferInfo = self.dataTransferService
                                .getTransferInfo(withId: transferId) else { return }
                            self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: transferInfo.accountId)
                        })
                        .disposed(by: self.disposeBag)
                case .dataTransferChanged:
                    self.log.debug("ConversationsManager: dataTransferChanged - id:\(transferId) status:\(stringFromEventCode(with: transferInfo.lastEvent))")
                    var status: DataTransferStatus = .unknown
                    switch transferInfo.lastEvent {
                    case .closed_by_host, .closed_by_peer:
                        status = DataTransferStatus.canceled
                        self.conversationService.dataTransferMessageMap.removeValue(forKey: transferId)
                    case .invalid, .unsupported, .invalid_pathname, .unjoinable_peer:
                        status = DataTransferStatus.error
                        self.conversationService.dataTransferMessageMap.removeValue(forKey: transferId)
                    case .wait_peer_acceptance, .wait_host_acceptance:
                        status = DataTransferStatus.awaiting
                        self.createTransferNotification(info: transferInfo)
                        self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: transferInfo.accountId)
                    case .ongoing:
                        status = DataTransferStatus.ongoing
                    case .finished:
                        status = DataTransferStatus.success
                        self.conversationService.dataTransferMessageMap.removeValue(forKey: transferId)
                    case .created:
                        break
                    @unknown default:
                        break
                    }
                    self.conversationService.transferStatusChanged(status, for: transferId, accountId: transferInfo.accountId, to: transferInfo.peer)
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
    private func handleReceivedLocationUpdate(from peerUri: String, to accountId: String, messageId: String, locationJSON content: String) {
        guard let currentAccount = self.accountsService.currentAccount,
            let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }

        let type = AccountModelHelper.init(withAccount: accountForMessage).isAccountSip() ? URIType.sip : URIType.ring
        guard let peerUri = JamiURI.init(schema: type, infoHach: peerUri, account: accountForMessage).uriString else { return }

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
        self.locationSharingService.handleReceivedLocationUpdate(from: peerUri, to: accountId, messageId: messageId, locationJSON: content)
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

    func createTransferNotification(info: NSDataTransferInfo) {
        guard let account = self.accountsService.getAccount(fromAccountId: info.accountId),
            AccountModelHelper.init(withAccount: account).isAccountRing(),
            self.accountsService.getCurrentProxyState(accountID: info.accountId) else { return }
        var message = L10n.Notifications.newFile + " "
        if let name = info.path.split(separator: "/").last {
            message += name
        } else {
            message += info.path
        }
        self.presentNotification(from: info.peer, to: account, message: message, peerName: info.displayName)
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

    func autoAcceptTransfer(transferInfo: NSDataTransferInfo, transferId: UInt64, accountId: String) {
        if transferInfo.flags != 1 || transferInfo.totalSize > maxSizeForAutoaccept ||
            (transferInfo.lastEvent != .wait_peer_acceptance && transferInfo.lastEvent != .wait_host_acceptance) {
            return
        }
        guard let messageData = self.conversationService.dataTransferMessageMap[transferId] else { return }
        var filename = ""
        if self.dataTransferService.acceptTransfer(withId: transferId, interactionID: messageData.messageID,
                                                   fileName: &filename, accountID: accountId,
                                                   conversationID: String(messageData.conversationID)) != .success {
            self.log.debug("ConversationsManager: accept transfer failed")
        }
    }

    func detectingMessageTyping(_ from: String, for accountId: String, status: Int) {
        conversationService.detectingMessageTyping(from, for: accountId, status: status)
    }
}

extension  ConversationsManager: MessagesAdapterDelegate {
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

    func conversationLoaded(conversationId: String, accountId: String, messages: [Any]) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        self.conversationService.conversationLoaded(conversationId: conversationId, accountId: accountId, messages: messages, accountURI: account.jamiId)
    }

    func newInteraction(conversationId: String, accountId: String, message: [String: String]) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else { return }
        self.conversationService.newInteraction(conversationId: conversationId, accountId: accountId, message: message, accountURI: account.jamiId)
        // present notification for text
        if let type = message[MessageAttributes.type.rawValue],
           let body = message[MessageAttributes.body.rawValue],
           let peer = message[MessageAttributes.author.rawValue],
           peer != account.jamiId,
           type == MessageType.text.rawValue {
            self.presentNotification(from: peer, to: account, message: body, peerName: peer)
        }
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        guard let conversation = self.conversationService.getConversationForId(conversationId: conversationId, accountId: accountId) else { return }
        if conversation.type != .oneToOne {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
            return
        }
        if let participant = conversation.getParticipants().first, let _ = self.contactsService.contact(withHash: participant.jamiId) {
            self.conversationService.saveLegacyConversation(conversation: conversation)
        } else {
            self.conversationService.conversationRemoved(conversationId: conversationId, accountId: accountId)
        }
    }
}
// swiftlint:enable type_body_length
