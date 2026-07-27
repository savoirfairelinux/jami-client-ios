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
                      isSip: Bool = false) -> CallControlsModel {
        let state = CallState(id: CallId(raw: "c"), accountId: accountId1,
                              direction: .outgoing, status: status,
                              media: media, pendingMediaRequest: pending)
        return CallControlsModel(call: state, isSipAccount: isSip)
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
        XCTAssertTrue(call(status: .current).canHold)
        XCTAssertFalse(call(status: .held(side: .local)).canHold)
        XCTAssertTrue(call(status: .held(side: .local)).canResume)
        XCTAssertFalse(call(status: .held(side: .peer)).canResume)
    }
}
