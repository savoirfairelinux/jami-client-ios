/*
 * Copyright (C) 2014-2026 Savoir-faire Linux Inc.
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

/// Calls and conference operations exposed by libjami to `CallStore`.
///
/// The production client forwards commands and queries through `CallsAdapter`.
///
/// This API receives no libjami events; incoming callbacks enter through
/// `CallEventSource`.
protocol LibJamiCallAPI: AnyObject, Sendable {
    // Call lifecycle
    func placeCall(accountId: String, to participantId: String, media: [MediaItem]) -> String?
    func accept(callId: String, accountId: String, media: [MediaItem]) -> Bool
    func refuse(callId: String, accountId: String) -> Bool
    func hangUp(callId: String, accountId: String) -> Bool
    func hold(callId: String, accountId: String) -> Bool
    func resume(callId: String, accountId: String) -> Bool
    func playDTMF(code: String)

    // Media renegotiation (SDP re-invite, and the answer to the peer's)
    func requestMediaChange(callId: String, accountId: String, media: [MediaItem]) -> Bool
    func answerMediaChangeRequest(callId: String, accountId: String, media: [MediaItem])
    func currentMedia(callId: String, accountId: String) -> [MediaItem]

    // Queries
    func callDetails(callId: String, accountId: String) -> CallDetails?
    func callList(accountId: String) -> [String]
    func activeCalls(conversationId: String, accountId: String) -> [[String: String]]

    // In-call messaging
    func sendInCallMessage(callId: String, accountId: String,
                           message: [String: String], from jamiId: String, isMixed: Bool)

    // Conference
    func joinConference(_ conferenceId: String, callId: String,
                        accountId: String, account2Id: String) -> Bool
    func joinConferences(_ first: String, second: String,
                         accountId: String, account2Id: String) -> Bool
    func joinCalls(_ first: String, second: String,
                   accountId: String, account2Id: String) -> Bool
    func conferenceInfos(conferenceId: String, accountId: String) -> [ConferenceParticipantInfo]
    func conferenceDetails(conferenceId: String, accountId: String) -> [String: String]
    func conferenceCalls(conferenceId: String, accountId: String) -> [String]
    func hangUpConference(conferenceId: String, accountId: String) -> Bool
    func setActiveParticipant(_ participantId: String, conferenceId: String, accountId: String)
    func setConferenceLayout(_ layout: Int, conferenceId: String, accountId: String)
    func setModerator(_ participantId: String, conferenceId: String,
                      accountId: String, active: Bool)
    func hangUpParticipant(_ participantId: String, conferenceId: String,
                           accountId: String, deviceId: String)
    func muteStream(_ participantId: String, conferenceId: String, accountId: String,
                    deviceId: String, streamId: String, muted: Bool)
    func raiseHand(_ participantId: String, conferenceId: String, accountId: String,
                   deviceId: String, raised: Bool)
}

/// Stateless beyond the adapter it forwards to; libjami does its own locking.
final class LibJamiCallClient: LibJamiCallAPI, @unchecked Sendable {

    private let adapter: CallsAdapter

    init(adapter: CallsAdapter) {
        self.adapter = adapter
    }

    /// A locally-minted id stands for a call libjami has not reported yet;
    /// sending one would address a call that does not exist.
    private func rejectsLocal(_ callId: String, _ function: StaticString = #function) -> Bool {
        guard CallId(raw: callId).isLocal else { return false }
        assertionFailure("local call id sent to libjami from \(function)")
        return true
    }

    // MARK: - Call lifecycle

    func placeCall(accountId: String, to participantId: String, media: [MediaItem]) -> String? {
        let callId = adapter.placeCall(withAccountId: accountId,
                                       toParticipantId: participantId,
                                       withMedia: media.toDictionaries())
        guard let callId = callId, !callId.isEmpty else { return nil }
        return callId
    }

    func accept(callId: String, accountId: String, media: [MediaItem]) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.acceptCall(withId: callId, accountId: accountId,
                                  withMedia: media.toDictionaries())
    }

    func refuse(callId: String, accountId: String) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.declineCall(withId: callId, accountId: accountId)
    }

    func hangUp(callId: String, accountId: String) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.endCall(callId, accountId: accountId)
    }

    func hold(callId: String, accountId: String) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.holdCall(withId: callId, accountId: accountId)
    }

    func resume(callId: String, accountId: String) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.resumeCall(withId: callId, accountId: accountId)
    }

    func playDTMF(code: String) {
        adapter.playDTMF(code)
    }

    // MARK: - Media

    func requestMediaChange(callId: String, accountId: String, media: [MediaItem]) -> Bool {
        guard !rejectsLocal(callId) else { return false }
        return adapter.requestMediaChange(callId, accountId: accountId,
                                          withMedia: media.toDictionaries())
    }

    func answerMediaChangeRequest(callId: String, accountId: String, media: [MediaItem]) {
        guard !rejectsLocal(callId) else { return }
        adapter.answerMediaChangeResquest(callId, accountId: accountId,
                                          withMedia: media.toDictionaries())
    }

    func currentMedia(callId: String, accountId: String) -> [MediaItem] {
        let list = adapter.currentMediaList(withCallId: callId, accountId: accountId) ?? []
        return [MediaItem](libJamiMediaList: list)
    }

    // MARK: - Queries

    func callDetails(callId: String, accountId: String) -> CallDetails? {
        guard let dict = adapter.callDetails(withCallId: callId, accountId: accountId),
              !dict.isEmpty else {
            return nil
        }
        return CallDetails(dict)
    }

    func callList(accountId: String) -> [String] {
        return adapter.calls(forAccountId: accountId) ?? []
    }

    func activeCalls(conversationId: String, accountId: String) -> [[String: String]] {
        return adapter.getActiveCalls(conversationId, accountId: accountId) ?? []
    }

    // MARK: - In-call messaging

    func sendInCallMessage(callId: String, accountId: String,
                           message: [String: String], from jamiId: String, isMixed: Bool) {
        adapter.sendTextMessage(withCallID: callId, accountId: accountId,
                                message: message, from: jamiId, isMixed: isMixed)
    }

    // MARK: - Conference

    func joinConference(_ conferenceId: String, callId: String,
                        accountId: String, account2Id: String) -> Bool {
        return adapter.joinConference(conferenceId, call: callId,
                                      accountId: accountId, account2Id: account2Id)
    }

    func joinConferences(_ first: String, second: String,
                         accountId: String, account2Id: String) -> Bool {
        return adapter.joinConferences(first, secondConference: second,
                                       accountId: accountId, account2Id: account2Id)
    }

    func joinCalls(_ first: String, second: String,
                   accountId: String, account2Id: String) -> Bool {
        return adapter.joinCall(first, second: second,
                                accountId: accountId, account2Id: account2Id)
    }

    func conferenceInfos(conferenceId: String, accountId: String) -> [ConferenceParticipantInfo] {
        let raw = adapter.getConferenceInfo(conferenceId, accountId: accountId) as? [[String: String]]
        return (raw ?? []).compactMap(ConferenceParticipantInfo.init)
    }

    func conferenceDetails(conferenceId: String, accountId: String) -> [String: String] {
        return adapter.getConferenceDetails(conferenceId, accountId: accountId) ?? [:]
    }

    func conferenceCalls(conferenceId: String, accountId: String) -> [String] {
        return adapter.getConferenceCalls(conferenceId, accountId: accountId) ?? []
    }

    func hangUpConference(conferenceId: String, accountId: String) -> Bool {
        return adapter.disconnectConference(conferenceId, accountId: accountId)
    }

    func setActiveParticipant(_ participantId: String, conferenceId: String, accountId: String) {
        adapter.setActiveParticipant(participantId, forConference: conferenceId,
                                     accountId: accountId)
    }

    func setConferenceLayout(_ layout: Int, conferenceId: String, accountId: String) {
        adapter.setConferenceLayout(Int32(layout), forConference: conferenceId,
                                    accountId: accountId)
    }

    func setModerator(_ participantId: String, conferenceId: String,
                      accountId: String, active: Bool) {
        adapter.setConferenceModerator(participantId, forConference: conferenceId,
                                       accountId: accountId, active: active)
    }

    func hangUpParticipant(_ participantId: String, conferenceId: String,
                           accountId: String, deviceId: String) {
        adapter.disconnectConferenceParticipant(participantId, forConference: conferenceId,
                                                accountId: accountId, deviceId: deviceId)
    }

    func muteStream(_ participantId: String, conferenceId: String, accountId: String,
                    deviceId: String, streamId: String, muted: Bool) {
        adapter.muteStream(participantId, forConference: conferenceId, accountId: accountId,
                           deviceId: deviceId, streamId: streamId, state: muted)
    }

    func raiseHand(_ participantId: String, conferenceId: String, accountId: String,
                   deviceId: String, raised: Bool) {
        adapter.raiseHand(participantId, forConference: conferenceId, accountId: accountId,
                          deviceId: deviceId, state: raised)
    }
}
