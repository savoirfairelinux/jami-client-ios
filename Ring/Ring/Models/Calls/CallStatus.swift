/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

enum HoldSide: Sendable, Equatable {
    case local, peer, both

    var includesLocal: Bool { self != .peer }
    var includesPeer: Bool { self != .local }
}

enum TerminationReason: Sendable, Equatable {
    case hungUp, busy, peerBusy, failure, inactive, over
    case endedLocally
}

enum CallIntent: Sendable {
    case accept, refuse, hangUp, hold, resume, changeMedia
}

/// Lifecycle status of a call.
enum CallStatus: Sendable, Equatable {
    case incoming
    case connecting
    case ringing
    case current
    case held(side: HoldSide)
    case terminated(TerminationReason)

    init(libJami: LibJamiCallState) {
        switch libJami {
        case .incoming: self = .incoming
        case .connecting: self = .connecting
        case .ringing: self = .ringing
        case .current: self = .current
        case .hold: self = .held(side: .local)
        case .hungUp: self = .terminated(.hungUp)
        case .busy: self = .terminated(.busy)
        case .peerBusy: self = .terminated(.peerBusy)
        case .failure: self = .terminated(.failure)
        case .inactive: self = .terminated(.inactive)
        case .over: self = .terminated(.over)
        }
    }

    var isTerminal: Bool {
        if case .terminated = self { return true }
        return false
    }

    var isOngoing: Bool {
        switch self {
        case .current, .held:
            return true
        default:
            return false
        }
    }

    /// Whether libjami (or the store) may move a call from `self` to `new`.
    /// Same-status is a legal no-op; terminated is absorbing; the call may
    /// die from any live state.
    func canTransition(to new: CallStatus) -> Bool {
        if isTerminal { return false }
        if new == self { return true }
        if case .terminated = new { return true }
        switch (self, new) {
        case (.incoming, .connecting), (.incoming, .ringing), (.incoming, .current):
            return true
        case (.connecting, .ringing), (.connecting, .current):
            return true
        case (.ringing, .current):
            return true
        case (.current, .held):
            return true
        case (.held, .current), (.held, .held):
            return true
        default:
            return false
        }
    }

    func allows(_ intent: CallIntent) -> Bool {
        switch intent {
        case .accept, .refuse:
            return self == .incoming
        case .hangUp:
            return !isTerminal
        case .hold:
            return self == .current
        case .resume:
            if case .held(let side) = self { return side.includesLocal }
            return false
        case .changeMedia:
            return isOngoing
        }
    }
}
