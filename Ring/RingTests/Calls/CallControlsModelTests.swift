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

final class CallControlsModelTests: XCTestCase {

    private func call(status: CallStatus = .current,
                      media: [MediaItem] = [.audio(), .video()],
                      pending: [MediaItem]? = nil,
                      isSip: Bool = false,
                      conference: ConferenceState? = nil) -> CallControlsModel {
        var state = CallTestFixtures.call(status: status,
                                          media: media)
        state.pendingMediaRequest = pending
        state.conferenceId = conference?.id
        return CallControlsModel(call: state, conference: conference,
                                 isSipAccount: isSip)
    }

    func testMuteStatesReflectLibJamiConfirmedMedia() {
        let model = call(media: [.audio(muted: true), .video(muted: false)])
        XCTAssertTrue(model.isAudioMuted)
        XCTAssertFalse(model.isVideoMuted)
    }

    func testMediaTogglesDisabledWhilePendingRequest() {
        let model = call(pending: [.audio(muted: true), .video()])
        XCTAssertFalse(model.canToggleMedia)
        XCTAssertTrue(call(pending: nil).canToggleMedia)
    }

    func testMediaTogglesRequireOngoingCall() {
        XCTAssertFalse(call(status: .ringing).canToggleMedia)
        XCTAssertFalse(call(status: .incoming).canToggleMedia)
        XCTAssertTrue(call(status: .held(side: .peer)).canToggleMedia)
    }

    func testCameraControlsOnlyWithUnmutedVideo() {
        XCTAssertTrue(call().canSwitchCamera)
        XCTAssertFalse(call(media: [.audio()]).canSwitchCamera)
        XCTAssertFalse(call(media: [.audio(), .video(muted: true)]).canSwitchCamera)
    }

    func testDialpadOnlyForSipAccounts() {
        XCTAssertTrue(call(isSip: true).showsDialpad)
        XCTAssertFalse(call(isSip: false).showsDialpad)
    }

    func testHoldAvailability() {
        XCTAssertFalse(call(status: .current).canHold,
                       "Jami calls do not expose SIP hold")
        XCTAssertTrue(call(status: .current, isSip: true).canHold)
        XCTAssertFalse(call(status: .held(side: .local), isSip: true).canHold)
        XCTAssertTrue(call(status: .held(side: .local), isSip: true).canResume)
        XCTAssertFalse(call(status: .held(side: .peer), isSip: true).canResume)
    }

    func testSipConferenceUsesHostMediaAndConferenceHold() {
        let conference = CallTestFixtures.conference(
            media: [.audio(muted: true), .video(muted: false)],
            isHost: true, lifecycle: .activeAttached)

        let model = call(media: [.audio(), .video(muted: true)],
                         isSip: true, conference: conference)

        XCTAssertTrue(model.isAudioMuted)
        XCTAssertFalse(model.isVideoMuted)
        XCTAssertTrue(model.canHold)
        XCTAssertFalse(model.canResume)
    }

    func testDetachedSipConferenceCanResume() {
        let conference = CallTestFixtures.conference(
            media: [.audio(), .video()], isHost: true,
            lifecycle: .activeDetached)

        let model = call(isSip: true, conference: conference)

        XCTAssertFalse(model.canHold)
        XCTAssertTrue(model.canResume)
    }

    func testJamiConferenceDoesNotExposeSipHold() {
        let conference = CallTestFixtures.conference(
            media: [.audio(), .video()], isHost: true,
            lifecycle: .activeAttached)

        let model = call(isSip: false, conference: conference)

        XCTAssertFalse(model.canHold)
        XCTAssertFalse(model.canResume)
    }

    func testConferencePendingMediaDisablesToggles() {
        let conference = CallTestFixtures.conference(
            media: [.audio(), .video()],
            pendingMediaRequest: [.audio(muted: true), .video()],
            isHost: true, lifecycle: .activeAttached)

        XCTAssertFalse(call(conference: conference).canToggleMedia)
    }

    func testDetachedHostedConferenceDisablesMediaControls() {
        var state = CallTestFixtures.call(media: [.audio(muted: true), .video()])
        state.conferenceId = CallTestFixtures.conferenceId
        let conference = CallTestFixtures.conference(
            isHost: true, lifecycle: .activeDetached)

        let model = CallControlsModel(call: state, conference: conference,
                                      isSipAccount: false)

        XCTAssertFalse(model.canToggleMedia,
                       "a detached relay has no local microphone or camera")
    }

    func testMismatchedHostedConferenceDoesNotSupplyPendingMediaState() {
        var state = CallTestFixtures.call(media: [.audio(), .video()])
        state.conferenceId = CallTestFixtures.conferenceId
        let unrelated = CallTestFixtures.conference(
            id: ConfId(raw: CallTestFixtures.secondaryCallId.raw),
            media: [.audio(muted: true), .video(muted: true)],
            pendingMediaRequest: [.audio(muted: true)], isHost: true)

        let model = CallControlsModel(call: state, conference: unrelated,
                                      isSipAccount: false)

        XCTAssertFalse(model.isAudioMuted)
        XCTAssertFalse(model.isVideoMuted)
        XCTAssertTrue(model.canToggleMedia)
    }

    func testEffectiveMediaUsesOnlyTheLocallyHostedConference() {
        var state = CallTestFixtures.call(media: [.audio(), .video()])
        state.conferenceId = CallTestFixtures.conferenceId
        let hosted = CallTestFixtures.conference(
            media: [.audio(muted: true), .video(muted: true)],
            isHost: true, lifecycle: .activeAttached)
        let peerHosted = CallTestFixtures.conference(
            media: [.audio(muted: true), .video(muted: true)])

        XCTAssertTrue(state.effectiveMedia(in: hosted).isAudioMuted)
        XCTAssertTrue(state.effectiveMedia(in: hosted).isVideoMuted)
        XCTAssertFalse(state.effectiveMedia(in: peerHosted).isAudioMuted,
                       "a peer-hosted conference still uses the local member leg")
        XCTAssertEqual(state.effectiveMedia(in: CallTestFixtures.conference(
                                                isHost: true, lifecycle: .activeAttached)), [],
                       "an attached host owns its media even before the list arrives")
    }
}
