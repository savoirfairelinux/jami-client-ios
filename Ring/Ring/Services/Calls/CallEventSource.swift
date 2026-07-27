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

enum RawCallSignal: Sendable {
    case callStateChanged(callId: String, state: String, accountId: String, code: Int)
    case incomingCall(accountId: String, callId: String, peerUri: String,
                      media: [[String: String]])
    case mediaChangeRequested(accountId: String, callId: String, media: [[String: String]])
    case mediaNegotiationStatus(callId: String, event: String, media: [[String: String]])
    case incomingMessage(callId: String, fromUri: String, message: [String: String])
    case peerHold(callId: String, hold: Bool)
    case audioMuted(callId: String, muted: Bool)
    case videoMuted(callId: String, muted: Bool)
    case remoteRecordingChanged(callId: String, recording: Bool)
    case conferenceCreated(conferenceId: String, conversationId: String, accountId: String)
    case conferenceChanged(conferenceId: String, accountId: String, state: String,
                           memberCallIds: [String])
    case conferenceRemoved(conferenceId: String)
    case conferenceInfosUpdated(conferenceId: String, info: [[String: String]])
}

/// A parsed call event carrying everything `CallStore` needs to apply it,
/// so the store never has to read back from libjami mid-decision.
enum LibJamiCallEvent: Sendable {
    /// `negotiatedMedia` is libjami's confirmed media list, resolved when the
    /// call reaches `current` and empty otherwise.
    case callStateChanged(callId: String, state: LibJamiCallState?, rawState: String,
                          accountId: String, code: Int, negotiatedMedia: [MediaItem],
                          videoCodec: String?)
    case incomingCall(accountId: String, callId: String, peerUri: String,
                      media: [MediaItem], details: CallDetails?)
    case mediaChangeRequested(accountId: String, callId: String, media: [MediaItem])
    case mediaNegotiationStatus(callId: String, event: MediaNegotiationEvent?,
                                media: [MediaItem])
    case incomingMessage(callId: String, fromUri: String, message: [String: String])
    case peerHold(callId: String, hold: Bool)
    case audioMuted(callId: String, muted: Bool)
    case videoMuted(callId: String, muted: Bool)
    case remoteRecordingChanged(callId: String, recording: Bool)
    case conferenceCreated(conferenceId: String, conversationId: String, accountId: String,
                           state: String, memberCallIds: [String],
                           participants: [ConferenceParticipantInfo], media: [MediaItem])
    case conferenceChanged(conferenceId: String, accountId: String, state: String,
                           memberCallIds: [String])
    case conferenceRemoved(conferenceId: String)
    case conferenceInfosUpdated(conferenceId: String, participants: [ConferenceParticipantInfo])
}

final class CallEventSource: NSObject {

    private let onSignal: @Sendable (RawCallSignal) -> Void

    init(onSignal: @escaping @Sendable (RawCallSignal) -> Void) {
        self.onSignal = onSignal
        super.init()
    }

    func attachToAdapter() {
        CallsAdapter.delegate = self
    }
}

extension CallEventSource: CallsAdapterDelegate {

    func didChangeCallState(withCallId callId: String, state: String,
                            accountId: String, stateCode: NSInteger) {
        onSignal(.callStateChanged(callId: callId, state: state,
                                   accountId: accountId, code: stateCode))
    }

    func receivingCall(withAccountId accountId: String, callId: String,
                       fromURI uri: String, withMedia: [[String: String]]) {
        onSignal(.incomingCall(accountId: accountId, callId: callId,
                               peerUri: uri, media: withMedia))
    }

    func didReceiveMediaChangeRequest(withAccountId accountId: String, callId: String,
                                      withMedia: [[String: String]]) {
        onSignal(.mediaChangeRequested(accountId: accountId, callId: callId,
                                       media: withMedia))
    }

    func didChangeMediaNegotiationStatus(withCallId callId: String, event: String,
                                         withMedia: [[String: String]]) {
        onSignal(.mediaNegotiationStatus(callId: callId, event: event, media: withMedia))
    }

    func didReceiveMessage(withCallId callId: String, fromURI uri: String,
                           message: [String: String]) {
        onSignal(.incomingMessage(callId: callId, fromUri: uri, message: message))
    }

    func callPlacedOnHold(withCallId callId: String, hold: Bool) {
        onSignal(.peerHold(callId: callId, hold: hold))
    }

    func audioMuted(call callId: String, mute: Bool) {
        onSignal(.audioMuted(callId: callId, muted: mute))
    }

    func videoMuted(call callId: String, mute: Bool) {
        onSignal(.videoMuted(callId: callId, muted: mute))
    }

    func remoteRecordingChanged(call callId: String, record: Bool) {
        onSignal(.remoteRecordingChanged(callId: callId, recording: record))
    }

    func conferenceCreated(conferenceId: String, conversationId: String, accountId: String) {
        onSignal(.conferenceCreated(conferenceId: conferenceId,
                                    conversationId: conversationId,
                                    accountId: accountId))
    }

    func conferenceChanged(conference conferenceID: String, accountId: String, state: String,
                           memberCallIds: [String]) {
        onSignal(.conferenceChanged(conferenceId: conferenceID,
                                    accountId: accountId, state: state,
                                    memberCallIds: memberCallIds))
    }

    func conferenceRemoved(conference conferenceID: String) {
        onSignal(.conferenceRemoved(conferenceId: conferenceID))
    }

    func conferenceInfoUpdated(conference conferenceID: String, info: [[String: String]]) {
        onSignal(.conferenceInfosUpdated(conferenceId: conferenceID, info: info))
    }
}
