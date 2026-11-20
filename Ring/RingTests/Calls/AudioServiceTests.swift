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
import AVFoundation
import Combine
@testable import Ring

/// Reproduces the routing iOS 27 showed on an iPhone 14 Pro: a category
/// or mode change drops the speaker override, a wired headset replaces
/// the earpiece, and Bluetooth is used only while the session allows it.
private final class FakeCallAudioSession: CallAudioSession {
    var hasReceiver = true
    var wiredConnected = false
    var bluetooth: AudioPort?
    private(set) var config: CallAudioConfiguration?
    private(set) var speakerOverride = false
    private(set) var configureCount = 0

    private let receiver = AudioPort(kind: .receiver, id: "receiver", name: "Receiver")
    private let speaker = AudioPort(kind: .speaker, id: "speaker", name: "Speaker")
    private let mic = AudioPort(kind: .other, id: "mic", name: "iPhone Microphone")
    private let headphones = AudioPort(kind: .wired, id: "headphones", name: "Headphones")
    private let headsetMic = AudioPort(kind: .wired, id: "headset-mic", name: "Headset Microphone")

    func snapshot() -> AudioRouteSnapshot {
        let allowsBluetooth = config?.allowsBluetooth ?? false
        let output: AudioPort
        if speakerOverride {
            output = speaker
        } else if wiredConnected {
            output = headphones
        } else if let bluetooth = bluetooth, allowsBluetooth {
            output = bluetooth
        } else if config?.videoMode == true || !hasReceiver {
            output = speaker
        } else {
            output = receiver
        }
        var inputs = [mic]
        if wiredConnected { inputs.append(headsetMic) }
        if let bluetooth = bluetooth, allowsBluetooth { inputs.append(bluetooth) }
        return AudioRouteSnapshot(outputs: [output], availableInputs: inputs,
                                  hasReceiver: hasReceiver)
    }

    func configuration() -> CallAudioConfiguration? { config }

    func configure(_ configuration: CallAudioConfiguration) {
        config = configuration
        speakerOverride = false
        configureCount += 1
    }

    func overrideToSpeaker(_ enabled: Bool) { speakerOverride = enabled }

    func preferInput(id: String?) {}

    func reset() {
        config = nil
        speakerOverride = false
    }
}

final class AudioServiceTests: XCTestCase {

    private var session: FakeCallAudioSession!
    private var notificationCenter: NotificationCenter!
    private var service: AudioService!
    private var state = AudioOutputState.idle
    private var cancellable: AnyCancellable?
    private let philips = AudioPort(kind: .bluetooth, id: "philips", name: "Philips SHQ6500")
    private var philipsOutput: AudioOutput { .bluetooth(id: "philips", name: "Philips SHQ6500") }

    override func setUp() {
        super.setUp()
        session = FakeCallAudioSession()
        notificationCenter = NotificationCenter()
        service = AudioService(session: session, notificationCenter: notificationCenter)
        cancellable = service.outputState.sink { [weak self] in self?.state = $0 }
    }

    override func tearDown() {
        cancellable = nil
        service = nil
        super.tearDown()
    }

    private func startCall(video: Bool) {
        service.prepareForCall(hasVideo: video)
        service.callKitActivated(callHasVideo: video)
        service.waitUntilIdle()
    }

    private func perform(_ action: (AudioService) -> Void) {
        action(service)
        service.waitUntilIdle()
    }

    func testCallsStartOnTheirDefaultOutput() {
        startCall(video: false)
        XCTAssertEqual(state.current, .iPhone)
        XCTAssertTrue(state.isDefault)

        perform { $0.callKitDeactivated() }
        startCall(video: true)
        XCTAssertEqual(state.current, .speaker)
        XCTAssertTrue(state.isDefault)
    }

    func testSpeakerToggleReturnsToConnectedHeadset() {
        session.bluetooth = philips
        startCall(video: false)
        XCTAssertEqual(state.current, philipsOutput)

        perform { $0.toggleSpeaker() }
        XCTAssertEqual(state.current, .speaker)
        XCTAssertFalse(state.isDefault)

        perform { $0.toggleSpeaker() }
        XCTAssertEqual(state.current, philipsOutput)
    }

    func testEarpieceWithBluetoothKeepsHeadsetOffered() {
        session.bluetooth = philips
        startCall(video: false)

        perform { $0.select(.iPhone) }
        XCTAssertEqual(state.current, .iPhone)
        XCTAssertEqual(state.available, [.iPhone, .speaker, philipsOutput])
        XCTAssertFalse(state.isDefault)

        perform { $0.select(philipsOutput) }
        XCTAssertEqual(state.current, philipsOutput)
    }

    func testVideoCallCanUseEarpieceAndSpeaker() {
        startCall(video: true)

        perform { $0.select(.iPhone) }
        XCTAssertEqual(state.current, .iPhone)
        XCTAssertFalse(state.isDefault)

        perform { $0.select(.speaker) }
        XCTAssertEqual(state.current, .speaker)
        XCTAssertTrue(state.isDefault)
    }

    func testCameraOnMovesAudioCallFromEarpieceOnce() {
        startCall(video: false)

        perform { $0.cameraTurnedOn() }
        XCTAssertEqual(state.current, .speaker)
        XCTAssertTrue(state.isDefault)

        perform { $0.select(.iPhone) }
        perform { $0.cameraTurnedOn() }
        XCTAssertEqual(state.current, .iPhone, "a later choice is kept")
    }

    func testCameraOnKeepsHeadset() {
        session.bluetooth = philips
        startCall(video: false)

        perform { $0.cameraTurnedOn() }

        XCTAssertEqual(state.current, philipsOutput)
    }

    func testRouteChangesOutsideTheAppAreFollowed() {
        session.bluetooth = philips
        startCall(video: false)

        session.bluetooth = nil
        notificationCenter.post(name: AVAudioSession.routeChangeNotification, object: nil)
        service.waitUntilIdle()

        XCTAssertEqual(state.current, .iPhone)
        XCTAssertEqual(state.available, [.iPhone, .speaker])
    }

    func testSecondCallKeepsCurrentRouting() {
        startCall(video: false)
        perform { $0.select(.speaker) }
        let configured = session.configureCount

        service.prepareForCall(hasVideo: true)

        XCTAssertEqual(session.configureCount, configured)
        XCTAssertTrue(session.speakerOverride)
    }

    func testEndingTheCallResetsTheSession() {
        startCall(video: false)
        perform { $0.select(.speaker) }

        perform { $0.callKitDeactivated() }

        XCTAssertNil(session.configuration())
        XCTAssertFalse(session.speakerOverride)
        XCTAssertEqual(state, .idle)
    }
}
