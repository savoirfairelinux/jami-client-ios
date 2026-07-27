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

    static let callId = CallId(raw: conversationId1)
    static let secondaryCallId = CallId(raw: conversationId2)
    static let inviteCallId = CallId(raw: deviceId1)
    static let hostCallId = CallId(raw: deviceId2)
    static let conferenceId = ConfId(raw: "conferenceId")
    static let peerUri = jamiId2
    static let secondaryPeerUri = jamiId3
    static let tertiaryPeerUri = jamiId4
    static let remoteDeviceId = deviceId2
    static let secondaryRemoteDeviceId = deviceId1
    static let remoteSinkId = "remoteSinkId"
    static let secondaryRemoteSinkId = "secondaryRemoteSinkId"
    static let tertiaryRemoteSinkId = "tertiaryRemoteSinkId"

    static func call(id: CallId = callId,
                     conversationId: String? = conversationId1,
                     accountId: String = accountId1,
                     direction: CallDirection = .outgoing,
                     peerUri: String = peerUri,
                     status: CallStatus = .current,
                     media: [MediaItem] = [],
                     isAudioOnly: Bool = false) -> CallState {
        CallState(id: id,
                  accountId: accountId,
                  direction: direction,
                  peerUri: peerUri,
                  status: status,
                  media: media,
                  isAudioOnly: isAudioOnly,
                  conversationId: conversationId)
    }

    static func conference(id: ConfId = conferenceId,
                           conversationId: String? = conversationId2,
                           accountId: String = accountId1,
                           media: [MediaItem] = [],
                           pendingMediaRequest: [MediaItem]? = nil,
                           participants: [ConferenceParticipantInfo] = [],
                           layout: ConferenceLayoutMode = .grid,
                           isHost: Bool = false,
                           lifecycle: ConferenceLifecycle = .unknown) -> ConferenceState {
        var conference = ConferenceState(id: id,
                                         accountId: accountId,
                                         media: media,
                                         pendingMediaRequest: pendingMediaRequest,
                                         participants: participants,
                                         layout: layout,
                                         isHost: isHost,
                                         lifecycle: lifecycle)
        conference.conversationId = conversationId
        return conference
    }

    static func directCall(id: String = callId.raw,
                           peerUri: String = peerUri,
                           isOngoing: Bool,
                           hasVideo: Bool,
                           hasNegotiatedVideo: Bool) -> CallTilePlanner.DirectCall {
        CallTilePlanner.DirectCall(id: id,
                                   peerUri: peerUri,
                                   isOngoing: isOngoing,
                                   hasVideo: hasVideo,
                                   hasNegotiatedVideo: hasNegotiatedVideo)
    }

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
        let dictionary = participantDictionary(
            uri: uri, device: device, sinkId: sinkId,
            isModerator: isModerator, isActive: isActive,
            handRaised: handRaised, audioLocalMuted: audioLocalMuted,
            audioModeratorMuted: audioModeratorMuted, videoMuted: videoMuted,
            recording: recording, voiceActivity: voiceActivity,
            frameSize: frameSize)
        return ConferenceParticipantInfo(dictionary)!
    }

    static func participantDictionary(
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
    ) -> [String: String] {
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
        return dictionary
    }
}
