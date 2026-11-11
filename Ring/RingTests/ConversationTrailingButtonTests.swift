/*
 *  Copyright (C) 2026 Savoir-faire Linux Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
@testable import Ring

final class ConversationTrailingButtonTests: XCTestCase {
    private func visible(isBlocked: Bool = false,
                         isConversationEnded: Bool = false,
                         canStartCalls: Bool = true,
                         hasPeerSharing: Bool = false,
                         isAccountSip: Bool = false) -> [ConversationTrailingButton] {
        return ConversationTrailingButton.visible(isBlocked: isBlocked,
                                                  isConversationEnded: isConversationEnded,
                                                  canStartCalls: canStartCalls,
                                                  hasPeerSharing: hasPeerSharing,
                                                  isAccountSip: isAccountSip)
    }

    func testJamiConversationOffersAudioAndVideo() {
        XCTAssertEqual(visible(), [.audioCall, .videoCall])
    }

    func testSipConversationOffersAudioOnly() {
        XCTAssertEqual(visible(isAccountSip: true), [.audioCall])
    }

    func testPeerSharingComesFirst() {
        XCTAssertEqual(visible(hasPeerSharing: true), [.peerSharing, .audioCall, .videoCall])
    }

    func testNoCallsKeepsPeerSharing() {
        XCTAssertEqual(visible(canStartCalls: false, hasPeerSharing: true), [.peerSharing])
        XCTAssertEqual(visible(canStartCalls: false), [])
    }

    func testBlockedConversationShowsNothing() {
        XCTAssertEqual(visible(isBlocked: true, hasPeerSharing: true), [])
    }

    func testEndedConversationShowsNothing() {
        XCTAssertEqual(visible(isConversationEnded: true, hasPeerSharing: true), [])
    }
}
