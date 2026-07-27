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

/// Turns raw libjami signals into events `CallStore` can apply without
/// reading anything back from libjami.
final class CallEventResolver: @unchecked Sendable {

    let events: AsyncStream<LibJamiCallEvent>

    private let api: LibJamiCallAPI
    private let queue: DispatchQueue
    private let continuation: AsyncStream<LibJamiCallEvent>.Continuation

    init(api: LibJamiCallAPI,
         queue: DispatchQueue = DispatchQueue(label: "com.savoirfairelinux.jami.calls.signals",
                                              qos: .userInitiated)) {
        self.api = api
        self.queue = queue
        var continuation: AsyncStream<LibJamiCallEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
    }

    /// Called on a libjami thread. Hands off immediately.
    func handle(_ signal: RawCallSignal) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.continuation.yield(self.resolve(signal))
        }
    }

    private func resolve(_ signal: RawCallSignal) -> LibJamiCallEvent {
        switch signal {
        case let .callStateChanged(callId, state, accountId, code):
            let parsed = LibJamiCallState(rawValue: state)
            // Only a call that just reached `current` has a negotiated list
            // worth reading; every other state would return the stale one.
            let negotiated = parsed == .current
                ? api.currentMedia(callId: callId, accountId: accountId)
                : []
            let codec = parsed == .current
                ? api.callDetails(callId: callId, accountId: accountId)?.videoCodec
                : nil
            return .callStateChanged(callId: callId, state: parsed, rawState: state,
                                     accountId: accountId, code: code,
                                     negotiatedMedia: negotiated,
                                     videoCodec: codec)

        case let .incomingCall(accountId, callId, peerUri, media):
            return .incomingCall(accountId: accountId, callId: callId, peerUri: peerUri,
                                 media: [MediaItem](libJamiMediaList: media),
                                 details: api.callDetails(callId: callId,
                                                          accountId: accountId))

        case let .conferenceCreated(conferenceId, conversationId, accountId):
            let details = api.conferenceDetails(conferenceId: conferenceId,
                                                accountId: accountId)
            return .conferenceCreated(conferenceId: conferenceId,
                                      conversationId: conversationId,
                                      accountId: accountId,
                                      state: details["STATE"] ?? "",
                                      memberCallIds: api.conferenceCalls(
                                        conferenceId: conferenceId, accountId: accountId),
                                      participants: api.conferenceInfos(
                                        conferenceId: conferenceId, accountId: accountId),
                                      media: api.currentMedia(callId: conferenceId,
                                                              accountId: accountId))

        case let .conferenceChanged(conferenceId, accountId, state, memberCallIds):
            return .conferenceChanged(conferenceId: conferenceId, accountId: accountId,
                                      state: state,
                                      memberCallIds: memberCallIds)

        case let .mediaChangeRequested(accountId, callId, media):
            return .mediaChangeRequested(accountId: accountId, callId: callId,
                                         media: [MediaItem](libJamiMediaList: media))

        case let .mediaNegotiationStatus(callId, event, media):
            return .mediaNegotiationStatus(callId: callId,
                                           event: MediaNegotiationEvent(rawValue: event),
                                           media: [MediaItem](libJamiMediaList: media))

        case let .conferenceInfosUpdated(conferenceId, info):
            return .conferenceInfosUpdated(
                conferenceId: conferenceId,
                participants: info.compactMap(ConferenceParticipantInfo.init))

        case let .incomingMessage(callId, fromUri, message):
            return .incomingMessage(callId: callId, fromUri: fromUri, message: message)

        case let .peerHold(callId, hold):
            return .peerHold(callId: callId, hold: hold)

        case let .audioMuted(callId, muted):
            return .audioMuted(callId: callId, muted: muted)

        case let .videoMuted(callId, muted):
            return .videoMuted(callId: callId, muted: muted)

        case let .remoteRecordingChanged(callId, recording):
            return .remoteRecordingChanged(callId: callId, recording: recording)

        case let .conferenceRemoved(conferenceId):
            return .conferenceRemoved(conferenceId: conferenceId)
        }
    }
}
