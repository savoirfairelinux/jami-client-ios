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

/// Keys of the dictionary returned by `getCallDetails`.
enum CallDetailKey: String {
    case callType = "CALL_TYPE"
    case peerNumber = "PEER_NUMBER"
    case registeredName = "REGISTERED_NAME"
    case displayName = "DISPLAY_NAME"
    case callState = "CALL_STATE"
    case confId = "CONF_ID"
    case timestampStart = "TIMESTAMP_START"
    case toUsername = "TO_USERNAME"
    case accountId = "ACCOUNTID"
    case peerHold = "PEER_HOLD"
    case audioMuted = "AUDIO_MUTED"
    case videoMuted = "VIDEO_MUTED"
    case videoSource = "VIDEO_SOURCE"
    case audioOnly = "AUDIO_ONLY"
    case audioCodec = "AUDIO_CODEC"
    case videoCodec = "VIDEO_CODEC"
}

/// Keys of a media-attribute dictionary (one entry of a media list).
enum MediaKey: String {
    case mediaType = "MEDIA_TYPE"
    case enabled = "ENABLED"
    case muted = "MUTED"
    case source = "SOURCE"
    case label = "LABEL"
    case onHold = "HOLD"
}

/// Values of `MediaKey.mediaType`.
enum MediaType: String {
    case audio = "MEDIA_TYPE_AUDIO"
    case video = "MEDIA_TYPE_VIDEO"
}

/// `MediaNegotiationStatus` signal event values.
enum MediaNegotiationEvent: String {
    case success = "NEGOTIATION_SUCCESS"
    case failure = "NEGOTIATION_FAIL"
}

/// Call states as delivered by the `StateChange` signal / `CALL_STATE`.
enum LibJamiCallState: String, CaseIterable {
    case incoming = "INCOMING"
    case connecting = "CONNECTING"
    case ringing = "RINGING"
    case current = "CURRENT"
    case hungUp = "HUNGUP"
    case busy = "BUSY"
    case peerBusy = "PEER_BUSY"
    case failure = "FAILURE"
    case hold = "HOLD"
    case inactive = "INACTIVE"
    case over = "OVER"
}

/// Keys of one entry of the `OnConferenceInfosUpdated` participant list.
enum ConfInfoKey: String {
    case uri
    case device
    case sinkId
    case active
    case frameX = "x"
    case frameY = "y"
    case frameWidth = "w"
    case frameHeight = "h"
    case videoMuted
    case audioLocalMuted
    case audioModeratorMuted
    case isModerator
    case handRaised
    case voiceActivity
    case recording
}

extension Bool {
    /// Parses libjami's boolean encodings ("true"/"false", "1"/"0").
    init?(libJamiString: String?) {
        switch libJamiString?.lowercased() {
        case "true", "1", "yes":
            self = true
        case "false", "0", "no":
            self = false
        default:
            return nil
        }
    }

    var libJamiString: String {
        return self ? "true" : "false"
    }
}
