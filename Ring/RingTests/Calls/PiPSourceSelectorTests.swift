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
    private let remoteId = CallTestFixtures.peerUri
    private let secondaryRemoteId = CallTestFixtures.secondaryPeerUri
    private let tertiaryRemoteId = CallTestFixtures.tertiaryPeerUri

    private func call(id: String = CallTestFixtures.callId.raw,
                      peerUri: String = CallTestFixtures.peerUri,
                      status: CallStatus = .current,
                      media: [MediaItem] = []) -> CallState {
        return CallTestFixtures.call(id: CallId(raw: id),
                                     conversationId: nil,
                                     peerUri: peerUri,
                                     status: status,
                                     media: media)
    }

    private func video(muted: Bool = false) -> MediaItem {
        MediaItem.video(muted: muted)
    }

    private func audio() -> MediaItem {
        MediaItem.audio()
    }

    private func conference(_ participants: [ConferenceParticipantInfo])
    -> ConferenceState {
        CallTestFixtures.conference(conversationId: nil, participants: participants)
    }

    private func participant(_ uri: String,
                             sinkId: String? = nil,
                             videoMuted: Bool = false,
                             voiceActivity: Bool = false) -> ConferenceParticipantInfo {
        CallTestFixtures.participant(uri: uri,
                                     sinkId: sinkId,
                                     videoMuted: videoMuted,
                                     voiceActivity: voiceActivity)
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
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.callId.raw)))
    }

    func testPeerVideoStillCountsWhileOurCameraIsMuted() {
        XCTAssertEqual(select(call: call(media: [audio(), video(muted: true)])),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.callId.raw)),
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
                            conference: conference([participant(localId)])),
                     "a conference where we are alone has nobody to show")
    }

    func testConferenceOfTwoShowsTheOtherParticipant() {
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conference([participant(localId),
                                                      participant(remoteId,
                                                                  sinkId: CallTestFixtures.remoteSinkId)])),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.remoteSinkId)))
    }

    func testEmptyUriHostCountsAsOurself() {
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conference([participant(String()),
                                                      participant(remoteId,
                                                                  sinkId: CallTestFixtures.remoteSinkId)])),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.remoteSinkId)))
    }

    func testConferenceFollowsTheSpeaker() {
        let conf = conference([participant(localId),
                               participant(remoteId),
                               participant(secondaryRemoteId,
                                           sinkId: CallTestFixtures.secondaryRemoteSinkId,
                                           voiceActivity: true),
                               participant(tertiaryRemoteId)])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: secondaryRemoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId)))
    }

    func testMutedSpeakerIsSkippedForParticipantWithVideo() {
        let conf = conference([participant(localId),
                               participant(remoteId,
                                           videoMuted: true,
                                           voiceActivity: true),
                               participant(secondaryRemoteId,
                                           sinkId: CallTestFixtures.secondaryRemoteSinkId)])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: secondaryRemoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId)))
    }

    func testAllRemoteVideoMutedHasNothingToShow() {
        let conf = conference([participant(localId),
                               participant(remoteId, videoMuted: true),
                               participant(secondaryRemoteId, videoMuted: true)])
        XCTAssertNil(select(call: call(media: [audio(), video()]), conference: conf))
    }

    func testParticipantWithoutSinkIsIgnored() {
        let conf = conference([participant(localId),
                               participant(remoteId, sinkId: String()),
                               participant(secondaryRemoteId,
                                           sinkId: CallTestFixtures.secondaryRemoteSinkId)])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: secondaryRemoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId)))
    }

    func testOurOwnVoiceDoesNotTakeOverPictureInPicture() {
        let conf = conference([participant(localId, voiceActivity: true),
                               participant(remoteId, sinkId: CallTestFixtures.remoteSinkId),
                               participant(secondaryRemoteId)])
        XCTAssertEqual(select(call: call(media: [audio(), video()]), conference: conf),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.remoteSinkId)),
                       "we never watch ourselves in picture in picture")
    }

    func testTheLastSpeakerStaysWhenEveryoneGoesQuiet() {
        let conf = conference([participant(localId),
                               participant(remoteId),
                               participant(secondaryRemoteId),
                               participant(tertiaryRemoteId,
                                           sinkId: CallTestFixtures.secondaryRemoteSinkId)])
        let current = PiPSourceSelector.Selection(uri: tertiaryRemoteId,
                                                  sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       current, "silence must not shuffle the picture-in-picture subject")
    }

    func testRetainedSpeakerRequiresTheSameSink() {
        let conf = conference([participant(localId),
                               participant(remoteId,
                                           sinkId: CallTestFixtures.secondaryRemoteSinkId),
                               participant(secondaryRemoteId)])
        let current = PiPSourceSelector.Selection(uri: remoteId,
                                                  sinkId: SinkId(raw: CallTestFixtures.remoteSinkId))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId)),
                       "a rejoined participant must not retain their stale decoder sink")
    }

    func testDepartedSpeakerFallsBackToTheFirstRemoteParticipant() {
        let conf = conference([participant(localId),
                               participant(remoteId,
                                           sinkId: CallTestFixtures.remoteSinkId),
                               participant(secondaryRemoteId)])
        let current = PiPSourceSelector.Selection(uri: tertiaryRemoteId,
                                                  sinkId: SinkId(raw: CallTestFixtures.secondaryRemoteSinkId))
        XCTAssertEqual(select(call: call(media: [audio(), video()]),
                              conference: conf, current: current),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.remoteSinkId)))
    }

    func testConferenceIgnoresTheCallMediaGate() {
        let conf = conference([participant(localId),
                               participant(remoteId, sinkId: CallTestFixtures.remoteSinkId)])
        XCTAssertEqual(select(call: call(media: [audio()]), conference: conf),
                       PiPSourceSelector.Selection(uri: remoteId,
                                                   sinkId: SinkId(raw: CallTestFixtures.remoteSinkId)),
                       "conference participants publish their own streams")
    }

    func testTerminatedConferenceHasNothingToShow() {
        let conf = conference([participant(localId),
                               participant(remoteId)])
        XCTAssertNil(select(call: call(status: .terminated(.endedLocally),
                                       media: [audio(), video()]),
                            conference: conf))
    }
}
