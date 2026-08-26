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

struct ConversationSnapshot: Sendable {
    let info: [String: String]
    let members: [[String: String]]
    let preferences: [String: String]
}

struct ConversationMemberUpdate: Sendable {
    let memberUri: String
    let event: Int
    let members: [[String: String]]
}

enum ConversationEvent: @unchecked Sendable {
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
    case conversationReady(accountId: String, conversationId: String,
                           snapshot: ConversationSnapshot)
    case conversationRemoved(accountId: String, conversationId: String)
    case conversationDeclined(accountId: String, conversationId: String)
    case conversationMemberEvent(accountId: String, conversationId: String,
                                 update: ConversationMemberUpdate)
    case conversationProfileUpdated(accountId: String, conversationId: String,
                                    profile: [String: String])
    case conversationPreferencesUpdated(accountId: String, conversationId: String,
                                        preferences: [String: String])
}

/// Hops libjami conversation signals off the daemon thread before any read-back.
///
/// `handle(_:)` is called on a daemon thread and returns immediately
final class ConversationEventResolver: @unchecked Sendable {

    private let api: LibJamiConversationAPI
    private let queue: DispatchQueue
    private var onEvent: ((ConversationEvent) -> Void)?

    init(api: LibJamiConversationAPI,
         queue: DispatchQueue = DispatchQueue(
            label: "com.savoirfairelinux.jami.conversations.signals", qos: .userInitiated)) {
        self.api = api
        self.queue = queue
    }

    /// Must be called before the source is attached to the adapter.
    func setEventHandler(_ handler: @escaping (ConversationEvent) -> Void) {
        queue.sync { self.onEvent = handler }
    }

    func handle(_ signal: RawConversationSignal) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let event = self.resolve(signal)
            self.onEvent?(event)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func resolve(_ signal: RawConversationSignal) -> ConversationEvent {
        switch signal {

        case let .conversationReady(accountId, conversationId):
            let snapshot = ConversationSnapshot(
                info: api.info(accountId: accountId, conversationId: conversationId),
                members: api.members(accountId: accountId, conversationId: conversationId),
                preferences: api.preferences(accountId: accountId, conversationId: conversationId))
            return .conversationReady(accountId: accountId, conversationId: conversationId,
                                      snapshot: snapshot)

        case let .conversationMemberEvent(accountId, conversationId, memberUri, event):
            let update = ConversationMemberUpdate(
                memberUri: memberUri,
                event: event,
                members: api.members(accountId: accountId, conversationId: conversationId))
            return .conversationMemberEvent(accountId: accountId, conversationId: conversationId,
                                            update: update)

        case let .incomingAccountMessage(accountId, from, messageId, payloads):
            return .incomingAccountMessage(accountId: accountId, from: from,
                                           messageId: messageId, payloads: payloads)

        case let .messageStatusChanged(accountId, conversationId, peer, messageId, status):
            return .messageStatusChanged(accountId: accountId, conversationId: conversationId,
                                         peer: peer, messageId: messageId, status: status)

        case let .activeCallsChanged(accountId, conversationId, calls):
            return .activeCallsChanged(accountId: accountId, conversationId: conversationId,
                                       calls: calls)

        case let .composingStatusChanged(accountId, conversationId, from, status):
            return .composingStatusChanged(accountId: accountId, conversationId: conversationId,
                                           from: from, status: status)

        case let .swarmLoaded(accountId, conversationId, messages, requestId):
            return .swarmLoaded(accountId: accountId, conversationId: conversationId,
                                messages: messages, requestId: requestId)

        case let .swarmMessageReceived(accountId, conversationId, message):
            return .swarmMessageReceived(accountId: accountId, conversationId: conversationId,
                                         message: message)

        case let .swarmMessageUpdated(accountId, conversationId, message):
            return .swarmMessageUpdated(accountId: accountId, conversationId: conversationId,
                                        message: message)

        case let .reactionAdded(accountId, conversationId, messageId, reaction):
            return .reactionAdded(accountId: accountId, conversationId: conversationId,
                                  messageId: messageId, reaction: reaction)

        case let .reactionRemoved(accountId, conversationId, messageId, reactionId):
            return .reactionRemoved(accountId: accountId, conversationId: conversationId,
                                    messageId: messageId, reactionId: reactionId)

        case let .conversationRemoved(accountId, conversationId):
            return .conversationRemoved(accountId: accountId, conversationId: conversationId)

        case let .conversationDeclined(accountId, conversationId):
            return .conversationDeclined(accountId: accountId, conversationId: conversationId)

        case let .conversationProfileUpdated(accountId, conversationId, profile):
            return .conversationProfileUpdated(accountId: accountId, conversationId: conversationId,
                                               profile: profile)

        case let .conversationPreferencesUpdated(accountId, conversationId, preferences):
            return .conversationPreferencesUpdated(accountId: accountId,
                                                   conversationId: conversationId,
                                                   preferences: preferences)
        }
    }
}
