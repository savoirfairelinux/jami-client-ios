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
import CoreVideo
import CoreGraphics
@testable import Ring

final class TestLibJamiCallAPI: LibJamiCallAPI, @unchecked Sendable {

    var placeCallReturn: String? = "call-1"
    var acceptReturn = true
    var refuseReturn = true
    var hangUpReturn = true
    var hangUpConferenceReturn = true
    var holdReturn = true
    var resumeReturn = true
    var requestMediaChangeReturn = true
    var callDetailsReturn: [String: CallDetails] = [:]
    var currentMediaReturn: [String: [MediaItem]] = [:]
    var conferenceCallsReturn: [String: [String]] = [:]
    var conferenceInfosReturn: [String: [ConferenceParticipantInfo]] = [:]
    var conferenceDetailsReturn: [String: [String: String]] = [:]
    var onPlaceCall: (() -> Void)?

    struct PlacedCall {
        let accountId: String
        let participantId: String
        let media: [MediaItem]
    }

    var placedCalls: [PlacedCall] = []
    var accepted: [(callId: String, media: [MediaItem])] = []
    var refused: [String] = []
    var hungUp: [String] = []
    var held: [String] = []
    var resumed: [String] = []
    var dtmfCodes: [String] = []
    var requestedMediaChanges: [(callId: String, media: [MediaItem])] = []
    var answeredMediaRequests: [(callId: String, media: [MediaItem])] = []
    var joinedCalls: [(first: String, second: String)] = []
    var joinedConferences: [(conferenceId: String, callId: String)] = []
    var hungUpConferences: [String] = []
    var sentMessages: [(callId: String, message: [String: String])] = []
    var moderationCommands: [String] = []

    func placeCall(accountId: String, to participantId: String, media: [MediaItem]) -> String? {
        placedCalls.append(PlacedCall(accountId: accountId,
                                      participantId: participantId,
                                      media: media))
        onPlaceCall?()
        return placeCallReturn
    }

    func accept(callId: String, accountId: String, media: [MediaItem]) -> Bool {
        accepted.append((callId, media))
        return acceptReturn
    }

    func refuse(callId: String, accountId: String) -> Bool {
        refused.append(callId)
        return refuseReturn
    }

    func hangUp(callId: String, accountId: String) -> Bool {
        hungUp.append(callId)
        return hangUpReturn
    }

    func hold(callId: String, accountId: String) -> Bool {
        held.append(callId)
        return holdReturn
    }

    func resume(callId: String, accountId: String) -> Bool {
        resumed.append(callId)
        return resumeReturn
    }

    func playDTMF(code: String) {
        dtmfCodes.append(code)
    }

    func requestMediaChange(callId: String, accountId: String, media: [MediaItem]) -> Bool {
        requestedMediaChanges.append((callId, media))
        return requestMediaChangeReturn
    }

    func answerMediaChangeRequest(callId: String, accountId: String, media: [MediaItem]) {
        answeredMediaRequests.append((callId, media))
    }

    func currentMedia(callId: String, accountId: String) -> [MediaItem] {
        return currentMediaReturn[callId] ?? []
    }

    func callDetails(callId: String, accountId: String) -> CallDetails? {
        return callDetailsReturn[callId]
    }

    func callList(accountId: String) -> [String] { [] }

    func activeCalls(conversationId: String, accountId: String) -> [[String: String]] { [] }

    func sendInCallMessage(callId: String, accountId: String,
                           message: [String: String], from jamiId: String, isMixed: Bool) {
        sentMessages.append((callId, message))
    }

    func joinConference(_ conferenceId: String, callId: String,
                        accountId: String, account2Id: String) -> Bool {
        joinedConferences.append((conferenceId, callId))
        return true
    }

    func joinConferences(_ first: String, second: String,
                         accountId: String, account2Id: String) -> Bool {
        moderationCommands.append("joinConferences:\(first):\(second)")
        return true
    }

    func joinCalls(_ first: String, second: String,
                   accountId: String, account2Id: String) -> Bool {
        joinedCalls.append((first, second))
        return true
    }

    func conferenceInfos(conferenceId: String, accountId: String) -> [ConferenceParticipantInfo] {
        return conferenceInfosReturn[conferenceId] ?? []
    }

    func conferenceDetails(conferenceId: String, accountId: String) -> [String: String] {
        return conferenceDetailsReturn[conferenceId] ?? [:]
    }

    func conferenceCalls(conferenceId: String, accountId: String) -> [String] {
        return conferenceCallsReturn[conferenceId] ?? []
    }

    func hangUpConference(conferenceId: String, accountId: String) -> Bool {
        hungUpConferences.append(conferenceId)
        return hangUpConferenceReturn
    }

    func setActiveParticipant(_ participantId: String, conferenceId: String, accountId: String) {
        moderationCommands.append("setActive:\(participantId):\(conferenceId)")
    }

    func setConferenceLayout(_ layout: Int, conferenceId: String, accountId: String) {
        moderationCommands.append("setLayout:\(layout):\(conferenceId)")
    }

    func setModerator(_ participantId: String, conferenceId: String,
                      accountId: String, active: Bool) {
        moderationCommands.append("setModerator:\(participantId):\(active)")
    }

    func hangUpParticipant(_ participantId: String, conferenceId: String,
                           accountId: String, deviceId: String) {
        moderationCommands.append("hangUpParticipant:\(participantId)")
    }

    func muteStream(_ participantId: String, conferenceId: String, accountId: String,
                    deviceId: String, streamId: String, muted: Bool) {
        moderationCommands.append(
            "muteStream:\(participantId):\(conferenceId):\(deviceId):\(streamId):\(muted)"
        )
    }

    func raiseHand(_ participantId: String, conferenceId: String, accountId: String,
                   deviceId: String, raised: Bool) {
        moderationCommands.append("raiseHand:\(participantId):\(raised)")
    }
}

final class TestLibJamiVideoAPI: LibJamiVideoAPI {
    func registerSink(_ sinkId: SinkId, width: Int, height: Int, hasListeners: Bool) {}
    func removeSink(_ sinkId: SinkId) {}
    func setHasListeners(_ hasListeners: Bool, sinkId: SinkId) {}
    func renderSize(_ sinkId: SinkId) -> CGSize { .zero }
    func writeOutgoingFrame(_ buffer: CVImageBuffer, angle: Int, videoInputId: String) {}
    func addVideoDevice(name: String, info: [String: Any]) {}
    func setDefaultDevice(_ name: String) {}
    func defaultDevice() -> String { "front" }
    func openVideoInput(_ path: String) {}
    func closeVideoInput(_ path: String) {}
    func setDecodingAccelerated(_ state: Bool) {}
    func setEncodingAccelerated(_ state: Bool) {}
    func decodingAccelerated() -> Bool { true }
    func encodingAccelerated() -> Bool { true }
    func startLocalRecording(videoInputId: String, path: String) -> String? { nil }
    func stopLocalRecording(path: String) {}
    func createMediaPlayer(path: String) -> String? { nil }
    func pausePlayer(playerId: String, pause: Bool) {}
    func closePlayer(playerId: String) {}
    func mutePlayerAudio(playerId: String, mute: Bool) {}
    func playerSeek(to time: Int, playerId: String) {}
    func playerPosition(playerId: String) -> Int64 { -1 }
}
