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

class ConversationsManager: MessagesAdapterDelegate {

    let conversationService: ConversationsService
    let accountsService: AccountsService
    let disposeBag = DisposeBag()
    fileprivate let textPlainMIMEType = "text/plain"

    init(with conversationService: ConversationsService, accountsService: AccountsService) {
        self.conversationService = conversationService
        self.accountsService = accountsService
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

        print("message received")
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()

            // Configure Notification Content
            notificationContent.title = content


            // Add Trigger
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)

            // Create Notification Request
            let notificationRequest = UNNotificationRequest(identifier: "cocoacasts_local_notification", content: notificationContent, trigger: notificationTrigger)

            // Add Request to User Notification Center
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
                if let error = error {
                    print("Unable to Add Notification Request (\(error), \(error.localizedDescription))")
                }
            }
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
        self.conversationService.messageStatusChanged(status,
                                                      for: messageId,
                                                      from: accountId,
                                                      to: uri)
    }

}
