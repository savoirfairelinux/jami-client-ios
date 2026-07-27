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

import CoreGraphics
@testable import Ring

enum CallTestFixtures {

    static func participant(
        uri: String,
        device: String = deviceId1,
        sinkId: String? = nil,
        isModerator: Bool = false,
        isActive: Bool = false,
        handRaised: Bool = false,
        audioLocalMuted: Bool = false,
        audioModeratorMuted: Bool = false,
        videoMuted: Bool = false,
        recording: Bool = false,
        voiceActivity: Bool = false,
        frameSize: CGSize? = nil
    ) -> ConferenceParticipantInfo {
        var dictionary: [String: String] = [
            ConfInfoKey.uri.rawValue: uri,
            ConfInfoKey.device.rawValue: device,
            ConfInfoKey.sinkId.rawValue: sinkId ?? "sink_" + uri,
            ConfInfoKey.isModerator.rawValue: isModerator.libJamiString,
            ConfInfoKey.active.rawValue: isActive.libJamiString,
            ConfInfoKey.handRaised.rawValue: handRaised.libJamiString,
            ConfInfoKey.audioLocalMuted.rawValue: audioLocalMuted.libJamiString,
            ConfInfoKey.audioModeratorMuted.rawValue: audioModeratorMuted.libJamiString,
            ConfInfoKey.videoMuted.rawValue: videoMuted.libJamiString,
            ConfInfoKey.recording.rawValue: recording.libJamiString,
            ConfInfoKey.voiceActivity.rawValue: voiceActivity.libJamiString
        ]
        if let frameSize = frameSize {
            dictionary[ConfInfoKey.frameWidth.rawValue] = String(describing: frameSize.width)
            dictionary[ConfInfoKey.frameHeight.rawValue] = String(describing: frameSize.height)
        }
        return ConferenceParticipantInfo(dictionary)!
    }
}
