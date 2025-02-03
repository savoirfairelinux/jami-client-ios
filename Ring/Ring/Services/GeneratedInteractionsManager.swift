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

/*
 This class generates interactions for contact and call events. Only for non swarm conversations
 */

class GeneratedInteractionsManager {
    let accountService: AccountsService
    let requestsService: RequestsService
    let conversationService: ConversationsService
    let callService: CallsService
    let disposeBag = DisposeBag()

    init(accountService: AccountsService, requestsService: RequestsService, conversationService: ConversationsService, callService: CallsService) {
        self.accountService = accountService
        self.requestsService = requestsService
        self.conversationService = conversationService
        self.callService = callService
        self.subscribeToContactEvents()
        self.subscribeToCallEvents()
    }

    // swiftlint:disable cyclomatic_complexity
    private func subscribeToContactEvents() {
        self.requestsService
            .sharedResponseStream
            .subscribe(onNext: { [weak self] contactRequestEvent in
                guard let self = self else { return }
                if self.accountService.boothMode() {
                    return
                }
                guard let accountID: String = contactRequestEvent.getEventInput(.accountId) else {
                    return
                }
                guard let jamiId: String = contactRequestEvent.getEventInput(.uri) else {
                    return
                }
                guard let account = self.accountService.getAccount(fromAccountId: accountID) else {
                    return
                }

                let type = AccountModelHelper.init(withAccount: account).isAccountSip() ? URIType.sip : URIType.ring
                guard let uriString = JamiURI.init(schema: type,
                                                   infoHash: jamiId,
                                                   account: account).uriString else { return }
                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount,
                   currentAccount.id == account.id {
                    shouldUpdateConversations = true
                }
                var date = Date()
                if let receivedDate: Date = contactRequestEvent.getEventInput(.date) {
                    date = receivedDate
                }
                var message = ""
                switch contactRequestEvent.eventType {
                case ServiceEventType.contactRequestReceived:
                    message = GeneratedMessage.invitationReceived.toString()
                case ServiceEventType.contactRequestDiscarded:
                    self.removeConversation(accountId: account.id,
                                            contactRingId: uriString,
                                            shouldUpdateConversation: shouldUpdateConversations)
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

        guard let conversation = self.conversationService.getConversationForParticipant(jamiId: contactRingId, accountId: accountId) else {
            return
        }
        // remove conversation if it contain only contact messages
        let messages = conversation.messages.filter({ !$0.type.isContact })

        if !messages.isEmpty {
            return
        }
        self.conversationService.removeConversationFromDB(conversation: conversation, keepConversation: false)
    }

    private func subscribeToCallEvents() {
        self.callService
            .sharedResponseStream
            .subscribe(onNext: { [weak self] callEvent in
                guard let self = self else { return }
                if self.accountService.boothMode() {
                    return
                }
                guard let accountID: String = callEvent.getEventInput(.accountId) else {
                    return
                }

                guard let jamiId: String = callEvent.getEventInput(.peerUri) else {
                    return
                }

                guard let account = self.accountService.getAccount(fromAccountId: accountID) else { return }

                if account.type != .sip {
                    // we should generate messages only for non swarm conversations
                    guard let conversation = self.conversationService.getConversationForParticipant(jamiId: jamiId.filterOutHost(), accountId: accountID), !conversation.isSwarm() else { return }
                } else {
                    // ensure sip conversation exists
                    guard let uri = JamiURI.init(schema: .sip, infoHash: jamiId, account: account).uriString else {
                        return
                    }
                    self.conversationService.createSipConversation(uri: uri, accountId: accountID)
                }

                guard let time: Int = callEvent.getEventInput(.callTime) else {
                    return
                }

                guard let callType: Int = callEvent.getEventInput(.callType) else {
                    return
                }

                let type = AccountModelHelper
                    .init(withAccount: account).isAccountSip() ? URIType.sip : URIType.ring
                guard let stringUri = JamiURI.init(schema: type,
                                                   infoHash: jamiId,
                                                   account: account).uriString else { return }
                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount,
                   currentAccount.id == account.id {
                    shouldUpdateConversations = true
                }
                let message = callType == CallType.incoming.rawValue
                    ? (time > 0) ? GeneratedMessage.incomingCall.toString() : GeneratedMessage.missedIncomingCall.toString() :
                    (time > 0) ? GeneratedMessage.outgoingCall.toString() :
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
