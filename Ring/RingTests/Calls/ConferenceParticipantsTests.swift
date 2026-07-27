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

    private func conference(_ participants: [ConferenceParticipantInfo],
                            isHost: Bool = false,
                            layout: ConferenceLayoutMode = .grid) -> ConferenceState {
        ConferenceState(id: ConfId(raw: "conf1"), accountId: accountId1,
                        participants: participants, layout: layout, isHost: isHost)
    }

    private func rows(_ conference: ConferenceState) -> [ConferenceParticipantRow] {
        ConferenceParticipants.rows(from: conference, localJamiId: localId)
    }

    private func row(_ uri: String, in rows: [ConferenceParticipantRow]) -> ConferenceParticipantRow? {
        rows.first { $0.uri == uri }
    }

    func testLocalParticipantComesFirst() {
        let list = rows(conference([CallTestFixtures.participant(uri: "alice"),
                                    CallTestFixtures.participant(uri: localId)]))
        XCTAssertEqual(list.first?.uri, localId)
        XCTAssertTrue(list.first?.isLocal == true)
    }

    func testHostSeesModerationOnOthers() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: "alice")], isHost: true))
        let alice = row("alice", in: list)?.actions ?? []
        XCTAssertTrue(alice.contains(.muteAudio))
        XCTAssertTrue(alice.contains(.setModerator))
        XCTAssertTrue(alice.contains(.endCall))
        XCTAssertTrue(alice.contains(.maximize), "a moderator may spotlight")
    }

    func testModeratorSeesMuteAndKickButNotSetModerator() {
        let local = CallTestFixtures.participant(uri: localId, isModerator: true)
        let list = rows(conference([local,
                                    CallTestFixtures.participant(uri: "alice")], isHost: false))
        let alice = row("alice", in: list)?.actions ?? []
        XCTAssertTrue(alice.contains(.muteAudio))
        XCTAssertTrue(alice.contains(.endCall))
        XCTAssertTrue(alice.contains(.maximize))
        XCTAssertFalse(alice.contains(.setModerator), "only the host promotes moderators")
    }

    func testRegularParticipantHasNoActionsOnOthers() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: "alice")], isHost: false))
        XCTAssertEqual(row("alice", in: list)?.actions, [],
                       "layout is shared conference state — a non-moderator "
                        + "can't recompose it, nor moderate others")
    }

    func testEmptyUriHostIsRecognizedAsLocalModerator() {
        let list = rows(conference([CallTestFixtures.participant(uri: "", isModerator: true),
                                    CallTestFixtures.participant(uri: "alice")], isHost: false))
        let host = list.first
        XCTAssertEqual(host?.isLocal, true, "the empty-uri cell is our own host cell")
        XCTAssertEqual(host?.uri, localId, "it resolves to the local jami id")
        let alice = row("alice", in: list)?.actions ?? []
        XCTAssertTrue(alice.contains(.muteAudio))
        XCTAssertTrue(alice.contains(.endCall), "a host may moderate others")
    }

    func testSelfCanMuteButNotSpotlightWhenNotModerator() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: "alice")], isHost: false))
        let localActions = row(localId, in: list)?.actions ?? []
        XCTAssertTrue(localActions.contains(.muteAudio), "you can always mute yourself")
        XCTAssertFalse(localActions.contains(.maximize),
                       "spotlight recomposes the room — moderator-only")
    }

    func testStatusFieldsMapFromParticipant() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId),
                                    CallTestFixtures.participant(uri: "alice",
                                                                 handRaised: true,
                                                                 audioLocalMuted: true,
                                                                 recording: true,
                                                                 voiceActivity: true)]))
        let alice = row("alice", in: list)
        XCTAssertEqual(alice?.isHandRaised, true)
        XCTAssertEqual(alice?.isAudioMuted, true)
        XCTAssertEqual(alice?.isRecording, true)
        XCTAssertEqual(alice?.isSpeaking, true)
    }

    func testPendingRowsCarryTheLegToHangUpAndItsProgress() {
        let invites = [PendingConferenceInvite(callId: CallId(raw: "c1"), peerUri: "bob",
                                               status: .ringing)]
        let pending = ConferenceParticipants.pendingRows(from: invites)
        XCTAssertEqual(pending.map(\.uri), ["bob"])
        XCTAssertEqual(pending.first?.callId, CallId(raw: "c1"),
                       "cancelling the invite hangs up its own leg")
        XCTAssertEqual(pending.first?.status, .ringing)
    }

    func testInviteesAreNotListedAmongJoinedParticipants() {
        let list = rows(conference([CallTestFixtures.participant(uri: localId)]))
        XCTAssertEqual(list.map(\.uri), [localId],
                       "an invitee has not joined the conference yet")
    }

    func testOneToOneCallIsListedWithoutModeration() {
        var call = CallState(id: CallId(raw: "call1"), accountId: accountId1,
                             direction: .outgoing, peerUri: "alice", status: .current)
        call.media = [.audio(muted: true)]

        let list = ConferenceParticipants.rows(from: call, localJamiId: localId)

        XCTAssertEqual(list.map(\.uri), [localId, "alice"], "we come first")
        XCTAssertEqual(list.first?.isAudioMuted, true)
        XCTAssertEqual(list.map(\.actions), [[], []],
                       "there is no conference to moderate")
    }
}
