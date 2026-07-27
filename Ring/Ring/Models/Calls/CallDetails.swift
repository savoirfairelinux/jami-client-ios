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

struct CallDetails: Sendable {
    let peerNumber: String
    let registeredName: String
    let displayName: String
    let state: LibJamiCallState?
    /// nil when the call is not part of a conference (libjami sends "").
    let conferenceId: String?
    let startedAt: Date?
    let accountId: String
    let peerHold: Bool
    let audioMuted: Bool
    let videoMuted: Bool
    let isAudioOnly: Bool
    let audioCodec: String
    let videoCodec: String

    init(_ dict: [String: String]) {
        func value(_ key: CallDetailKey) -> String? { dict[key.rawValue] }

        self.peerNumber = value(.peerNumber) ?? ""
        self.registeredName = value(.registeredName) ?? ""
        self.displayName = value(.displayName) ?? ""
        self.state = value(.callState).flatMap(LibJamiCallState.init(rawValue:))
        let confId = value(.confId) ?? ""
        self.conferenceId = confId.isEmpty ? nil : confId
        self.startedAt = value(.timestampStart)
            .flatMap(TimeInterval.init)
            .flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
        self.accountId = value(.accountId) ?? ""
        self.peerHold = Bool(libJamiString: value(.peerHold)) ?? false
        self.audioMuted = Bool(libJamiString: value(.audioMuted)) ?? false
        self.videoMuted = Bool(libJamiString: value(.videoMuted)) ?? false
        self.isAudioOnly = Bool(libJamiString: value(.audioOnly)) ?? false
        self.audioCodec = value(.audioCodec) ?? ""
        self.videoCodec = value(.videoCodec) ?? ""
    }
}
