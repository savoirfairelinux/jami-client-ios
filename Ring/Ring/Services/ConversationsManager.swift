/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import Foundation
import RxSwift
import SwiftyBeaver

class ConversationsManager: MessagesAdapterDelegate {

    let log = SwiftyBeaver.self

    let conversationService: ConversationsService
    let accountsService: AccountsService
    let nameService: NameService
    let dataTransferService: DataTransferService
    let contactService: ContactsService

    private let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"
    fileprivate let maxSizeForAutoaccept = 20 * 1024 * 1024
    private let notificationHandler = LocalNotificationsHelper()

    // swiftlint:disable cyclomatic_complexity
    init(with conversationService: ConversationsService,
         accountsService: AccountsService,
         nameService: NameService,
         dataTransferService: DataTransferService,
         contactService: ContactsService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
        self.contactService = contactService
        MessagesAdapter.delegate = self

        self.accountsService
            .sharedResponseStream
            .filter({ (event) in
                return event.eventType == ServiceEventType.registrationStateChanged &&
                    event.getEventInput(ServiceEventInput.registrationState) == Registered
            })
            .subscribe(onNext: { [unowned self] _ in
                if let currentAccount = self.accountsService.currentAccount {
                    if let ringID = AccountModelHelper(withAccount: currentAccount).ringId {
                        self.conversationService
                            .getConversationsForAccount(accountId: currentAccount.id, accountUri: ringID)
                            .subscribe()
                            .disposed(by: self.disposeBag)
                    }
                }
            })
            .disposed(by: disposeBag)

        self.dataTransferService
            .sharedResponseStream
            .filter({ (event) in
                return  event.eventType == ServiceEventType.dataTransferCreated ||
                        event.eventType == ServiceEventType.dataTransferChanged
            })
            .subscribe(onNext: { [unowned self] event in
                guard   let transferId: UInt64 = event.getEventInput(ServiceEventInput.transferId),
                        let transferInfo = self.dataTransferService.getTransferInfo(withId: transferId) else {
                    self.log.error("ConversationsManager: can't find transferInfo")
                    return
                }
                guard let currentAccount = self.accountsService.currentAccount else {
                    return
                }
                let accountHelper = AccountModelHelper(withAccount: currentAccount)
                switch event.eventType {
                case .dataTransferCreated:
                    if self.contactService.contact(withRingId: transferInfo.peer) == nil {
                        self.contactService.incomingTrustRequestReceived(from: transferInfo.peer, to: accountHelper.ringId!, withPayload: Data(), receivedDate: Date())
                    }
                    let photoIdentifier: String? = event.getEventInput(.localPhotolID)
                    self.log.debug("ConversationsManager: dataTransferCreated - id:\(transferId)")
                    self.conversationService
                        .generateDataTransferMessage(transferId: transferId,
                                                     transferInfo: transferInfo,
                                                     accountRingId: accountHelper.ringId!,
                                                     accountId: currentAccount.id,
                                                     photoIdentifier: photoIdentifier)
                        .subscribe(onCompleted: {
                            guard let transferInfo = self.dataTransferService
                                .getTransferInfo(withId: transferId) else {return}
                            self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: currentAccount.id)
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
                        self.autoAcceptTransfer(transferInfo: transferInfo, transferId: transferId, accountId: currentAccount.id)
                    case .ongoing:
                        status = DataTransferStatus.ongoing
                    case .finished:
                        status = DataTransferStatus.success
                        self.conversationService.dataTransferMessageMap.removeValue(forKey: transferId)
                    case .created:
                        break
                    }
                    self.conversationService.transferStatusChanged(status, for: transferId, fromAccount: currentAccount, to: transferInfo.peer)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    func prepareConversationsForAccount(accountId: String, accountUri: String) {
      self.conversationService
        .getConversationsForAccount(accountId: accountId, accountUri: accountUri)
        .subscribe()
        .disposed(by: self.disposeBag)
    }

    // MARK: Message Adapter delegate

    func didReceiveMessage(_ message: [String: String], from senderAccount: String,
                           to receiverAccountId: String) {
        guard let content = message[textPlainMIMEType] else {
            return
        }

        if UIApplication.shared.applicationState != .active {
            var data = [String: String]()
            data [NotificationUserInfoKeys.messageContent.rawValue] = content
            data [NotificationUserInfoKeys.participantID.rawValue] = senderAccount
            self.nameService.usernameLookupStatus.single()
                .filter({ lookupNameResponse in
                    return lookupNameResponse.address != nil &&
                        lookupNameResponse.address == senderAccount
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

            self.nameService.lookupAddress(withAccount: "", nameserver: "", address: senderAccount)
        }

        guard let currentAccount = self.accountsService.currentAccount else {
            return
        }

        guard let currentAccountUri = AccountModelHelper(withAccount: currentAccount).ringId else {
            return
        }

        guard let accountForMessage = self.accountsService.getAccount(fromAccountId: receiverAccountId) else {
            return
        }

        guard let messageAccountUri = AccountModelHelper(withAccount: accountForMessage).ringId else {
            return
        }

        var shouldUpdateConversationsList = false
        if currentAccountUri == messageAccountUri {
            shouldUpdateConversationsList = true
        }

        if self.contactService.contact(withRingId: senderAccount) == nil {
            self.contactService.incomingTrustRequestReceived(from: senderAccount, to: messageAccountUri, withPayload: Data(), receivedDate: Date())
        }
        let message = self.conversationService.createMessage(withId: "",
                                                             withContent: content,
                                                             byAuthor: senderAccount,
                                                             generated: false,
                                                             incoming: true)
        self.conversationService.saveMessage(message: message,
                                             toConversationWith: senderAccount,
                                             toAccountId: receiverAccountId,
                                             toAccountUri: messageAccountUri,
                                             shouldRefreshConversations: shouldUpdateConversationsList)
            .subscribe()
            .disposed(by: self.disposeBag)
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: UInt64, from accountId: String,
                              to uri: String) {
        guard let account = self.accountsService.getAccount(fromAccountId: accountId) else {
            return
        }
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      fromAccount: account,
                                                      to: uri)
    }

    func autoAcceptTransfer(transferInfo: NSDataTransferInfo, transferId: UInt64, accountId: String) {
        if transferInfo.flags != 1 || transferInfo.totalSize > maxSizeForAutoaccept ||
            (transferInfo.lastEvent != .wait_peer_acceptance && transferInfo.lastEvent != .wait_host_acceptance) {
            return
        }
        guard let messageData = self.conversationService.dataTransferMessageMap[transferId] else {return}
        if !(self.dataTransferService.isTransferImage(withId: transferId, accountID: accountId,
                                                      conversationID: String(messageData.conversationID)) ?? false) {
            return
        }
        var filename = ""
        if self.dataTransferService.acceptTransfer(withId: transferId, interactionID: messageData.messageID,
                                                   fileName: &filename, accountID: accountId,
                                                   conversationID: String(messageData.conversationID)) != .success {
            self.log.debug("ConversationsManager: accept transfer failed")
        }
    }
}
