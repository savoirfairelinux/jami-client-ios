/*
 * Copyright (C) 2022-2026 Savoir-faire Linux Inc.
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

enum PiPSourceSelector {

    struct Selection: Equatable {
        let uri: String
        let sinkId: SinkId
    }

    static func select(call: CallState?, conference: ConferenceState?,
                       localJamiId: String, current: Selection?) -> Selection? {
        guard let call = call, !call.status.isTerminal else { return nil }
        if let conference = conference, !conference.participants.isEmpty {
            return selectInConference(conference, localJamiId: localJamiId,
                                      current: current)
        }
        guard call.status.isOngoing, call.hasNegotiatedVideo else { return nil }
        return Selection(uri: call.peerUri, sinkId: SinkId(raw: call.id.raw))
    }

    private static func selectInConference(_ conference: ConferenceState,
                                           localJamiId: String,
                                           current: Selection?) -> Selection? {
        let remotesWithVideo = conference.participants.filter {
            !$0.isLocalParticipant(localJamiId: localJamiId) &&
                !$0.isVideoMuted && !$0.sinkId.raw.isEmpty
        }
        guard !remotesWithVideo.isEmpty else { return nil }
        if let speaker = remotesWithVideo.first(where: \.hasVoiceActivity) {
            return Selection(uri: speaker.uri, sinkId: speaker.sinkId)
        }
        if let current = current,
           let retained = remotesWithVideo.first(where: { $0.sinkId == current.sinkId }) {
            return Selection(uri: retained.uri, sinkId: retained.sinkId)
        }
        let first = remotesWithVideo[0]
        return Selection(uri: first.uri, sinkId: first.sinkId)
    }
}
