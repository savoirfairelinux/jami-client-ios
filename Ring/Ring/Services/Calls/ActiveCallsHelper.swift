/*
 * Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import RxRelay

// Fields that identify a call on the wire. Excludes `accountId` and
// `isFromLocalDevice`: those are local bookkeeping that differs across
// trackers mirroring the same remote call.
struct RemoteCallIdentity: Hashable {
    let conversationId: String
    let id: String
    let uri: String
    let device: String
}

struct ActiveCall: Hashable {
    let id: String
    let uri: String
    let device: String
    let conversationId: String
    let accountId: String
    let isFromLocalDevice: Bool

    var remoteIdentity: RemoteCallIdentity {
        RemoteCallIdentity(conversationId: conversationId, id: id, uri: uri, device: device)
    }

    func constructURI() -> String {
        return "rdv:" + self.conversationId + "/" + self.uri + "/" + self.device + "/" + self.id
    }

    init(id: String, uri: String, device: String, conversationId: String, accountId: String,
         isFromLocalDevice: Bool) {
        self.id = id
        self.uri = uri
        self.device = device
        self.conversationId = conversationId
        self.accountId = accountId
        self.isFromLocalDevice = isFromLocalDevice
    }

    init?(_ raw: String) {
        let components = raw.replacingOccurrences(of: "rdv:", with: "").split(separator: "/")
        guard components.count == 4 else { return nil }
        self.conversationId = String(components[0])
        self.uri = String(components[1])
        self.device = String(components[2])
        self.id = String(components[3])
        self.isFromLocalDevice = false
        self.accountId = ""
    }
}

struct AccountCallTracker {
    private var calls: [String: [ActiveCall]] = [:]
    private var ignoredCalls: [String: Set<ActiveCall>] = [:]
    private var acceptedCalls: [String: Set<ActiveCall>] = [:]

    var allConversationIds: [String] {
        Array(calls.keys)
    }

    mutating func setCalls(for conversationId: String, to newCalls: [ActiveCall]) {
        calls[conversationId] = newCalls
        if newCalls.isEmpty {
            ignoredCalls[conversationId] = []
            acceptedCalls[conversationId] = []
        }
    }

    mutating func ignoreCall(_ call: ActiveCall) {
        ignoredCalls[call.conversationId, default: Set()].insert(call)
    }

    mutating func acceptCall(_ call: ActiveCall) {
        acceptedCalls[call.conversationId, default: Set()].insert(call)
    }

    func calls(for conversationId: String) -> [ActiveCall] {
        calls[conversationId] ?? []
    }

    func ignoredCalls(for conversationId: String) -> Set<ActiveCall> {
        ignoredCalls[conversationId] ?? []
    }

    func acceptedCalls(for conversationId: String) -> Set<ActiveCall> {
        acceptedCalls[conversationId] ?? []
    }

    mutating func removeAcceptedCall(_ call: ActiveCall) {
        acceptedCalls[call.conversationId]?.remove(call)
    }

    func notAcceptedCalls(for conversationId: String) -> [ActiveCall] {
        calls(for: conversationId).filter { !acceptedCalls(for: conversationId).contains($0) }
    }

    func notIgnoredCalls(for conversationId: String) -> [ActiveCall] {
        calls(for: conversationId).filter { !ignoredCalls(for: conversationId).contains($0) }
    }

    func incomingNotAcceptedCalls(for conversationId: String) -> [ActiveCall] {
        return notAcceptedCalls(for: conversationId)
            .filter { !$0.isFromLocalDevice }
    }

    func incomingNotAcceptedNotIgnoredCalls() -> [ActiveCall] {
        allConversationIds.flatMap { conversationId in
            let accepted = acceptedCalls(for: conversationId)
            return notIgnoredCalls(for: conversationId)
                .filter { !$0.isFromLocalDevice && !accepted.contains($0) }
        }
    }
}

class ActiveCallsHelper {
    var activeCalls = BehaviorRelay<[String: AccountCallTracker]>(value: [:])

    func updateActiveCalls(conversationId: String, calls: [[String: String]], account: AccountModel) {
        let parsedCalls: [ActiveCall] = calls.compactMap { dict -> ActiveCall? in
            guard let id = dict["id"], let uri = dict["uri"], let device = dict["device"] else {
                return nil
            }

            let currentDeviceId = account.devices.first(where: \.isCurrent)?.deviceId ?? ""
            let isLocal = uri == account.jamiId && device == currentDeviceId

            return ActiveCall(
                id: id,
                uri: uri,
                device: device,
                conversationId: conversationId,
                accountId: account.id,
                isFromLocalDevice: isLocal
            )
        }

        var calls = activeCalls.value
        var callTracker = calls[account.id] ?? AccountCallTracker()
        callTracker.setCalls(for: conversationId, to: parsedCalls)
        calls[account.id] = callTracker
        activeCalls.accept(calls)
    }

    func ignoreCall(_ call: ActiveCall) {
        // Always ignore on the origin account, even when its tracker is not
        // yet in `activeCalls`. Then fan out to every sibling tracker that
        // mirrors the same remote call, otherwise the popup re-surfaces from
        // the sibling on the next emission.
        var calls = activeCalls.value
        var originTracker = calls[call.accountId] ?? AccountCallTracker()
        originTracker.ignoreCall(call)
        calls[call.accountId] = originTracker

        for (accountId, var tracker) in calls where accountId != call.accountId {
            guard let match = tracker.calls(for: call.conversationId).first(where: { $0.remoteIdentity == call.remoteIdentity }) else { continue }
            tracker.ignoreCall(match)
            calls[accountId] = tracker
        }
        activeCalls.accept(calls)
    }

    func acceptCall(_ callURI: String) {
        guard let parsed = ActiveCall.init(callURI) else { return }
        applyToAllTrackersHolding(matching: parsed) { tracker, ownCall in
            tracker.acceptCall(ownCall)
        }
    }

    func getActiveCall(conversationId: String, accountId: String) -> ActiveCall? {
        return activeCalls.value[accountId]?.calls(for: conversationId).first
    }

    func hasRemoteActiveCalls() -> Bool {
        return activeCalls.value.values.contains { state in
            !state.allConversationIds
                .flatMap { state.notIgnoredCalls(for: $0) }
                .filter { !$0.isFromLocalDevice }
                .isEmpty
        }
    }

    func activeCallHangedUp(callURI: String) {
        guard let parsed = ActiveCall.init(callURI) else { return }

        // Removes the call from accepted calls list to allow rejoining,
        // and adds it to ignored calls to prevent call alerts from showing.
        applyToAllTrackersHolding(matching: parsed) { tracker, ownCall in
            tracker.ignoreCall(ownCall)
            tracker.removeAcceptedCall(ownCall)
        }
    }

    // Applies `mutation` to every tracker holding a call that matches
    // `template` on the remote identity. The tracker-local `ActiveCall`
    // instance must be passed through: accepted/ignored sets hash the full
    // struct (including `accountId`), so a stranger instance would not
    // deduplicate.
    private func applyToAllTrackersHolding(matching template: ActiveCall,
                                           mutation: (inout AccountCallTracker, ActiveCall) -> Void) {
        var calls = activeCalls.value
        var changed = false
        for (accountId, var tracker) in calls {
            let matches = tracker.calls(for: template.conversationId).filter { $0.remoteIdentity == template.remoteIdentity }
            guard !matches.isEmpty else { continue }
            for ownCall in matches {
                mutation(&tracker, ownCall)
            }
            calls[accountId] = tracker
            changed = true
        }
        if changed {
            activeCalls.accept(calls)
        }
    }
}
