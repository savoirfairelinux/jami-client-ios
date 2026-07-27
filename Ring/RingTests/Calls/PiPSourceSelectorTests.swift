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

final class PiPSourceSelectorTests: XCTestCase {

    private let localId = jamiId1

    private func call(id: String = "c1", peerUri: String = "bob",
                      status: CallStatus = .current,
                      media: [MediaItem] = []) -> CallState {
        var state = CallState(id: CallId(raw: id), accountId: accountId1,
                              direction: .outgoing, status: status)
        state.peerUri = peerUri
        state.media = media
        return state
    }

    private func video(muted: Bool = false) -> MediaItem {
        MediaItem.video(muted: muted)
    }

    private func audio() -> MediaItem {
        MediaItem.audio()
    }

    private func conference(_ participants: [ConferenceParticipantInfo])
    -> ConferenceState {
        ConferenceState(id: ConfId(raw: "conf1"), accountId: accountId1,
                        participants: participants)
    }

    private func select(call: CallState?, conference: ConferenceState? = nil,
                        current: PiPSourceSelector.Selection? = nil)
    -> PiPSourceSelector.Selection? {
        PiPSourceSelector.select(call: call, conference: conference,
                                 localJamiId: localId, current: current)
    }

    // MARK: - Direct calls

    func testAudioOnlyCallHasNothingToShow() {
        XCTAssertNil(select(call: call(media: [audio()])),
                     "a call with no negotiated video cannot feed picture in picture")
    }

    func testRingingVideoCallHasNothingToShow() {
        XCTAssertNil(select(call: call(status: .ringing, media: [audio(), video()])),
                     "the peer sink carries no frames before the call is answered")
    }

    func testOngoingVideoCallShowsThePeer() {
        XCTAssertEqual(select(call: call(media: [audio(), video()])),
                       PiPSourceSelector.Selection(uri: "bob",
                                                   sinkId: SinkId(raw: "c1")))
    }

    func testPeerVideoStillCountsWhileOurCameraIsMuted() {
        XCTAssertEqual(select(call: call(media: [audio(), video(muted: true)])),
                       PiPSourceSelector.Selection(uri: "bob",
                                                   sinkId: SinkId(raw: "c1")),
                       "muting our own camera does not stop the peer's stream")
    }

    func testTerminatedCallHasNothingToShow() {
        XCTAssertNil(select(call: call(status: .terminated(.endedLocally),
                                       media: [audio(), video()])))
    }

    func testNoCallHasNothingToShow() {
        XCTAssertNil(select(call: nil))
    }

    // MARK: - Conferences

    func testConferenceOfOneIsEmpty() {
        XCTAssertNil(select(call: call(media: [audio(), video()]),
                            conference: conference([CallTestFixtures.participant(uri: localId)])),
                     "a conference where we are alone has nobody to show")
    }

    func testConferenceOfTwoShowsTheOtherParticipant() {
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conference([CallTestFixtures.participant(uri: localId),
                                                      CallTestFixtures.participant(uri: "alice")])),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice")))
    }

    func testEmptyUriHostCountsAsOurself() {
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conference([CallTestFixtures.participant(uri: ""),
                                                      CallTestFixtures.participant(uri: "alice")])),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice")))
    }

    func testConferenceFollowsTheSpeaker() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice"),
                               CallTestFixtures.participant(uri: "bob", voiceActivity: true),
                               CallTestFixtures.participant(uri: "carol")])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: "bob",
                                                   sinkId: SinkId(raw: "sink_bob")))
    }

    func testMutedSpeakerIsSkippedForParticipantWithVideo() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice", videoMuted: true,
                                                            voiceActivity: true),
                               CallTestFixtures.participant(uri: "bob")])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: "bob",
                                                   sinkId: SinkId(raw: "sink_bob")))
    }

    func testAllRemoteVideoMutedHasNothingToShow() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice", videoMuted: true),
                               CallTestFixtures.participant(uri: "bob", videoMuted: true)])
        XCTAssertNil(select(call: call(media: [audio(), video()]), conference: conf))
    }

    func testParticipantWithoutSinkIsIgnored() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice", sinkId: ""),
                               CallTestFixtures.participant(uri: "bob")])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: "bob",
                                                   sinkId: SinkId(raw: "sink_bob")))
    }

    func testOurOwnVoiceDoesNotTakeOverPictureInPicture() {
        let conf = conference([CallTestFixtures.participant(uri: localId,
                                                            voiceActivity: true),
                               CallTestFixtures.participant(uri: "alice"),
                               CallTestFixtures.participant(uri: "bob")])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice")),
                       "we never watch ourselves in picture in picture")
    }

    func testTheLastSpeakerStaysWhenEveryoneGoesQuiet() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice"),
                               CallTestFixtures.participant(uri: "bob"),
                               CallTestFixtures.participant(uri: "carol")])
        let current = PiPSourceSelector.Selection(uri: "carol",
                                                  sinkId: SinkId(raw: "sink_carol"))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       current, "silence must not shuffle the picture-in-picture subject")
    }

    func testRetainedSpeakerRequiresTheSameSink() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice",
                                                            sinkId: "sink_alice_new"),
                               CallTestFixtures.participant(uri: "bob")])
        let current = PiPSourceSelector.Selection(uri: "alice",
                                                  sinkId: SinkId(raw: "sink_alice_old"))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice_new")),
                       "a rejoined participant must not retain their stale decoder sink")
    }

    func testDepartedSpeakerFallsBackToTheFirstRemoteParticipant() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice"),
                               CallTestFixtures.participant(uri: "bob")])
        let current = PiPSourceSelector.Selection(uri: "carol",
                                                  sinkId: SinkId(raw: "sink_carol"))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice")))
    }

    func testConferenceIgnoresTheCallMediaGate() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice")])
        XCTAssertEqual(select(call: call(media: [audio()]), conference: conf),
                       PiPSourceSelector.Selection(uri: "alice",
                                                   sinkId: SinkId(raw: "sink_alice")),
                       "conference participants publish their own streams")
    }

    func testTerminatedConferenceHasNothingToShow() {
        let conf = conference([CallTestFixtures.participant(uri: localId),
                               CallTestFixtures.participant(uri: "alice")])
        XCTAssertNil(select(call: call(status: .terminated(.endedLocally),
                                       media: [audio(), video()]),
                            conference: conf))
    }
}
