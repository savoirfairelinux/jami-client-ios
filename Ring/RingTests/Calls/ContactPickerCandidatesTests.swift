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

final class ContactPickerCandidatesTests: XCTestCase {

    func testPeersInCallsCoverLiveCallsAndTheirConferenceParticipants() {
        var conferenceCall = CallTestFixtures.call(peerUri: "jami:" + jamiId2 + "@ring.dht")
        conferenceCall.conferenceId = CallTestFixtures.conferenceId
        let endedCall = CallTestFixtures.call(id: CallTestFixtures.secondaryCallId,
                                              peerUri: jamiId4,
                                              status: .terminated(.over))
        var state = CallSystemState()
        state.calls = [conferenceCall.id: conferenceCall, endedCall.id: endedCall]
        state.conferences[CallTestFixtures.conferenceId] = CallTestFixtures.conference(
            participants: [CallTestFixtures.participant(uri: jamiId3)])

        XCTAssertEqual(state.peerHashesInCalls, [jamiId2, jamiId3])
    }

    func testPickableContactsDropBannedContactsAndPeersInCalls() {
        let inCall = ContactModel(withDictionary: ["id": jamiId2])
        let banned = ContactModel(withDictionary: ["id": jamiId3, "banned": "true"])
        let available = ContactModel(withDictionary: ["id": jamiId4])

        let pickable = ContactPickerViewModel.pickableContacts([inCall, banned, available],
                                                               excluding: [jamiId2])

        XCTAssertEqual(pickable.map(\.hash), [jamiId4])
    }
}
