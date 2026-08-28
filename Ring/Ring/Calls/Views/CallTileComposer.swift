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

import UIKit

struct CallTileComposer {

    struct Composition {
        let tiles: [CanvasTileModel]
        let style: CanvasTileStyle
    }

    private let videoService: VideoService
    private let localJamiId: String

    init(videoService: VideoService, localJamiId: String) {
        self.videoService = videoService
        self.localJamiId = localJamiId
    }

    func compose(call: CallState?, conference: ConferenceState?,
                 avatars: CallParticipantAvatars?,
                 frozenForRecomposition: Bool = false) -> Composition {
        let terminated = call?.status.isTerminal == true
        let isSwarmCall = call?.peerUri.hasPrefix("swarm:") == true
        if !terminated, let conference = conference, !conference.participants.isEmpty {
            let localCameraOn = call?.effectiveMedia(in: conference).hasVideo == true
            let isLocalOnlySwarm = isSwarmCall && conference.participants.count == 1
                && conference.participants[0].isLocalParticipant(
                    localJamiId: localJamiId,
                    isHostedLocally: conference.isHost)
            let plans = CallTilePlanner.conferenceTiles(
                conference.participants,
                localJamiId: localJamiId,
                peerUri: call?.peerUri ?? "",
                isHostedLocally: conference.isHost,
                localCameraOn: localCameraOn,
                usesStableLocalIdentity: isSwarmCall,
                showsNames: !isLocalOnlySwarm,
                frozenForRecomposition: frozenForRecomposition)
            let style: CanvasTileStyle = isLocalOnlySwarm ? .plain : .cards
            return makeComposition(plans: plans, style: style, avatars: avatars)
        }

        let plans: [CallTilePlan]
        if terminated, conference != nil {
            plans = []
        } else if let call = call, isSwarmCall {
            plans = [CallTilePlanner.swarmStartupTile(
                localJamiId: localJamiId,
                localCameraOn: call.effectiveMedia(in: conference).hasVideo)]
        } else if let call = call {
            plans = CallTilePlanner.directCallTiles(
                CallTilePlanner.DirectCall(id: call.id.raw,
                                           peerUri: call.peerUri,
                                           isOngoing: call.status.isOngoing,
                                           hasVideo: !terminated && call.hasVideo,
                                           hasNegotiatedVideo: call.hasNegotiatedVideo))
        } else {
            plans = []
        }
        return makeComposition(plans: plans, style: .plain, avatars: avatars)
    }

    private func makeComposition(plans: [CallTilePlan], style: CanvasTileStyle,
                                 avatars: CallParticipantAvatars?) -> Composition {
        Composition(tiles: plans.map { model(from: $0, avatars: avatars) },
                    style: style)
    }

    private func model(from plan: CallTilePlan,
                       avatars: CallParticipantAvatars?) -> CanvasTileModel {
        let distributor: FrameDistributor?
        let transform: CGAffineTransform?
        switch plan.source {
        case .localCamera:
            distributor = videoService.localFrames
            transform = videoService.localLayerTransform
        case .remoteStream(let sinkId):
            distributor = plan.showsVideo ? videoService.distributor(for: sinkId) : nil
            transform = nil
        }
        return CanvasTileModel(
            participant: CanvasParticipant(id: plan.id, isLocalPreview: plan.isLocalPreview),
            tileState: ParticipantTileState(showsVideo: plan.showsVideo,
                                            showsName: plan.showsName,
                                            isSpeaking: plan.isSpeaking),
            distributor: distributor,
            fixedTransform: transform,
            avatarProvider: plan.avatarUri.isEmpty ? nil
                : avatars?.provider(forUri: plan.avatarUri),
            expectedVideoSize: plan.expectedVideoSize)
    }
}
