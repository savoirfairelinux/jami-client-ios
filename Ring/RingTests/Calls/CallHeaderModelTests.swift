/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

    private let localId = "me"
    private let jamiId = jamiId1

    private func call(peerUri: String, displayName: String = "") -> CallState {
        var call = CallTestFixtures.call(peerUri: peerUri, status: .current)
        call.displayName = displayName
        return call
    }

    private func participant(_ uri: String) -> ConferenceParticipantInfo {
        CallTestFixtures.participant(uri: uri)
    }

    private func conference(_ uris: [String]) -> ConferenceState {
        CallTestFixtures.conference(participants: uris.map(participant))
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
        let model = header(call: call(peerUri: "bob", displayName: "Bob"),
                           peerName: "Bob Martin")
        XCTAssertEqual(model.title, "Bob Martin",
                       "a name resolved from the profile wins over the call's own")
        XCTAssertFalse(model.showsRoster, "two people are not a roster worth opening")
        XCTAssertTrue(model.avatarURIs.isEmpty)
    }

    func testOneToOneFallsBackToTheJamiIdUntruncated() {
        let model = header(call: call(peerUri: jamiId))
        XCTAssertEqual(model.title, jamiId,
                       "the view truncates for display — the model keeps the whole id")
        XCTAssertTrue(model.titleIsIdentifier,
                      "both ends of an id matter, so the view must truncate the middle")
    }

    func testAnUnresolvedProfileNeverReplacesTheNameTheCallCameWith() {
        let model = header(call: call(peerUri: jamiId, displayName: "Bob"),
                           peerName: jamiId)
        XCTAssertEqual(model.title, "Bob",
                       "a profile that resolved to nothing reports the hash — "
                        + "that is not an improvement on a name we already had")
        XCTAssertFalse(model.titleIsIdentifier)
    }

    func testAResolvedNameIsNotTreatedAsAnIdentifier() {
        let model = header(call: call(peerUri: jamiId), peerName: "Bob Martin")
        XCTAssertFalse(model.titleIsIdentifier,
                       "a name reads from the front — truncate its tail, not its middle")
    }

    func testAnUnansweredInviteStopsTheHeaderNamingOnePerson() {
        let model = header(call: call(peerUri: "bob", displayName: "Bob"),
                           pending: [pendingRow("alice")])
        XCTAssertTrue(model.showsRoster, "a pending invite can still be cancelled")
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("2"),
                       "the call is already more than two people — naming one is a lie")
        XCTAssertEqual(model.avatarURIs, ["bob", "alice"],
                       "the invitee's face is the sign the call is growing")
    }

    func testAnUnansweredInviteIsAnnouncedOnTheStatusLine() {
        var ongoing = call(peerUri: "bob", displayName: "Bob")
        ongoing.startedAt = Date()
        ongoing.pendingInvites = [PendingConferenceInvite(callId: CallTestFixtures.secondaryCallId,
                                                          peerUri: "alice",
                                                          status: .ringing)]
        XCTAssertEqual(CallHeaderModel.statusLine(for: ongoing), L10n.Calls.inviting,
                       "an outstanding invite matters more than the elapsed time")
    }

    // MARK: - Conference

    func testConferenceIsTitledByCountNeverByAMember() {
        let uris = [localId, "alice", "bob", "carol", "dave"]
        let model = header(call: call(peerUri: "alice", displayName: "Alice"),
                           conference: conference(uris),
                           peerName: "Alice")
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("5"),
                       "a conference has no name — no member may stand in for it, "
                        + "not even the one whose name is already resolved")
        XCTAssertTrue(model.showsRoster)
    }

    func testTheCountIsWhoIsHereNotWhoWasInvited() {
        let model = header(call: call(peerUri: "alice"),
                           conference: conference([localId, "alice"]),
                           pending: [pendingRow("bob")])
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("2"),
                       "someone still ringing is not in the call — and the roster "
                        + "sheet counts them in its own Invited section")
    }

    func testAPeerOnTwoDevicesGetsOneAvatar() {
        let conference = CallTestFixtures.conference(
            participants: [participant(localId),
                           CallTestFixtures.participant(uri: "alice", device: deviceId1),
                           CallTestFixtures.participant(uri: "alice", device: deviceId2),
                           participant("bob")])
        let model = header(call: call(peerUri: "alice"), conference: conference)
        XCTAssertEqual(model.avatarURIs, ["alice", "bob"],
                       "one face per person — a second device is not a second face")
        XCTAssertEqual(model.title, L10n.Calls.participantsInCall("3"),
                       "a second device is not a second person in the count")
    }

    func testConferenceShowsAtMostThreeAvatarsAndNeverTheLocalOne() {
        let uris = [localId, "alice", "bob", "carol", "dave"]
        let model = header(call: call(peerUri: "alice"), conference: conference(uris))
        XCTAssertEqual(model.avatarURIs, ["alice", "bob", "carol"])
        XCTAssertFalse(model.avatarURIs.contains(localId),
                       "your own face tells you nothing about who else is here")
    }
}
