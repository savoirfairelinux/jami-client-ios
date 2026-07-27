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

final class ConferenceMenuTests: XCTestCase {

    private let builder = ConferenceMenuBuilder()

    func testLowerHandOnlyAppearsWhenHandIsRaised() {
        let raised = builder.menuForLocalTile(layout: .grid, isActive: false,
                                              isHandRaised: true,
                                              isModeratorMuted: false)
        let lowered = builder.menuForLocalTile(layout: .grid, isActive: false,
                                               isHandRaised: false,
                                               isModeratorMuted: false)

        XCTAssertTrue(raised.contains(.lowerHand))
        XCTAssertFalse(lowered.contains(.lowerHand))
    }

    func testRegularParticipantHasNoModerationActions() {
        let menu = builder.menuForParticipant(isHost: false, layout: .grid,
                                              isActive: false, role: .regular,
                                              isHandRaised: false)

        XCTAssertFalse(menu.contains(.muteAudio))
        XCTAssertFalse(menu.contains(.setModerator))
        XCTAssertFalse(menu.contains(.endCall))
    }

    func testHostSeesModerationActions() {
        let menu = builder.menuForParticipant(isHost: true, layout: .grid,
                                              isActive: false, role: .host,
                                              isHandRaised: false)

        XCTAssertTrue(menu.contains(.muteAudio))
        XCTAssertTrue(menu.contains(.setModerator))
        XCTAssertTrue(menu.contains(.endCall))
    }

    func testModeratorCanMuteAndEndAnotherCall() {
        let menu = builder.menuForParticipant(isHost: false, layout: .grid,
                                              isActive: false, role: .moderator,
                                              isHandRaised: false)

        XCTAssertTrue(menu.contains(.muteAudio))
        XCTAssertTrue(menu.contains(.endCall))
        XCTAssertFalse(menu.contains(.setModerator))
    }

    func testFullscreenActiveParticipantCanMinimize() {
        let menu = builder.menuForParticipant(isHost: false, layout: .one,
                                              isActive: true, role: .regular,
                                              isHandRaised: false)

        XCTAssertTrue(menu.contains(.minimize))
        XCTAssertFalse(menu.contains(.maximize))
    }
}
