/*
 * Copyright (C) 2025-2026 Savoir-faire Linux Inc.
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

// Identifies a call across accounts. Excludes `accountId` and
// `isFromLocalDevice`, which differ per tracker.
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
}

extension ActiveCall {

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
