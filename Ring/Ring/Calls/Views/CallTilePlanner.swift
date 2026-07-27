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

enum CallTileSource: Equatable {
    case localCamera
    case remoteStream(SinkId)
}

struct CallTilePlan: Equatable, Identifiable {
    let id: String
    let isLocalPreview: Bool
    let source: CallTileSource
    let showsVideo: Bool
    let isSpeaking: Bool
    let avatarUri: String
    let showsName: Bool
    var expectedVideoSize: CGSize?
}

enum CallTilePlanner {

    static func conferenceTiles(_ participants: [ConferenceParticipantInfo],
                                localJamiId: String,
                                localCameraOn: Bool,
                                frozenForRecomposition: Bool = false) -> [CallTilePlan] {
        participants.map { info in
            if info.isLocalParticipant(localJamiId: localJamiId) {
                return CallTilePlan(id: info.id,
                                    isLocalPreview: false,
                                    source: .localCamera,
                                    showsVideo: localCameraOn,
                                    isSpeaking: info.hasVoiceActivity,
                                    avatarUri: localJamiId,
                                    showsName: true)
            }
            let cropSize = info.frame.size
            let hasCrop = cropSize.width > 0 && cropSize.height > 0
            let expected: CGSize? = frozenForRecomposition ? .zero
                : (hasCrop ? cropSize : nil)
            return CallTilePlan(id: info.id,
                                isLocalPreview: false,
                                source: .remoteStream(info.sinkId),
                                showsVideo: !info.isVideoMuted,
                                isSpeaking: info.hasVoiceActivity,
                                avatarUri: info.uri,
                                showsName: true,
                                expectedVideoSize: expected)
        }
    }

    struct DirectCall {
        let id: String
        let peerUri: String
        let isOngoing: Bool
        let hasVideo: Bool
        let hasNegotiatedVideo: Bool
    }

    static func directCallTiles(_ call: DirectCall) -> [CallTilePlan] {
        let localPreview = CallTilePlan(id: CanvasParticipant.localId,
                                        isLocalPreview: true,
                                        source: .localCamera,
                                        showsVideo: true,
                                        isSpeaking: false,
                                        avatarUri: "",
                                        showsName: false)
        if call.hasVideo && !call.isOngoing {
            return [localPreview]
        }

        var plans = [CallTilePlan(id: call.id,
                                  isLocalPreview: false,
                                  source: .remoteStream(SinkId(raw: call.id)),
                                  showsVideo: call.hasNegotiatedVideo && call.isOngoing,
                                  isSpeaking: false,
                                  avatarUri: call.peerUri,
                                  showsName: false)]
        if call.hasVideo {
            plans.append(localPreview)
        }
        return plans
    }
}
