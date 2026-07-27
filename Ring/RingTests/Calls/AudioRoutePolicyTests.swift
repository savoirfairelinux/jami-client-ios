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

final class AudioRoutePolicyTests: XCTestCase {

    func testHeadsetAlwaysWins() {
        XCTAssertEqual(AudioRoutePolicy.route(bluetoothConnected: true,
                                              headphonesConnected: false,
                                              prefersSpeaker: true), .bluetooth)
        XCTAssertEqual(AudioRoutePolicy.route(bluetoothConnected: true,
                                              headphonesConnected: true,
                                              prefersSpeaker: false), .bluetooth,
                       "bluetooth wins over wired headphones")
        XCTAssertEqual(AudioRoutePolicy.route(bluetoothConnected: false,
                                              headphonesConnected: true,
                                              prefersSpeaker: true), .headphones)
    }

    func testSpeakerPreferenceAppliesWithoutHeadset() {
        XCTAssertEqual(AudioRoutePolicy.route(bluetoothConnected: false,
                                              headphonesConnected: false,
                                              prefersSpeaker: true), .builtinSpeaker)
        XCTAssertEqual(AudioRoutePolicy.route(bluetoothConnected: false,
                                              headphonesConnected: false,
                                              prefersSpeaker: false), .receiver)
    }

    func testDefaultPreferenceFollowsVideo() {
        XCTAssertTrue(AudioRoutePolicy.defaultSpeakerPreference(callHasVideo: true))
        XCTAssertFalse(AudioRoutePolicy.defaultSpeakerPreference(callHasVideo: false))
    }

    func testOverrideOnActivationOnlyForIncoming() {
        XCTAssertTrue(AudioRoutePolicy.shouldOverrideOnActivation(direction: .incoming))
        XCTAssertFalse(AudioRoutePolicy.shouldOverrideOnActivation(direction: .outgoing))
    }

    func testLibJamiPortNumbersAreStable() {
        XCTAssertEqual(AudioRoute.builtinSpeaker.rawValue, 0)
        XCTAssertEqual(AudioRoute.bluetooth.rawValue, 1)
        XCTAssertEqual(AudioRoute.headphones.rawValue, 2)
        XCTAssertEqual(AudioRoute.receiver.rawValue, 3)
    }
}
