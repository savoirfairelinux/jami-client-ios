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

    private func hostedConference(lifecycle: ConferenceLifecycle,
                                  media: [MediaItem] = [.audio(), .video()])
    -> ConferenceState {
        CallTestFixtures.conference(media: media, isHost: true, lifecycle: lifecycle)
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

        let attached = hostedConference(lifecycle: .activeAttached)
        XCTAssertTrue(call(isSip: true, conference: attached).canHold,
                      "a hosted conference is held as a whole")
        XCTAssertFalse(call(isSip: true, conference: attached).canResume)
        let detached = hostedConference(lifecycle: .activeDetached)
        XCTAssertFalse(call(isSip: true, conference: detached).canHold)
        XCTAssertTrue(call(isSip: true, conference: detached).canResume)
    }

    func testSipConferenceUsesHostMedia() {
        let conference = hostedConference(lifecycle: .activeAttached,
                                          media: [.audio(muted: true), .video(muted: false)])

        let model = call(media: [.audio(), .video(muted: true)],
                         isSip: true, conference: conference)

        XCTAssertTrue(model.isAudioMuted)
        XCTAssertFalse(model.isVideoMuted)
    }

    func testConferencePendingMediaDisablesToggles() {
        let conference = CallTestFixtures.conference(
            media: [.audio(), .video()],
            pendingMediaRequest: [.audio(muted: true), .video()],
            isHost: true, lifecycle: .activeAttached)

        XCTAssertFalse(call(conference: conference).canToggleMedia)
    }

    func testDetachedHostedConferenceDisablesMediaControls() {
        let model = call(media: [.audio(muted: true), .video()],
                         conference: hostedConference(lifecycle: .activeDetached))

        XCTAssertFalse(model.canToggleMedia,
                       "a detached relay has no local microphone or camera")
    }
}
