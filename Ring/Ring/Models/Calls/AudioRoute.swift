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

/// Audio output routes. Raw values are libjami's device indices —
/// do not renumber.
enum AudioRoute: Int, Sendable {
    case builtinSpeaker = 0
    case bluetooth = 1
    case headphones = 2
    case receiver = 3
}

/// The one place audio-route policy lives.
enum AudioRoutePolicy {

    /// A connected headset always wins (bluetooth over wired); otherwise
    /// the user's speaker/receiver preference applies.
    static func route(bluetoothConnected: Bool, headphonesConnected: Bool,
                      prefersSpeaker: Bool) -> AudioRoute {
        if bluetoothConnected { return .bluetooth }
        if headphonesConnected { return .headphones }
        return prefersSpeaker ? .builtinSpeaker : .receiver
    }

    /// Video calls default to speaker, audio-only calls to the receiver.
    static func defaultSpeakerPreference(callHasVideo: Bool) -> Bool {
        return callHasVideo
    }

    /// Outgoing calls create the audio session with default parameters;
    /// only incoming calls need the route overridden on CallKit
    /// activation.
    static func shouldOverrideOnActivation(direction: CallDirection) -> Bool {
        return direction == .incoming
    }
}
