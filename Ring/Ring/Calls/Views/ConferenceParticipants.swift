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

struct ConferenceParticipantRow: Identifiable, Equatable {
    let id: String
    let uri: String
    let isLocal: Bool
    let isModerator: Bool
    let isActive: Bool
    let isAudioMuted: Bool
    let isAudioModeratorMuted: Bool
    let isVideoMuted: Bool
    let isHandRaised: Bool
    let isRecording: Bool
    let isSpeaking: Bool
    let actions: [ConferenceMenuItem]
}

struct PendingParticipantRow: Identifiable, Equatable {
    let id: String
    let callId: CallId
    let uri: String
    let status: CallStatus

    var progressText: String {
        switch status {
        case .connecting: return L10n.Calls.connecting
        case .ringing: return L10n.Calls.ringing
        default: return L10n.Calls.calling
        }
    }

    func stopCallingLabel(displayName: String) -> String {
        L10n.Calls.stopCalling(displayName)
    }
}

enum ConferenceParticipants {

    static func pendingRows(from invites: [PendingConferenceInvite]) -> [PendingParticipantRow] {
        return invites.map { invite in
            PendingParticipantRow(id: invite.callId.raw, callId: invite.callId,
                                  uri: invite.peerUri, status: invite.status)
        }
    }

    static func rows(from call: CallState, localJamiId: String) -> [ConferenceParticipantRow] {
        let local = ConferenceParticipantRow(
            id: ConferenceParticipantInfo.id(uri: localJamiId, device: ""),
            uri: localJamiId, isLocal: true, isModerator: false, isActive: false,
            isAudioMuted: call.isAudioMuted, isAudioModeratorMuted: false,
            isVideoMuted: call.isVideoMuted,
            isHandRaised: false, isRecording: false, isSpeaking: false, actions: [])
        guard !call.peerUri.isEmpty else { return [local] }
        let peer = ConferenceParticipantRow(
            id: ConferenceParticipantInfo.id(uri: call.peerUri, device: ""),
            uri: call.peerUri, isLocal: false, isModerator: false, isActive: false,
            isAudioMuted: false, isAudioModeratorMuted: false,
            isVideoMuted: false, isHandRaised: false,
            isRecording: call.peerIsRecording, isSpeaking: false, actions: [])
        return [local, peer]
    }

    static func rows(from conference: ConferenceState,
                     localJamiId: String,
                     peerUri: String,
                     builder: ConferenceMenuBuilder = ConferenceMenuBuilder())
    -> [ConferenceParticipantRow] {
        let localInfo = conference.participants.first {
            $0.isLocalParticipant(localJamiId: localJamiId,
                                  isHostedLocally: conference.isHost)
        }

        let joined = conference.participants.map { info -> ConferenceParticipantRow in
            let isLocal = info.id == localInfo?.id
            let actions = self.actions(for: info, isLocal: isLocal,
                                       conference: conference, localInfo: localInfo, builder: builder)
            return ConferenceParticipantRow(
                id: info.id,
                uri: info.resolvedUri(localJamiId: localJamiId,
                                      peerUri: peerUri,
                                      isHostedLocally: conference.isHost),
                isLocal: isLocal,
                isModerator: info.isModerator,
                isActive: info.isActive,
                isAudioMuted: info.isAudioLocallyMuted || info.isAudioModeratorMuted,
                isAudioModeratorMuted: info.isAudioModeratorMuted,
                isVideoMuted: info.isVideoMuted,
                isHandRaised: info.isHandRaised,
                isRecording: info.isRecording,
                isSpeaking: info.hasVoiceActivity,
                actions: actions)
        }

        return joined.filter { $0.isLocal } + joined.filter { !$0.isLocal }
    }

    private static func actions(for info: ConferenceParticipantInfo, isLocal: Bool,
                                conference: ConferenceState,
                                localInfo: ConferenceParticipantInfo?,
                                builder: ConferenceMenuBuilder) -> [ConferenceMenuItem] {
        let base: [ConferenceMenuItem]
        if isLocal {
            base = builder.menuForLocalTile(layout: conference.layout,
                                            isActive: info.isActive,
                                            isHandRaised: info.isHandRaised,
                                            isModeratorMuted: info.isAudioModeratorMuted)
        } else {
            let role: ConferenceRole = conference.isHost ? .host
                : (localInfo?.isModerator == true ? .moderator : .regular)
            base = builder.menuForParticipant(isHost: conference.isHost,
                                              layout: conference.layout,
                                              isActive: info.isActive,
                                              role: role,
                                              isHandRaised: info.isHandRaised)
        }
        let canModerate = conference.isHost || (localInfo?.isModerator == true)
        guard !canModerate else { return base }
        return base.filter { $0 != .maximize && $0 != .minimize }
    }
}
