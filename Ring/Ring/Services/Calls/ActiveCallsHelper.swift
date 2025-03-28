/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import RxRelay

struct ActiveCall: Hashable {
    let id: String
    let uri: String
    let device: String
    let conversationId: String
    let accountId: String
    let isFromLocalDevice: Bool
}

struct AccountCallTracker {
    private var calls: [String: [ActiveCall]] = [:]
    private var ignoredCalls: [String: Set<ActiveCall>] = [:]
    private var answeredCalls: [String: Set<ActiveCall>] = [:]

    var allConversationIds: [String] {
        Array(calls.keys)
    }

    mutating func setCalls(for conversationId: String, to newCalls: [ActiveCall]) {
        calls[conversationId] = newCalls
        if newCalls.isEmpty {
            ignoredCalls[conversationId] = []
        }
    }

    mutating func ignoreCall(_ call: ActiveCall) {
        ignoredCalls[call.conversationId, default: Set()].insert(call)
    }

    mutating func answerCall(_ call: ActiveCall) {
        answeredCalls[call.conversationId, default: Set()].insert(call)
    }

    func calls(for conversationId: String) -> [ActiveCall] {
        calls[conversationId] ?? []
    }

    func ignoredCalls(for conversationId: String) -> Set<ActiveCall> {
        ignoredCalls[conversationId] ?? []
    }

    func answeredCalls(for conversationId: String) -> Set<ActiveCall> {
        answeredCalls[conversationId] ?? []
    }

    func notAnsweredCalls(for conversationId: String) -> [ActiveCall] {
        calls(for: conversationId).filter { !answeredCalls(for: conversationId).contains($0) }
    }

    func notIgnoredCalls(for conversationId: String) -> [ActiveCall] {
        calls(for: conversationId).filter { !ignoredCalls(for: conversationId).contains($0) }
    }

    func incomingUnansweredCalls(for conversationId: String) -> [ActiveCall] {
        return notAnsweredCalls(for: conversationId)
            .filter { !$0.isFromLocalDevice }
    }

    func incomingUnansweredNotIgnoredCalls() -> [ActiveCall] {
        allConversationIds.flatMap { conversationId in
            let answered = answeredCalls(for: conversationId)
            return notIgnoredCalls(for: conversationId)
                .filter { !$0.isFromLocalDevice && !answered.contains($0) }
        }
    }
}

struct CallURI {
    let conversationId: String
    let uri: String
    let device: String
    let id: String

    init?(_ raw: String) {
        guard raw.hasPrefix("rdv:") else { return nil }
        let components = raw.dropFirst(4).split(separator: "/")
        guard components.count == 4 else { return nil }
        self.conversationId = String(components[0])
        self.uri = String(components[1])
        self.device = String(components[2])
        self.id = String(components[3])
    }
}

class ActiveCallsHelper {
    var activeCalls = BehaviorRelay<[String: AccountCallTracker]>(value: [:])

    func updateActiveCalls(conversationId: String, accountId: String, calls: [[String: String]], account: AccountModel) {
        let parsedCalls: [ActiveCall] = calls.compactMap { dict in
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
                accountId: accountId,
                isFromLocalDevice: isLocal
            )
        }

        var calls = activeCalls.value
        var callTracker = calls[accountId] ?? AccountCallTracker()
        callTracker.setCalls(for: conversationId, to: parsedCalls)
        calls[accountId] = callTracker
        activeCalls.accept(calls)
    }

    func ignoreCall(_ call: ActiveCall) {
        var calls = activeCalls.value
        var callTracker = calls[call.accountId] ?? AccountCallTracker()
        callTracker.ignoreCall(call)
        calls[call.accountId] = callTracker
        activeCalls.accept(calls)
    }

    func answerCall(_ callURI: String) {
        guard let parsed = CallURI(callURI),
              let (accountId, call) = findActiveCall(conversationId: parsed.conversationId, callId: parsed.id) else {
            return
        }

        var calls = activeCalls.value
        var callTracker = calls[call.accountId] ?? AccountCallTracker()
        callTracker.answerCall(call)
        calls[accountId] = callTracker
        activeCalls.accept(calls)
    }

    private func findActiveCall(conversationId: String, callId: String) -> (accountId: String, call: ActiveCall)? {
        for (accountId, state) in activeCalls.value {
            if let call = state.calls(for: conversationId).first(where: { $0.id == callId }) {
                return (accountId, call)
            }
        }
        return nil
    }

    func hasRemoteActiveCalls() -> Bool {
        return activeCalls.value.values.contains { state in
            !state.allConversationIds
                .flatMap { state.notIgnoredCalls(for: $0) }
                .filter { !$0.isFromLocalDevice }
                .isEmpty
        }
    }
}
