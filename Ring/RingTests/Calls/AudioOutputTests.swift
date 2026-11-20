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

/// Port kinds and names follow what iOS 27 reported on an iPhone 14 Pro.
final class AudioOutputTests: XCTestCase {

    private let receiver = AudioPort(kind: .receiver, id: "Built-In Receiver", name: "Receiver")
    private let speaker = AudioPort(kind: .speaker, id: "Speaker", name: "Speaker")
    private let builtInMic = AudioPort(kind: .other, id: "Built-In Microphone", name: "iPhone Microphone")
    private let headphones = AudioPort(kind: .wired, id: "Wired Headphones", name: "Headphones")
    private let headsetMic = AudioPort(kind: .wired, id: "Wired Microphone", name: "Headset Microphone")
    private let philipsOut = AudioPort(kind: .bluetooth, id: "00:22:37:AA:BB:CC-tsco", name: "Philips SHQ6500")
    private let philipsIn = AudioPort(kind: .bluetooth, id: "00:22:37:AA:BB:CC-tsco-in", name: "Philips SHQ6500")
    private var philips: AudioOutput { .bluetooth(id: philipsOut.id, name: "Philips SHQ6500") }

    func testPhoneOffersEarpieceAndSpeaker() {
        let snapshot = AudioRouteSnapshot(outputs: [receiver], availableInputs: [builtInMic],
                                          hasReceiver: true)
        XCTAssertEqual(AudioOutputs.available(in: snapshot), [.iPhone, .speaker])
        XCTAssertEqual(AudioOutputs.current(in: snapshot), .iPhone)
    }

    func testIPadOffersOnlySpeaker() {
        let snapshot = AudioRouteSnapshot(outputs: [speaker], availableInputs: [builtInMic],
                                          hasReceiver: false)
        XCTAssertEqual(AudioOutputs.available(in: snapshot), [.speaker])
    }

    func testWiredHeadsetReplacesEarpiece() {
        let onHeadset = AudioRouteSnapshot(outputs: [headphones],
                                           availableInputs: [builtInMic, headsetMic],
                                           hasReceiver: true)
        XCTAssertEqual(AudioOutputs.available(in: onHeadset), [.speaker, .wired])
        XCTAssertEqual(AudioOutputs.current(in: onHeadset), .wired)

        let onSpeaker = AudioRouteSnapshot(outputs: [speaker],
                                           availableInputs: [builtInMic, headsetMic],
                                           hasReceiver: true)
        XCTAssertEqual(AudioOutputs.available(in: onSpeaker), [.speaker, .wired],
                       "the headset stays offered while audio is on the speaker")
    }

    func testBluetoothHeadsetIsOfferedOnceAndMatchedByName() {
        let snapshot = AudioRouteSnapshot(outputs: [philipsOut],
                                          availableInputs: [builtInMic, philipsIn],
                                          hasReceiver: true)
        let available = AudioOutputs.available(in: snapshot)
        XCTAssertEqual(available, [.iPhone, .speaker, philips])
        XCTAssertEqual(AudioOutputs.current(in: snapshot), philips)
    }

    func testDefaultOutputFollowsCallTypeAndHeadsets() {
        let phone: [AudioOutput] = [.iPhone, .speaker]
        XCTAssertTrue(AudioOutputs.isDefault(.iPhone, among: phone, callHasVideo: false))
        XCTAssertFalse(AudioOutputs.isDefault(.speaker, among: phone, callHasVideo: false))
        XCTAssertTrue(AudioOutputs.isDefault(.speaker, among: phone, callHasVideo: true))
        XCTAssertFalse(AudioOutputs.isDefault(.iPhone, among: phone, callHasVideo: true))
        XCTAssertTrue(AudioOutputs.isDefault(.speaker, among: [.speaker], callHasVideo: false),
                      "iPad has no earpiece")

        let withHeadset = phone + [philips]
        XCTAssertTrue(AudioOutputs.isDefault(philips, among: withHeadset, callHasVideo: true))
        XCTAssertFalse(AudioOutputs.isDefault(.speaker, among: withHeadset, callHasVideo: true))
    }

    func testTapSwitchesOnlyBetweenTwoOutputs() {
        XCTAssertEqual(AudioOutputs.toggleTarget(from: .iPhone, among: [.iPhone, .speaker]), .speaker)
        XCTAssertEqual(AudioOutputs.toggleTarget(from: .speaker, among: [.speaker, .wired]), .wired)
        XCTAssertNil(AudioOutputs.toggleTarget(from: .iPhone, among: [.iPhone, .speaker, philips]))
    }
}
