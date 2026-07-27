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

struct ConferenceParticipantInfo: Hashable, Identifiable, Sendable {
    let uri: String
    let device: String
    let sinkId: SinkId
    let isActive: Bool
    let frame: CGRect
    let isVideoMuted: Bool
    let isAudioLocallyMuted: Bool
    let isAudioModeratorMuted: Bool
    let isModerator: Bool
    let isHandRaised: Bool
    let hasVoiceActivity: Bool
    let isRecording: Bool

    var id: String { Self.id(uri: uri, device: device) }

    static func id(uri: String, device: String) -> String { uri + "|" + device }

    func isLocalParticipant(localJamiId: String, isHostedLocally: Bool) -> Bool {
        if uri.isEmpty { return isHostedLocally }
        return !localJamiId.isEmpty && uri.filterOutHost() == localJamiId
    }

    func resolvedUri(localJamiId: String, peerUri: String,
                     isHostedLocally: Bool) -> String {
        guard uri.isEmpty else { return uri }
        return isHostedLocally ? localJamiId : peerUri
    }

    init?(_ dict: [String: String]) {
        guard let uri = dict[ConfInfoKey.uri.rawValue] else { return nil }
        func value(_ key: ConfInfoKey) -> String? { dict[key.rawValue] }
        func flag(_ key: ConfInfoKey) -> Bool { Bool(libJamiString: value(key)) ?? false }
        func dimension(_ key: ConfInfoKey) -> CGFloat {
            CGFloat(value(key).flatMap(Double.init) ?? 0)
        }

        self.uri = uri
        self.device = value(.device) ?? ""
        self.sinkId = SinkId(raw: value(.sinkId) ?? "")
        self.isActive = flag(.active)
        self.frame = CGRect(x: dimension(.frameX), y: dimension(.frameY),
                            width: dimension(.frameWidth), height: dimension(.frameHeight))
        self.isVideoMuted = flag(.videoMuted)
        self.isAudioLocallyMuted = flag(.audioLocalMuted)
        self.isAudioModeratorMuted = flag(.audioModeratorMuted)
        self.isModerator = flag(.isModerator)
        self.isHandRaised = flag(.handRaised)
        self.hasVoiceActivity = flag(.voiceActivity)
        self.isRecording = flag(.recording)
    }
}
