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

final class CallStatusTransitionTests: XCTestCase {

    func testLibJamiStateMapping() {
        XCTAssertEqual(CallStatus(libJami: .incoming), .incoming)
        XCTAssertEqual(CallStatus(libJami: .connecting), .connecting)
        XCTAssertEqual(CallStatus(libJami: .ringing), .ringing)
        XCTAssertEqual(CallStatus(libJami: .current), .current)
        XCTAssertEqual(CallStatus(libJami: .hold), .held(side: .local))
        XCTAssertEqual(CallStatus(libJami: .hungUp), .terminated(.hungUp))
        XCTAssertEqual(CallStatus(libJami: .busy), .terminated(.busy))
        XCTAssertEqual(CallStatus(libJami: .peerBusy), .terminated(.peerBusy))
        XCTAssertEqual(CallStatus(libJami: .failure), .terminated(.failure))
        XCTAssertEqual(CallStatus(libJami: .inactive), .terminated(.inactive))
        XCTAssertEqual(CallStatus(libJami: .over), .terminated(.over))
    }

    func testNoLibJamiStateMapsToEndedLocally() {
        for libJamiState in LibJamiCallState.allCases {
            XCTAssertNotEqual(CallStatus(libJami: libJamiState), .terminated(.endedLocally),
                              "\(libJamiState) must not map to endedLocally")
        }
    }

    func testTerminatedIsAbsorbing() {
        let terminated = CallStatus.terminated(.over)
        for next: CallStatus in [.incoming, .connecting, .ringing, .current,
                                 .held(side: .local), .terminated(.failure)] {
            XCTAssertFalse(terminated.canTransition(to: next), "\(next)")
        }
    }

    func testEndedLocallyIsAbsorbing() {
        let terminated = CallStatus.terminated(.endedLocally)
        for next: CallStatus in [.incoming, .connecting, .ringing, .current,
                                 .held(side: .local), .terminated(.over)] {
            XCTAssertFalse(terminated.canTransition(to: next), "\(next)")
        }
    }

    func testHappyPathOutgoing() {
        XCTAssertTrue(CallStatus.connecting.canTransition(to: .ringing))
        XCTAssertTrue(CallStatus.ringing.canTransition(to: .current))
        XCTAssertTrue(CallStatus.current.canTransition(to: .terminated(.over)))
    }

    func testHappyPathIncoming() {
        XCTAssertTrue(CallStatus.incoming.canTransition(to: .connecting))
        XCTAssertTrue(CallStatus.incoming.canTransition(to: .current))
        XCTAssertTrue(CallStatus.incoming.canTransition(to: .terminated(.hungUp)))
    }

    func testHoldRoundTrip() {
        XCTAssertTrue(CallStatus.current.canTransition(to: .held(side: .local)))
        XCTAssertTrue(CallStatus.held(side: .local).canTransition(to: .current))
        XCTAssertTrue(CallStatus.held(side: .local).canTransition(to: .held(side: .both)))
    }

    func testNoBackwardTransitions() {
        XCTAssertFalse(CallStatus.current.canTransition(to: .ringing))
        XCTAssertFalse(CallStatus.current.canTransition(to: .incoming))
        XCTAssertFalse(CallStatus.ringing.canTransition(to: .connecting))
    }

    func testSameStateIsAllowedAsNoOp() {
        XCTAssertTrue(CallStatus.current.canTransition(to: .current))
        XCTAssertTrue(CallStatus.ringing.canTransition(to: .ringing))
    }

    func testPredicates() {
        XCTAssertTrue(CallStatus.terminated(.busy).isTerminal)
        XCTAssertTrue(CallStatus.terminated(.endedLocally).isTerminal)
        XCTAssertFalse(CallStatus.current.isTerminal)
        XCTAssertTrue(CallStatus.current.isOngoing)
        XCTAssertTrue(CallStatus.held(side: .peer).isOngoing)
        XCTAssertFalse(CallStatus.incoming.isOngoing)
        XCTAssertFalse(CallStatus.terminated(.over).isOngoing)
        XCTAssertFalse(CallStatus.terminated(.endedLocally).isOngoing)
    }

    func testAcceptAndRefuseOnlyFromIncoming() {
        XCTAssertTrue(CallStatus.incoming.allows(.accept))
        XCTAssertTrue(CallStatus.incoming.allows(.refuse))
        for status: CallStatus in [.connecting, .ringing, .current,
                                   .held(side: .local), .terminated(.over)] {
            XCTAssertFalse(status.allows(.accept), "\(status)")
            XCTAssertFalse(status.allows(.refuse), "\(status)")
        }
    }

    func testHangUpFromAnyLiveState() {
        for status: CallStatus in [.incoming, .connecting, .ringing, .current,
                                   .held(side: .peer)] {
            XCTAssertTrue(status.allows(.hangUp), "\(status)")
        }
        XCTAssertFalse(CallStatus.terminated(.over).allows(.hangUp))
        XCTAssertFalse(CallStatus.terminated(.endedLocally).allows(.hangUp),
                       "a second tap must not re-send hangUp")
    }

    func testHoldResumeIntents() {
        XCTAssertTrue(CallStatus.current.allows(.hold))
        XCTAssertFalse(CallStatus.ringing.allows(.hold))
        XCTAssertFalse(CallStatus.held(side: .local).allows(.hold))

        XCTAssertTrue(CallStatus.held(side: .local).allows(.resume))
        XCTAssertTrue(CallStatus.held(side: .both).allows(.resume))
        XCTAssertFalse(CallStatus.held(side: .peer).allows(.resume))
        XCTAssertFalse(CallStatus.current.allows(.resume))
    }

    func testMediaIntentsRequireEstablishedCall() {
        XCTAssertTrue(CallStatus.current.allows(.changeMedia))
        XCTAssertTrue(CallStatus.held(side: .peer).allows(.changeMedia))
        XCTAssertFalse(CallStatus.ringing.allows(.changeMedia))
        XCTAssertFalse(CallStatus.incoming.allows(.changeMedia))
    }
}
