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

    func testConnectedHeadsetsTakePriorityOverSpeakerPreference() {
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

    func testDefaultSpeakerPreferenceMatchesVideoCapability() {
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

final class AudioServiceTests: XCTestCase {

    private final class FakeAudioAPI: LibJamiAudioAPI {
        var outputDevices: [Int] = []

        func setAudioOutputDevice(_ index: Int) {
            outputDevices.append(index)
        }

        func setAudioInputDevice(_ index: Int) {}
    }

    func testToggleSpeakerUsesActualReceiverWhenPreferenceIsStale() {
        let api = FakeAudioAPI()
        let service = AudioService(
            audio: api,
            currentRoute: {
                AudioRouteState(speakerActive: false,
                                bluetoothConnected: false,
                                headphonesConnected: false)
            },
            notificationCenter: NotificationCenter())

        service.toggleSpeaker()

        XCTAssertEqual(api.outputDevices, [AudioRoute.builtinSpeaker.rawValue])
    }

    func testRapidSpeakerTogglesUseLastKnownState() {
        let api = FakeAudioAPI()
        let service = AudioService(
            audio: api,
            currentRoute: {
                AudioRouteState(speakerActive: false,
                                bluetoothConnected: false,
                                headphonesConnected: false)
            },
            notificationCenter: NotificationCenter())

        service.toggleSpeaker()
        service.toggleSpeaker()

        XCTAssertEqual(api.outputDevices, [
            AudioRoute.builtinSpeaker.rawValue,
            AudioRoute.receiver.rawValue
        ])
    }

    func testToggleSpeakerOverridesConnectedHeadset() {
        let api = FakeAudioAPI()
        let service = AudioService(
            audio: api,
            currentRoute: {
                AudioRouteState(speakerActive: false,
                                bluetoothConnected: true,
                                headphonesConnected: false)
            },
            notificationCenter: NotificationCenter())

        service.toggleSpeaker()

        XCTAssertEqual(api.outputDevices, [AudioRoute.builtinSpeaker.rawValue],
                       "an explicit user action must override automatic headset routing")
    }

    func testToggleSpeakerUsesActualSpeakerWhenPreferenceIsStale() {
        let api = FakeAudioAPI()
        let service = AudioService(
            audio: api,
            currentRoute: {
                AudioRouteState(speakerActive: true,
                                bluetoothConnected: false,
                                headphonesConnected: false)
            },
            notificationCenter: NotificationCenter())
        service.callKitActivated(callHasVideo: false, direction: .outgoing)

        service.toggleSpeaker()

        XCTAssertEqual(api.outputDevices, [AudioRoute.receiver.rawValue])
    }

    func testIncomingActivationStillPrefersConnectedHeadset() {
        let api = FakeAudioAPI()
        let service = AudioService(
            audio: api,
            currentRoute: {
                AudioRouteState(speakerActive: false,
                                bluetoothConnected: true,
                                headphonesConnected: false)
            },
            notificationCenter: NotificationCenter())

        service.callKitActivated(callHasVideo: true, direction: .incoming)

        XCTAssertEqual(api.outputDevices, [AudioRoute.bluetooth.rawValue],
                       "automatic routing still follows a newly connected headset")
    }
}
