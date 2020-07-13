/*
 *  Copyright (C) 2017-2020 Savoir-faire Linux Inc.
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

class ConversationsManager: MessagesAdapterDelegate {

    let log = SwiftyBeaver.self

    private let conversationService: ConversationsService
    private let accountsService: AccountsService
    private let nameService: NameService
    private let dataTransferService: DataTransferService
    private let callService: CallsService
    private let locationSharingService: LocationSharingService

    private let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"
    private let geoLocationMIMEType = "application/geo"
    fileprivate let maxSizeForAutoaccept = 20 * 1024 * 1024
    private let notificationHandler = LocalNotificationsHelper()

    // swiftlint:disable cyclomatic_complexity
    init(with conversationService: ConversationsService, accountsService: AccountsService, nameService: NameService,
         dataTransferService: DataTransferService, callService: CallsService, locationSharingService: LocationSharingService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.callService = callService
        self.locationSharingService = locationSharingService
        MessagesAdapter.delegate = self
        subscribeFileTransferEvents()
        subscribeCallsEvents()
    }

    func subscribeCallsEvents() {
        self.callService.newMessage.filter({ (event) in
            return  event.eventType == ServiceEventType.newIncomingMessage
        })
            .subscribe(onNext: { [unowned self] event in
                if self.accountsService.boothMode() {
                    return
                }
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                    let messageContent: String = event.getEventInput(ServiceEventInput.content),
                    let peerUri: String = event.getEventInput(ServiceEventInput.peerUri)
                    else {return}
                self.handleNewMessage(from: peerUri,
                                      to: accountId,
                                      messageId: "",
                                      message: messageContent,
                                      peerName: event.getEventInput(ServiceEventInput.name))
            })
            .disposed(by: disposeBag)

        self.callService.newMessage.filter({ (event) in
            return  event.eventType == ServiceEventType.newOutgoingMessage
        })
            .subscribe(onNext: { [unowned self] event in
                if self.accountsService.boothMode() {
                    return
                }
                guard let accountId: String = event.getEventInput(ServiceEventInput.accountId),
                    let messageContent: String = event.getEventInput(ServiceEventInput.content),
                    let peerUri: String = event.getEventInput(ServiceEventInput.peerUri),
                    let accountURi: String = event.getEventInput(ServiceEventInput.accountUri)
                    else {return}
                let message = self.conversationService.createMessage(withId: "",
                                                                     withContent: messageContent,
                                                                     byAuthor: accountURi,
                                                                     generated: false,
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
    func subscribeFileTransferEvents() {
        self.dataTransferService
            .sharedResponseStream
            .filter({ (event) in
                return  event.eventType == ServiceEventType.dataTransferCreated ||
                    event.eventType == ServiceEventType.dataTransferChanged
            })
            .subscribe(onNext: { [unowned self] event in
                if self.accountsService.boothMode() {
                    return
                }
                guard   let transferId: UInt64 = event.getEventInput(ServiceEventInput.transferId),
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
                                .getTransferInfo(withId: transferId) else {return}
                            self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: transferInfo.accountId)
                        }).disposed(by: self.disposeBag)
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

    func prepareConversationsForAccount(accountId: String) {
      self.conversationService
        .getConversationsForAccount(accountId: accountId)
        .subscribe()
        .disposed(by: self.disposeBag)
    }

    // MARK: Message Adapter delegate

    func didReceiveMessage(_ message: [String: String], from senderAccount: String,
                           messageId: String,
                           to receiverAccountId: String) {
        if self.accountsService.boothMode() {
            return
        }
        if let content = message[textPlainMIMEType] {
            DispatchQueue.main.async { [unowned self] in
                self.handleNewMessage(from: senderAccount,
                                      to: receiverAccountId,
                                      messageId: messageId,
                                      message: content,
                                      peerName: nil)
            }
        } /*else*/
        if let content = message[geoLocationMIMEType] {
//            DispatchQueue.main.async { [unowned self] in
                self.handleReceivedLocationUpdate(from: senderAccount,
                                                  to: receiverAccountId,
                                                  messageId: messageId,
                                                  locationJSON: content)
            }
//        }
    }

    private func handleReceivedLocationUpdate(from peerUri: String, to accountId: String, messageId: String, locationJSON content: String) {

        guard let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else { return }

        let type = AccountModelHelper.init(withAccount: accountForMessage).isAccountSip() ? URIType.sip : URIType.ring
        guard let peerUri = JamiURI.init(schema: type, infoHach: peerUri, account: accountForMessage).uriString else {return}

        // Tell the location sharing service
        self.locationSharingService.handleReceivedLocationUpdate(from: peerUri, to: accountId, messageId: messageId, locationJSON: content)

        // Handle notification?
    }

    func handleNewMessage(from peerUri: String, to accountId: String, messageId: String, message content: String, peerName: String?) {
        guard let currentAccount = self.accountsService.currentAccount else {
            return
        }
        guard let accountForMessage = self.accountsService.getAccount(fromAccountId: accountId) else {
            return
        }
        if UIApplication.shared.applicationState != .active && AccountModelHelper
            .init(withAccount: accountForMessage).isAccountRing() &&
            accountsService.getCurrentProxyState(accountID: accountId) {
            var data = [String: String]()
            data [NotificationUserInfoKeys.messageContent.rawValue] = content
            data [NotificationUserInfoKeys.participantID.rawValue] = peerUri
            data [NotificationUserInfoKeys.accountID.rawValue] = accountId
            if let name = peerName {
                data [NotificationUserInfoKeys.name.rawValue] = name
                self.notificationHandler.presentMessageNotification(data: data)
            } else {
                // only for jami accounts
                if let hash = JamiURI(schema: URIType.ring,
                                      infoHach: peerUri).hash {
                    searchNameAndPresentNotification(data: data, hash: hash)
                }
            }
        }
        var shouldUpdateConversationsList = false
        if currentAccount.id == accountForMessage.id {
            shouldUpdateConversationsList = true
        }

        let type = AccountModelHelper.init(withAccount: accountForMessage)
            .isAccountSip() ? URIType.sip : URIType.ring
        guard let uriString = JamiURI.init(schema: type,
                                           infoHach: peerUri,
                                           account: accountForMessage).uriString else {return}
        let message = self.conversationService.createMessage(withId: messageId,
                                                             withContent: content,
                                                             byAuthor: uriString,
                                                             generated: false,
                                                             incoming: true)
        self.conversationService.saveMessage(message: message,
                                             toConversationWith: uriString,
                                             toAccountId: accountId,
                                             shouldRefreshConversations: shouldUpdateConversationsList)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func createTransferNotification(info: NSDataTransferInfo) {
        DispatchQueue.main.async { [weak self] in
            if UIApplication.shared.applicationState == .active {
                return
            }
            DispatchQueue.global(qos: .background).async {
                guard let account = self?.accountsService.getAccount(fromAccountId: info.accountId), AccountModelHelper
                    .init(withAccount: account).isAccountRing(),
                    let state = self?.accountsService.getCurrentProxyState(accountID: info.accountId), state  else {
                        return
                }
                var data = [String: String]()
                var message = L10n.Notifications.newFile + " "
                if let name = info.path.split(separator: "/").last {
                    message += name
                } else {
                    message += info.path
                }
                data [NotificationUserInfoKeys.messageContent.rawValue] = message
                data [NotificationUserInfoKeys.participantID.rawValue] = info.peer
                data [NotificationUserInfoKeys.accountID.rawValue] = info.accountId
                if let name = info.displayName {
                    data [NotificationUserInfoKeys.name.rawValue] = name
                    self?.notificationHandler.presentMessageNotification(data: data)
                } else {
                    guard let hash = JamiURI(schema: URIType.ring,
                                             infoHach: info.peer).hash else {return}

                    self?.searchNameAndPresentNotification(data: data, hash: hash)
                }
            }
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
            .subscribe(onNext: { [weak self] lookupNameResponse in
                if let name = lookupNameResponse.name, !name.isEmpty {
                    data [NotificationUserInfoKeys.name.rawValue] = name
                    self?.notificationHandler.presentMessageNotification(data: data)
                } else if let address = lookupNameResponse.address {
                    data [NotificationUserInfoKeys.name.rawValue] = address
                    self?.notificationHandler.presentMessageNotification(data: data)
                }
            }).disposed(by: self.disposeBag)
        self.nameService.lookupAddress(withAccount: accountId, nameserver: "", address: hash)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64, from accountId: String,
                              to uri: String) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else {
            return
        }
        let type = AccountModelHelper
            .init(withAccount: account).isAccountSip() ? URIType.sip : URIType.ring
        guard let stringUri = JamiURI.init(schema: type,
                                           infoHach: uri,
                                           account: account).uriString else {return}
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      fromAccount: account,
                                                      to: stringUri)
    }

    func autoAcceptTransfer(transferInfo: NSDataTransferInfo, transferId: UInt64, accountId: String) {
        if transferInfo.flags != 1 || transferInfo.totalSize > maxSizeForAutoaccept ||
            (transferInfo.lastEvent != .wait_peer_acceptance && transferInfo.lastEvent != .wait_host_acceptance) {
            return
        }
        guard let messageData = self.conversationService.dataTransferMessageMap[transferId] else {return}
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
