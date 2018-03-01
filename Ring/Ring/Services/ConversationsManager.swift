/*
 *  Copyright (C) 2017 Savoir-faire Linux Inc.
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

    private let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"
    private let notificationHandler = LocalNotificationsHelper()

    init(with conversationService: ConversationsService, accountsService: AccountsService, nameService: NameService, dataTransferService: DataTransferService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
        self.nameService = nameService
        self.dataTransferService = dataTransferService
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
                        let transfer = self.dataTransferService.transfer(withTransferId: transferId) else {
                    self.log.error("ConversationsManager: can't find transfer")
                    return
                }
                guard let currentAccount = self.accountsService.currentAccount else {
                    return
                }
                let accountHelper = AccountModelHelper(withAccount: currentAccount)
                switch event.eventType {
                case .dataTransferCreated:
                    self.log.debug("ConversationsManager: dataTransferCreated - id:\(transfer.id)")
                    self.conversationService.generateDataTransferMessage(transfer: transfer,
                                                                         contactRingId: transfer.peerInfoHash,
                                                                         accountRingId: accountHelper.ringId!,
                                                                         accountId: currentAccount.id)
                case .dataTransferChanged:
                    self.log.debug("ConversationsManager: dataTransferChanged - id:\(transfer.id) status:\(stringFromEventCode(with: transfer.status))")
                    var status: MessageStatus = .unknown
                    switch transfer.status {
                    case .closed_by_host, .closed_by_peer:
                        status = MessageStatus.transferCanceled
                    case .invalid, .unsupported, .invalid_pathname, .unjoinable_peer:
                        status = MessageStatus.transferError
                    case .wait_peer_acceptance, .wait_host_acceptance:
                        status = MessageStatus.transferAwaiting
                    case .ongoing:
                        status = MessageStatus.transferOngoing
                    case .finished:
                        status = MessageStatus.transferSuccess
                    case .created:
                        break
                    }
                    self.conversationService.messageStatusChanged(status, for: transfer.id, fromAccount: currentAccount, to: transfer.peerInfoHash)
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
}
