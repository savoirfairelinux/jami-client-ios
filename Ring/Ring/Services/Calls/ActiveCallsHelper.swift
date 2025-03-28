//
//  Untitled.swift
//  Ring
//
//  Created by kateryna on 2025-05-17.
//  Copyright © 2025 Savoir-faire Linux. All rights reserved.
//

import RxRelay

struct ActiveCall: Equatable {
    let id: String
    let uri: String
    let device: String
    let conversationId: String
    let accountId: String
    let isfromLocalDevice: Bool

    static func == (lhs: ActiveCall, rhs: ActiveCall) -> Bool {
        return lhs.id == rhs.id &&
        lhs.uri == rhs.uri &&
        lhs.device == rhs.device &&
        lhs.conversationId == rhs.conversationId &&
        lhs.accountId == rhs.accountId
    }
}

struct AccountCalls {
    private var calls: [String: [ActiveCall]] = [:]
    private var ignoredCalls: [String: [ActiveCall]] = [:]
    
    var allConversationIds: [String] {
        return Array(calls.keys)
    }
    
    mutating func updateCalls(for conversationId: String, with calls: [ActiveCall]) {
        self.calls[conversationId] = calls
        if calls.isEmpty {
            self.ignoredCalls[conversationId] = []
        }
    }
    
    mutating func ignoreCall(_ call: ActiveCall) {
        var conversationCalls = ignoredCalls[call.conversationId] ?? []
        conversationCalls.append(call)
        ignoredCalls[call.conversationId] = conversationCalls
    }
    
    func calls(for conversationId: String) -> [ActiveCall] {
        return calls[conversationId] ?? []
    }
    
    func ignoredCalls(for conversationId: String) -> [ActiveCall] {
        return ignoredCalls[conversationId] ?? []
    }

    func notIgnoredCalls(for conversationId: String) -> [ActiveCall] {
        return calls(for: conversationId).filter { !ignoredCalls(for: conversationId).contains($0) }
    }
}

class ActiveCallsHelper {
    var activeCalls = BehaviorRelay<[String: AccountCalls]>(value: [:])

    private func updateAccountCalls(for accountId: String, with update: (inout AccountCalls) -> Void) {
        var currentCalls = self.activeCalls.value
        var accountCalls = currentCalls[accountId] ?? AccountCalls()
        update(&accountCalls)
        currentCalls[accountId] = accountCalls
        self.activeCalls.accept(currentCalls)
    }

    func activeCallsChanged(conversationId: String, accountId: String, calls: [[String: String]], account: AccountModel) {
        let activeCalls = calls.compactMap { call -> ActiveCall? in
            guard let id = call["id"],
                  let uri = call["uri"],
                  let device = call["device"] else { return nil }
            let accountDeviceId: String = account.devices.filter { device in
                device.isCurrent
            }.first?.deviceId ?? ""

            let isLocal = uri == account.jamiId && accountDeviceId == device

            return ActiveCall(id: id,
                            uri: uri,
                            device: device,
                            conversationId: conversationId,
                              accountId: accountId,
                              isfromLocalDevice: isLocal)
        }
        
        updateAccountCalls(for: accountId) { accountCalls in
            accountCalls.updateCalls(for: conversationId, with: activeCalls)
        }
    }

    func ignoreCall(_ call: ActiveCall) {
        updateAccountCalls(for: call.accountId) { accountCalls in
            accountCalls.ignoreCall(call)
        }
    }
}
