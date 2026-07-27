/*
 * Copyright (C) 2024-2026 Savoir-faire Linux Inc.
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

/// Tracks ongoing swarm calls per account (from libjami's
/// `getActiveCalls` / activeCallsChanged), including which the user
/// ignored or accepted. Ignore/accept propagate to sibling accounts
/// that share the conversation so popups don't resurface.
struct ActiveCallsTracker: Sendable {

    /// The account fields the tracker needs — keeps it decoupled from
    /// AccountModel/AccountsService.
    struct AccountRef: Sendable {
        let id: String
        let jamiId: String
        let currentDeviceId: String
    }

    private(set) var trackers: [String: AccountCallTracker] = [:]

    mutating func updateActiveCalls(conversationId: String,
                                    calls: [[String: String]],
                                    account: AccountRef) {
        let parsed: [ActiveCall] = calls.compactMap { dict in
            guard let id = dict["id"], let uri = dict["uri"], let device = dict["device"] else {
                return nil
            }
            let isLocal = uri == account.jamiId && device == account.currentDeviceId
            return ActiveCall(id: id, uri: uri, device: device,
                              conversationId: conversationId,
                              accountId: account.id,
                              isFromLocalDevice: isLocal)
        }
        var tracker = trackers[account.id] ?? AccountCallTracker()
        tracker.setCalls(for: conversationId, to: parsed)
        trackers[account.id] = tracker
    }

    /// Ignores on the origin account first (its tracker may be missing),
    /// then propagates to siblings holding the same remote call.
    mutating func ignoreCall(_ call: ActiveCall) {
        var originTracker = trackers[call.accountId] ?? AccountCallTracker()
        originTracker.ignoreCall(call)
        trackers[call.accountId] = originTracker

        applyToSiblings(of: call) { tracker, ownCall in
            tracker.ignoreCall(ownCall)
        }
    }

    mutating func acceptCall(uri: String) {
        guard let parsed = ActiveCall(uri) else { return }
        applyToAllTrackersHolding(matching: parsed) { tracker, ownCall in
            tracker.acceptCall(ownCall)
        }
    }

    mutating func activeCallHungUp(uri: String) {
        guard let parsed = ActiveCall(uri) else { return }
        applyToAllTrackersHolding(matching: parsed) { tracker, ownCall in
            tracker.removeAcceptedCall(ownCall)
        }
    }

    func activeCall(conversationId: String, accountId: String) -> ActiveCall? {
        return trackers[accountId]?.calls(for: conversationId).first
    }

    func hasRemoteActiveCalls() -> Bool {
        return trackers.values.contains { tracker in
            !tracker.allConversationIds
                .flatMap { tracker.notIgnoredCalls(for: $0) }
                .filter { !$0.isFromLocalDevice }
                .isEmpty
        }
    }

    func hasUnansweredRemoteCalls() -> Bool {
        return trackers.values.contains {
            !$0.incomingNotAcceptedNotIgnoredCalls().isEmpty
        }
    }

    // MARK: - Private

    private mutating func applyToSiblings(of call: ActiveCall,
                                          _ operation: (inout AccountCallTracker, ActiveCall) -> Void) {
        for (accountId, var tracker) in trackers where accountId != call.accountId {
            guard let match = tracker.calls(for: call.conversationId)
                    .first(where: { $0.remoteIdentity == call.remoteIdentity }) else { continue }
            operation(&tracker, match)
            trackers[accountId] = tracker
        }
    }

    private mutating func applyToAllTrackersHolding(matching call: ActiveCall,
                                                    _ operation: (inout AccountCallTracker, ActiveCall) -> Void) {
        for (accountId, var tracker) in trackers {
            guard let match = tracker.calls(for: call.conversationId)
                    .first(where: { $0.remoteIdentity == call.remoteIdentity }) else { continue }
            operation(&tracker, match)
            trackers[accountId] = tracker
        }
    }
}
