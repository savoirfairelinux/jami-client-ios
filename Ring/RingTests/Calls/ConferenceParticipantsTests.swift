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

import XCTest
@testable import Ring

final class ConferenceParticipantsTests: XCTestCase {

    private let localId = jamiId1
    private let remoteId = CallTestFixtures.peerUri

    private func conference(_ participants: [ConferenceParticipantInfo],
                            isHost: Bool = false,
                            layout: ConferenceLayoutMode = .grid) -> ConferenceState {
        CallTestFixtures.conference(conversationId: nil,
                                    participants: participants,
                                    layout: layout,
                                    isHost: isHost)
    }

    private func rows(_ conference: ConferenceState) -> [ConferenceParticipantRow] {
        ConferenceParticipants.rows(from: conference, localJamiId: localId)
    }

    private func row(_ uri: String, in rows: [ConferenceParticipantRow]) -> ConferenceParticipantRow? {
        rows.first { $0.uri == uri }
    }

    func testLocalParticipantComesFirst() {
        let list = rows(conference([CallTestFixtures.participant(uri: remoteId),
                                    CallTestFixtures.participant(uri: localId)]))
        XCTAssertEqual(list.first?.uri, localId)
        XCTAssertTrue(list.first?.isLocal == true)
    }

    func testHostSeesModerationOnOthers() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: remoteId)], isHost: true))
        let remote = row(remoteId, in: list)?.actions ?? []
        XCTAssertTrue(remote.contains(.muteAudio))
        XCTAssertTrue(remote.contains(.setModerator))
        XCTAssertTrue(remote.contains(.endCall))
        XCTAssertTrue(remote.contains(.maximize), "a moderator may spotlight")
    }

    func testModeratorSeesMuteAndKickButNotSetModerator() {
        let local = CallTestFixtures.participant(uri: localId, isModerator: true)
        let list = rows(conference([local,
                                    CallTestFixtures.participant(uri: remoteId)], isHost: false))
        let remote = row(remoteId, in: list)?.actions ?? []
        XCTAssertTrue(remote.contains(.muteAudio))
        XCTAssertTrue(remote.contains(.endCall))
        XCTAssertTrue(remote.contains(.maximize))
        XCTAssertFalse(remote.contains(.setModerator), "only the host promotes moderators")
    }

    func testRegularParticipantHasNoActionsOnOthers() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: remoteId)], isHost: false))
        XCTAssertEqual(row(remoteId, in: list)?.actions, [],
                       "layout is shared conference state — a non-moderator "
                        + "can't recompose it, nor moderate others")
    }

    func testEmptyUriHostIsRecognizedAsLocalModerator() {
        let list = rows(conference([CallTestFixtures.participant(uri: String(), isModerator: true),
                                    CallTestFixtures.participant(uri: remoteId)], isHost: false))
        let host = list.first
        XCTAssertEqual(host?.isLocal, true, "the empty-uri cell is our own host cell")
        XCTAssertEqual(host?.uri, localId, "it resolves to the local jami id")
        let remote = row(remoteId, in: list)?.actions ?? []
        XCTAssertTrue(remote.contains(.muteAudio))
        XCTAssertTrue(remote.contains(.endCall), "a host may moderate others")
    }

    func testSelfCanMuteButNotSpotlightWhenNotModerator() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: remoteId)], isHost: false))
        let localActions = row(localId, in: list)?.actions ?? []
        XCTAssertTrue(localActions.contains(.muteAudio), "you can always mute yourself")
        XCTAssertFalse(localActions.contains(.maximize),
                       "spotlight recomposes the room — moderator-only")
    }

    func testStatusFieldsMapFromParticipant() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: remoteId,
                                                                 handRaised: true,
                                                                 audioLocalMuted: true,
                                                                 recording: true,
                                                                 voiceActivity: true)]))
        let remote = row(remoteId, in: list)
        XCTAssertEqual(remote?.isHandRaised, true)
        XCTAssertEqual(remote?.isAudioMuted, true)
        XCTAssertEqual(remote?.isRecording, true)
        XCTAssertEqual(remote?.isSpeaking, true)
    }

    func testPendingRowsCarryTheLegToHangUpAndItsProgress() {
        let invites = [PendingConferenceInvite(callId: CallTestFixtures.callId,
                                               peerUri: remoteId,
                                               status: .ringing)]
        let pending = ConferenceParticipants.pendingRows(from: invites)
        XCTAssertEqual(pending.map(\.uri), [remoteId])
        XCTAssertEqual(pending.first?.callId, CallTestFixtures.callId,
                       "cancelling the invite hangs up its own leg")
        XCTAssertEqual(pending.first?.status, .ringing)
    }

    func testPendingRowUsesCallOrientedPresentation() {
        let connecting = PendingParticipantRow(id: CallTestFixtures.callId.raw,
                                               callId: CallTestFixtures.callId,
                                               uri: remoteId, status: .connecting)
        let ringing = PendingParticipantRow(id: CallTestFixtures.callId.raw,
                                            callId: CallTestFixtures.callId,
                                            uri: remoteId, status: .ringing)
        let fallback = PendingParticipantRow(id: CallTestFixtures.callId.raw,
                                             callId: CallTestFixtures.callId,
                                             uri: remoteId, status: .incoming)

        XCTAssertEqual(connecting.progressText, L10n.Calls.connecting)
        XCTAssertEqual(ringing.progressText, L10n.Calls.ringing)
        XCTAssertEqual(fallback.progressText, L10n.Calls.calling)
        XCTAssertEqual(fallback.stopCallingLabel(displayName: "Bob"),
                       L10n.Calls.stopCalling("Bob"))
    }

    func testInviteesAreNotListedAmongJoinedParticipants() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId)]))
        XCTAssertEqual(list.map(\.uri), [localId],
                       "an invitee has not joined the conference yet")
    }

    func testOneToOneCallIsListedWithoutModeration() {
        var call = CallTestFixtures.call(conversationId: nil,
                                         peerUri: remoteId,
                                         status: .current)
        call.media = [.audio(muted: true)]

        let list = ConferenceParticipants.rows(from: call, localJamiId: localId)

        XCTAssertEqual(list.map(\.uri), [localId, remoteId], "we come first")
        XCTAssertEqual(list.first?.isAudioMuted, true)
        XCTAssertEqual(list.map(\.actions), [[], []],
                       "there is no conference to moderate")
    }
}
