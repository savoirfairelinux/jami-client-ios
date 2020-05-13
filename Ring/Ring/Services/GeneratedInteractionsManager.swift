/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
 *  Author: Quentin Muret <quentin.muret@savoirfairelinux.com>
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

class GeneratedInteractionsManager {
    let accountService: AccountsService
    let contactService: ContactsService
    let conversationService: ConversationsService
    let callService: CallsService
    let disposeBag = DisposeBag()

    init(accountService: AccountsService, contactService: ContactsService, conversationService: ConversationsService, callService: CallsService) {
        self.accountService = accountService
        self.contactService = contactService
        self.conversationService = conversationService
        self.callService = callService
        self.subscribeToContactEvents()
        self.subscribeToCallEvents()
    }

    // swiftlint:disable cyclomatic_complexity
    private func subscribeToContactEvents() {
        self.contactService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] contactRequestEvent in
                guard let accountID: String = contactRequestEvent.getEventInput(.accountId) else {
                    return
                }
                guard let contactUri: String = contactRequestEvent.getEventInput(.uri) else {
                    return
                }
                guard let account = self.accountService.getAccount(fromAccountId: accountID) else {
                    return
                }
                let type = AccountModelHelper.init(withAccount: account).isAccountSip() ? URIType.sip : URIType.ring
                guard let uriString = JamiURI.init(schema: type,
                                                   infoHach: contactUri,
                                                   account: account).uriString else {return}
                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount,
                    currentAccount.id == account.id {
                    shouldUpdateConversations = true
                }
                var date = Date()
                if let receivedDate: Date = contactRequestEvent.getEventInput(.date) {
                    date = receivedDate
                }
                if self.accountService.boothMode() {
                    if contactRequestEvent.eventType == ServiceEventType.contactRequestReceived {
                        self.contactService
                            .discard(from: contactUri, withAccountId: accountID)
                            .subscribe()
                            .disposed(by: self.disposeBag)
                    }
                    return
                }
                var message = ""
                switch contactRequestEvent.eventType {
                case ServiceEventType.contactAdded:
                    message = GeneratedMessage.contactAdded.toString()
                case ServiceEventType.contactRequestReceived:
                    message = GeneratedMessage.invitationReceived.toString()
                case ServiceEventType.contactRequestDiscarded:
                    self.removeConversation(accountId: account.id,
                                            contactRingId: uriString,
                                            shouldUpdateConversation: shouldUpdateConversations)
                    return
                default:
                    return
                }
                self.conversationService.generateMessage(messageContent: message,
                                                         contactUri: uriString,
                                                         accountId: account.id,
                                                         date: date,
                                                         interactionType: InteractionType.contact,
                                                         shouldUpdateConversation: shouldUpdateConversations)
            })
            .disposed(by: disposeBag)
    }

    private func removeConversation(accountId: String,
                                    contactRingId: String,
                                    shouldUpdateConversation: Bool) {

        guard let conversation = self.conversationService.findConversation(withUri: contactRingId, withAccountId: accountId) else {
            return
        }
        // remove conversation if it contain only generated messages
        let messagesNotGenerated = conversation.messages.filter({!$0.isGenerated})

        if !messagesNotGenerated.isEmpty {
            return
        }
        self.conversationService.clearHistory(conversation: conversation, keepConversation: false)
    }

    private func subscribeToCallEvents() {
        self.callService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] callEvent in
                if self.accountService.boothMode() {
                    return
                }
                guard let accountID: String = callEvent.getEventInput(.accountId) else {
                    return
                }

                guard let contactUri: String = callEvent.getEventInput(.uri) else {
                    return
                }

                guard let time: Int = callEvent.getEventInput(.callTime) else {
                    return
                }

                guard let callType: Int = callEvent.getEventInput(.callType) else {
                    return
                }

                guard let account = self.accountService.getAccount(fromAccountId: accountID) else {
                    return
                }
                let type = AccountModelHelper
                    .init(withAccount: account).isAccountSip() ? URIType.sip : URIType.ring
                guard let stringUri = JamiURI.init(schema: type,
                                                   infoHach: contactUri,
                                                   account: account).uriString else {return}
                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount,
                    currentAccount.id == account.id {
                    shouldUpdateConversations = true
                }
                let message = callType == CallType.incoming.rawValue
                ? (time > 0) ?  GeneratedMessage.incomingCall.toString() : GeneratedMessage.missedIncomingCall.toString() :
                (time > 0) ?  GeneratedMessage.outgoingCall.toString() :
                    GeneratedMessage.missedOutgoingCall.toString()
                self.conversationService
                    .generateMessage(messageContent: message,
                                     duration: Int64(time),
                                     contactUri: stringUri,
                                     accountId: account.id,
                                     date: Date(),
                                     interactionType: InteractionType.call,
                                     shouldUpdateConversation: shouldUpdateConversations)

            })
            .disposed(by: disposeBag)
    }
}
