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

final class CallHeaderModelTests: XCTestCase {

    private let localId = jamiId1
    private let peerId = CallTestFixtures.peerUri

    private func call(peerUri: String, displayName: String = "") -> CallState {
        var call = CallTestFixtures.call(peerUri: peerUri, status: .current)
        call.displayName = displayName
        return call
    }

    private func conference(_ uris: [String]) -> ConferenceState {
        CallTestFixtures.conference(
            participants: uris.map { CallTestFixtures.participant(uri: $0) })
    }

    private func header(call: CallState?, conference: ConferenceState? = nil,
                        pending: [PendingParticipantRow] = [],
                        peerName: String = "") -> CallHeaderModel {
        let rows: [ConferenceParticipantRow]
        if let conference = conference {
            rows = ConferenceParticipants.rows(from: conference,
                                               localJamiId: localId,
                                               peerUri: call?.peerUri ?? "")
        } else if let call = call {
            rows = ConferenceParticipants.rows(from: call, localJamiId: localId)
        } else {
            rows = []
        }
        return CallHeaderModel(call: call, isConference: conference != nil, rows: rows,
                               pending: pending, peerName: peerName)
    }

    private func pendingRow(_ uri: String) -> PendingParticipantRow {
        PendingParticipantRow(id: uri, callId: CallTestFixtures.secondaryCallId, uri: uri,
                              status: .connecting)
    }

    // MARK: - One to one

    func testOneToOneShowsTheResolvedPeerName() {
        let model = header(call: call(peerUri: peerId, displayName: profileName1),
                           peerName: profileName2)
        XCTAssertEqual(model.title, profileName2,
                       "a name resolved from the profile wins over the call's own")
        XCTAssertFalse(model.showsRoster, "two people are not a roster worth opening")
        XCTAssertTrue(model.avatars.isEmpty)
    }

    func testOneToOneFallsBackToTheJamiIdUntruncated() {
        let model = header(call: call(peerUri: peerId))
        XCTAssertEqual(model.title, peerId,
                       "the view truncates for display — the model keeps the whole id")
        XCTAssertTrue(model.titleIsIdentifier,
                      "both ends of an id matter, so the view must truncate the middle")
    }

    func testAnUnresolvedProfileNeverReplacesTheNameTheCallCameWith() {
        let model = header(call: call(peerUri: peerId, displayName: profileName1),
                           peerName: peerId)
        XCTAssertEqual(model.title, profileName1,
                       "a profile that resolved to nothing reports the hash — "
                        + "that is not an improvement on a name we already had")
        XCTAssertFalse(model.titleIsIdentifier,
                       "a name reads from the front — truncate its tail, not its middle")
    }

    func testAnUnansweredInviteStopsTheHeaderNamingOnePerson() {
        let model = header(call: call(peerUri: peerId, displayName: profileName1),
                           pending: [pendingRow(CallTestFixtures.secondaryPeerUri)])
        XCTAssertTrue(model.showsRoster, "a pending invite can still be cancelled")
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("2"),
                       "the call is already more than two people — naming one is a lie")
        XCTAssertEqual(model.avatars.map(\.uri),
                       [peerId, CallTestFixtures.secondaryPeerUri],
                       "the invitee's face is the sign the call is growing")
        XCTAssertEqual(model.avatars.map(\.isPending), [false, true],
                       "an invitee is on the way, not here — their face must say so")
        XCTAssertTrue(model.isInviting)
    }

    func testAnUnansweredInviteLeavesTheDurationRunning() {
        var ongoing = call(peerUri: peerId, displayName: profileName1)
        ongoing.startedAt = Date()
        ongoing.pendingInvites = [
            PendingConferenceInvite(
                callId: CallTestFixtures.secondaryCallId,
                peerUri: CallTestFixtures.secondaryPeerUri,
                status: .ringing
            )
        ]
        XCTAssertNotNil(
            CallHeaderModel.statusLine(for: ongoing)
                .range(of: "^[0-9]{2}:[0-9]{2}$", options: .regularExpression),
            "inviting someone does not interrupt the call being timed — "
                + "the pending face carries the invite"
        )
    }

    func testAnInviteIsStillAnnouncedWhenItsFaceDoesNotFit() {
        let model = header(call: call(peerUri: peerId),
                           conference: conference([localId, peerId,
                                                   CallTestFixtures.secondaryPeerUri,
                                                   CallTestFixtures.tertiaryPeerUri]),
                           pending: [pendingRow(jamiId5)])
        XCTAssertFalse(model.avatars.contains { $0.isPending },
                       "precondition: the invitee is past the last drawn face")
        XCTAssertTrue(model.isInviting,
                      "VoiceOver has no faces to read — it needs the state in words")
    }

    // MARK: - Conference

    func testConferenceIsTitledByCountNeverByAMember() {
        let uris = [localId, peerId, CallTestFixtures.secondaryPeerUri,
                    CallTestFixtures.tertiaryPeerUri]
        let model = header(call: call(peerUri: peerId, displayName: profileName1),
                           conference: conference(uris),
                           peerName: profileName1)
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("4"),
                       "a conference has no name — no member may stand in for it, "
                        + "not even the one whose name is already resolved")
        XCTAssertTrue(model.showsRoster)
    }

    func testTheCountIsWhoIsHereNotWhoWasInvited() {
        let model = header(call: call(peerUri: peerId),
                           conference: conference([localId, peerId]),
                           pending: [pendingRow(CallTestFixtures.secondaryPeerUri)])
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("2"),
                       "someone still ringing is not in the call — and the roster "
                        + "sheet counts them in its own Invited section")
    }

    func testAPeerOnTwoDevicesGetsOneAvatar() {
        let conference = CallTestFixtures.conference(
            participants: [CallTestFixtures.participant(uri: localId),
                           CallTestFixtures.participant(uri: peerId, device: deviceId1),
                           CallTestFixtures.participant(uri: peerId, device: deviceId2),
                           CallTestFixtures.participant(uri: CallTestFixtures.secondaryPeerUri)])
        let model = header(call: call(peerUri: peerId), conference: conference)
        XCTAssertEqual(model.avatars.map(\.uri),
                       [peerId, CallTestFixtures.secondaryPeerUri],
                       "one face per person — a second device is not a second face")
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("3"),
                       "a second device is not a second person in the count")
    }

    func testConferenceShowsAtMostThreeAvatarsAndNeverTheLocalOne() {
        let uris = [localId, peerId, CallTestFixtures.secondaryPeerUri,
                    CallTestFixtures.tertiaryPeerUri, jamiId5]
        let model = header(call: call(peerUri: peerId), conference: conference(uris))
        XCTAssertEqual(model.avatars.map(\.uri),
                       [peerId, CallTestFixtures.secondaryPeerUri,
                        CallTestFixtures.tertiaryPeerUri])
        XCTAssertFalse(model.avatars.contains { $0.uri == localId },
                       "your own face tells you nothing about who else is here")
    }
}
