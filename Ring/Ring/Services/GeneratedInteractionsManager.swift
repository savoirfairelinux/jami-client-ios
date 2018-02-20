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

    private func subscribeToContactEvents() {
        self.contactService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] contactRequestEvent in

                guard let accountID: String = contactRequestEvent.getEventInput(.accountId) else {
                    return
                }

                guard let contactRingId: String = contactRequestEvent.getEventInput(.uri) else {
                    return
                }

                guard let account = self.accountService.getAccount(fromAccountId: accountID) else {
                    return
                }

                guard let ringId = AccountModelHelper(withAccount: account).ringId else {
                    return
                }

                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount {
                    if let currentrRingId = AccountModelHelper(withAccount: currentAccount).ringId, currentrRingId == ringId {
                        shouldUpdateConversations = true
                    }
                }

                var type: GeneratedMessageType

                var date = Date()
                if let receivedDate: Date = contactRequestEvent.getEventInput(.date) {
                    date = receivedDate
                }

                switch contactRequestEvent.eventType {

                case ServiceEventType.contactAdded:

                    guard let contactConfirmed: Bool = contactRequestEvent.getEventInput(.state) else {
                        return
                    }

                    if !contactConfirmed {
                        return
                    }
                    type = GeneratedMessageType.contactRequestAccepted
                case ServiceEventType.contactRequestSended:
                    type = GeneratedMessageType.sendContactRequest
                case ServiceEventType.contactRequestReceived:
                    type = GeneratedMessageType.receivedContactRequest
                case ServiceEventType.contactRequestDiscarded:
                    self.removeConversation(accountId: account.id,
                                            accountRingId: ringId,
                                            contactRingId: contactRingId,
                                            shouldUpdateConversation: shouldUpdateConversations)
                    return
                default:
                    return
                }

                self.conversationService.generateMessage(messageContent: type.rawValue,
                                                         contactRingId: contactRingId,
                                                         accountRingId: ringId,
                                                         accountId: account.id,
                                                         date: date,
                                                         interactionType: InteractionType.contact,
                                                         shouldUpdateConversation: shouldUpdateConversations)

            })
            .disposed(by: disposeBag)
    }

    private func removeConversation(accountId: String, accountRingId: String,
                                    contactRingId: String,
                                    shouldUpdateConversation: Bool) {

        guard let conversation = self.conversationService.findConversation(withRingId: contactRingId, withAccountId: accountId) else {
            return
        }
        // remove conversation if it contain only generated messages
        let messagesNotGenerated = conversation.messages.filter({!$0.isGenerated})

        if !messagesNotGenerated.isEmpty {
            return
        }
        self.conversationService.deleteConversation(conversation: conversation)
    }

    private func subscribeToCallEvents() {
        self.callService
            .sharedResponseStream
            .subscribe(onNext: { [unowned self] callEvent in

                guard let accountID: String = callEvent.getEventInput(.accountId) else {
                    return
                }

                guard let contactRingId: String = callEvent.getEventInput(.uri) else {
                    return
                }

                guard let time: Double = callEvent.getEventInput(.callTime) else {
                    return
                }

                guard let callType: Int = callEvent.getEventInput(.callType) else {
                    return
                }

                guard let account = self.accountService.getAccount(fromAccountId: accountID) else {
                    return
                }

                guard let ringId = AccountModelHelper(withAccount: account).ringId else {
                    return
                }

                var shouldUpdateConversations = false
                if let currentAccount = self.accountService.currentAccount {
                    if let currentrRingId = AccountModelHelper(withAccount: currentAccount).ringId, currentrRingId == ringId {
                        shouldUpdateConversations = true
                    }
                }
                var message = ""

                if time > 0 {
                    let timeString = self.convertSecondsToString(seconds: time)
                    if callType == CallType.incoming.rawValue {
                        message = GeneratedMessageType.incomingCall.rawValue + " - " + timeString
                    } else if callType == CallType.outgoing.rawValue {
                        message = GeneratedMessageType.outgoingCall.rawValue + " - " + timeString
                    }
                } else {
                    if callType == CallType.incoming.rawValue {
                        message = GeneratedMessageType.missedIncomingCall.rawValue
                    } else if callType == CallType.outgoing.rawValue {
                        message = GeneratedMessageType.missedOutgoingCall.rawValue
                    }
                }
                self.conversationService.generateMessage(messageContent: message,
                                                         contactRingId: contactRingId,
                                                         accountRingId: ringId,
                                                         accountId: account.id,
                                                         date: Date(),
                                                         interactionType: InteractionType.call,
                                                         shouldUpdateConversation: shouldUpdateConversations)

            })
            .disposed(by: disposeBag)
    }

    func convertSecondsToString(seconds: Double) -> String {
        var string = ""
        var reminderSeconds = seconds
        let hours = Int(seconds / 3600)
        if hours > 0 {
            reminderSeconds = seconds.truncatingRemainder(dividingBy: 3600)
            string += String(format: "%02d", hours) + ":"

        }
        let min = Int(reminderSeconds / 60)
        let sec = reminderSeconds.truncatingRemainder(dividingBy: 60)
        string += String(format: "%02d:%02d", min, Int(sec))
        print("string", string)
        return string
    }
}
