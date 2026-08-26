/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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

enum RawConversationSignal: @unchecked Sendable {
    case incomingAccountMessage(accountId: String, from: String, messageId: String,
                                payloads: [String: String])
    case messageStatusChanged(accountId: String, conversationId: String, peer: String,
                              messageId: String, status: MessageStatus)
    case activeCallsChanged(accountId: String, conversationId: String, calls: [[String: String]])
    case composingStatusChanged(accountId: String, conversationId: String, from: String, status: Int)
    case swarmLoaded(accountId: String, conversationId: String,
                     messages: [SwarmMessageWrap], requestId: Int)
    case swarmMessageReceived(accountId: String, conversationId: String, message: SwarmMessageWrap)
    case swarmMessageUpdated(accountId: String, conversationId: String, message: SwarmMessageWrap)
    case reactionAdded(accountId: String, conversationId: String, messageId: String,
                       reaction: [String: String])
    case reactionRemoved(accountId: String, conversationId: String, messageId: String,
                         reactionId: String)
    case conversationReady(accountId: String, conversationId: String)
    case conversationRemoved(accountId: String, conversationId: String)
    case conversationDeclined(accountId: String, conversationId: String)
    case conversationMemberEvent(accountId: String, conversationId: String,
                                 memberUri: String, event: Int)
    case conversationProfileUpdated(accountId: String, conversationId: String,
                                    profile: [String: String])
    case conversationPreferencesUpdated(accountId: String, conversationId: String,
                                        preferences: [String: String])
}

final class ConversationEventSource: NSObject {

    private let onSignal: (RawConversationSignal) -> Void

    init(onSignal: @escaping (RawConversationSignal) -> Void) {
        self.onSignal = onSignal
        super.init()
    }

    func attachToAdapter() {
        ConversationsAdapter.messagesDelegate = self
    }
}

extension ConversationEventSource: MessagesAdapterDelegate {

    func didReceiveMessage(_ message: [String: String], from senderAccount: String,
                           messageId: String, to receiverAccountId: String) {
        onSignal(.incomingAccountMessage(accountId: receiverAccountId, from: senderAccount,
                                         messageId: messageId, payloads: message))
    }

    func messageStatusChanged(_ status: MessageStatus, for messageId: String, from accountId: String,
                              to jamiId: String, in conversationId: String) {
        onSignal(.messageStatusChanged(accountId: accountId, conversationId: conversationId,
                                       peer: jamiId, messageId: messageId, status: status))
    }

    func activeCallsChanged(conversationId: String, accountId: String, calls: [[String: String]]) {
        onSignal(.activeCallsChanged(accountId: accountId, conversationId: conversationId,
                                     calls: calls))
    }

    func composingStatusChanged(accountId: String, conversationId: String,
                                from: String, status: Int) {
        onSignal(.composingStatusChanged(accountId: accountId, conversationId: conversationId,
                                         from: from, status: status))
    }

    func conversationLoaded(conversationId: String, accountId: String,
                            messages: [SwarmMessageWrap], requestId: Int) {
        onSignal(.swarmLoaded(accountId: accountId, conversationId: conversationId,
                              messages: messages, requestId: requestId))
    }

    func newInteraction(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        onSignal(.swarmMessageReceived(accountId: accountId, conversationId: conversationId,
                                       message: message))
    }

    func messageUpdated(conversationId: String, accountId: String, message: SwarmMessageWrap) {
        onSignal(.swarmMessageUpdated(accountId: accountId, conversationId: conversationId,
                                      message: message))
    }

    func reactionAdded(conversationId: String, accountId: String,
                       messageId: String, reaction: [String: String]) {
        onSignal(.reactionAdded(accountId: accountId, conversationId: conversationId,
                                messageId: messageId, reaction: reaction))
    }

    func reactionRemoved(conversationId: String, accountId: String,
                         messageId: String, reactionId: String) {
        onSignal(.reactionRemoved(accountId: accountId, conversationId: conversationId,
                                  messageId: messageId, reactionId: reactionId))
    }

    func conversationReady(conversationId: String, accountId: String) {
        onSignal(.conversationReady(accountId: accountId, conversationId: conversationId))
    }

    func conversationRemoved(conversationId: String, accountId: String) {
        onSignal(.conversationRemoved(accountId: accountId, conversationId: conversationId))
    }

    func conversationDeclined(conversationId: String, accountId: String) {
        onSignal(.conversationDeclined(accountId: accountId, conversationId: conversationId))
    }

    func conversationMemberEvent(conversationId: String, accountId: String,
                                 memberUri: String, event: Int) {
        onSignal(.conversationMemberEvent(accountId: accountId, conversationId: conversationId,
                                          memberUri: memberUri, event: event))
    }

    func conversationProfileUpdated(conversationId: String, accountId: String,
                                    profile: [String: String]) {
        onSignal(.conversationProfileUpdated(accountId: accountId, conversationId: conversationId,
                                             profile: profile))
    }

    func conversationPreferencesUpdated(conversationId: String, accountId: String,
                                        preferences: [String: String]) {
        onSignal(.conversationPreferencesUpdated(accountId: accountId,
                                                 conversationId: conversationId,
                                                 preferences: preferences))
    }
}
