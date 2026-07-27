/*
 * Copyright (C) 2019-2026 Savoir-faire Linux Inc.
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

/// Pure state machine associating CallKit UUIDs with libjami calls.
///
/// A VoIP push reports a CallKit call before libjami knows anything
/// (a *placeholder*); when libjami's incoming call arrives it takes over
/// the placeholder's UUID, and any accept/decline the user performed in
/// between replays.
struct CallKitDirectory: Sendable {

    enum UserDecision: Equatable, Sendable {
        case accepted(withVideo: Bool)
        case declined
    }

    enum DecisionOutcome: Equatable, Sendable {
        /// Decision stored; it will replay when libjami call arrives.
        case storedOnPlaceholder
        /// The UUID maps to a live call — apply the decision now.
        case applyToCall(CallId)
        case unknownCall
    }

    struct Placeholder: Sendable {
        let peerId: String
        let accountId: String
        let displayName: String
        let hasVideo: Bool
        var decision: UserDecision?
    }

    private enum Association: Sendable {
        case placeholder(Placeholder)
        case live(CallId)
    }

    private var associations: [UUID: Association] = [:]

    // MARK: - Placeholders

    /// Registers a placeholder for a pushed call. If the peer already has
    /// one on this account, it is replaced and the old UUID is returned so
    /// the caller can end its CallKit call. A peer calling two accounts on
    /// the same device is two calls, so those placeholders coexist.
    @discardableResult
    mutating func addPlaceholder(uuid: UUID, peerId: String, accountId: String,
                                 displayName: String, hasVideo: Bool) -> UUID? {
        let replaced = placeholderUUID(peerId: peerId, accountId: accountId)
        if let replaced = replaced {
            associations[replaced] = nil
        }
        associations[uuid] = .placeholder(Placeholder(peerId: peerId,
                                                      accountId: accountId,
                                                      displayName: displayName,
                                                      hasVideo: hasVideo,
                                                      decision: nil))
        return replaced
    }

    func placeholderUUID(peerId: String, accountId: String) -> UUID? {
        return associations.first { _, association in
            if case let .placeholder(placeholder) = association {
                return placeholder.peerId == peerId && placeholder.accountId == accountId
            }
            return false
        }?.key
    }

    func placeholder(uuid: UUID) -> Placeholder? {
        if case let .placeholder(placeholder) = associations[uuid] {
            return placeholder
        }
        return nil
    }

    func allPlaceholderUUIDs() -> [UUID] {
        return associations.compactMap { uuid, association in
            if case .placeholder = association { return uuid }
            return nil
        }
    }

    mutating func recordCallAction(uuid: UUID, _ decision: UserDecision) -> DecisionOutcome {
        switch associations[uuid] {
        case .placeholder(var placeholder):
            placeholder.decision = decision
            associations[uuid] = .placeholder(placeholder)
            return .storedOnPlaceholder
        case .live(let callId):
            return .applyToCall(callId)
        case nil:
            return .unknownCall
        }
    }

    // MARK: - Matching

    /// Promotes the peer's placeholder on this account to a live association
    /// with the libjami call, returning the CallKit UUID to reuse and any
    /// decision the user already took.
    mutating func match(peerId: String, accountId: String,
                        callId: CallId) -> (uuid: UUID, pendingDecision: UserDecision?)? {
        guard let uuid = placeholderUUID(peerId: peerId, accountId: accountId),
              case let .placeholder(placeholder) = associations[uuid] else {
            return nil
        }
        associations[uuid] = .live(callId)
        return (uuid, placeholder.decision)
    }

    // MARK: - Live calls

    mutating func attach(uuid: UUID, to callId: CallId) {
        associations[uuid] = .live(callId)
    }

    mutating func remove(uuid: UUID) {
        associations[uuid] = nil
    }

    /// Removes an expired placeholder (libjami never reported the call).
    /// No-op when the association was promoted in the meantime.
    @discardableResult
    mutating func expirePlaceholder(uuid: UUID) -> Bool {
        guard case .placeholder = associations[uuid] else { return false }
        associations[uuid] = nil
        return true
    }

    // MARK: - Lookups

    func isTracked(_ uuid: UUID) -> Bool {
        return associations[uuid] != nil
    }

    func callId(for uuid: UUID) -> CallId? {
        if case let .live(callId) = associations[uuid] {
            return callId
        }
        return nil
    }

    func uuid(for callId: CallId) -> UUID? {
        return associations.first { _, association in
            if case let .live(id) = association {
                return id == callId
            }
            return false
        }?.key
    }

    var isEmpty: Bool {
        return associations.isEmpty
    }
}
