/*
 * Copyright (C) 2017-2026 Savoir-faire Linux Inc.
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

import Foundation
import AVFoundation
import Combine
import UIKit

struct AudioOutputState: Equatable, Sendable {
    var available: [AudioOutput]
    var current: AudioOutput?
    /// Whether `current` is where the call goes without the user's choice.
    var isDefault: Bool

    static let idle = AudioOutputState(available: [], current: nil, isDefault: true)
}

/// How the PlayAndRecord session is set up for a call.
struct CallAudioConfiguration: Equatable, Sendable {
    var videoMode: Bool
    var allowsBluetooth: Bool
}

/// The parts of the audio session call routing uses.
protocol CallAudioSession: AnyObject {
    func snapshot() -> AudioRouteSnapshot
    /// Nil while the session isn't set up for a call.
    func configuration() -> CallAudioConfiguration?
    func configure(_ configuration: CallAudioConfiguration)
    func overrideToSpeaker(_ enabled: Bool)
    func preferInput(id: String?)
    /// Back to the app's state outside calls.
    func reset()
}

/// Owns call audio routing. libjami plays and records through the
/// session this service configures and doesn't change its routing.
final class AudioService {

    private let session: CallAudioSession
    private let notificationCenter: NotificationCenter
    private let queue = DispatchQueue(label: "com.savoirfairelinux.jami.audio.route")
    private let stateSubject = CurrentValueSubject<AudioOutputState, Never>(.idle)
    private var observer: NSObjectProtocol?

    // Confined to `queue`.
    private var inCall = false
    private var callHasVideo = false
    /// Bluetooth inputs disappear while the session disallows Bluetooth to
    /// reach the earpiece; they stay offered so the user can switch back.
    private var hiddenBluetooth: [AudioPort] = []

    /// Emits on an unspecified queue; receive on main before binding to the UI.
    var outputState: AnyPublisher<AudioOutputState, Never> {
        stateSubject.removeDuplicates().eraseToAnyPublisher()
    }

    convenience init() {
        self.init(session: SystemCallAudioSession(), notificationCenter: .default)
    }

    init(session: CallAudioSession, notificationCenter: NotificationCenter) {
        self.session = session
        self.notificationCenter = notificationCenter
        // Every reason matters: turning Bluetooth off mid-call is reported
        // as `.override`, not as the device becoming unavailable.
        observer = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.refresh() }
        }
    }

    deinit {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
    }

    /// Called before CallKit activates the session, so the call starts
    /// in the right mode. The starting route is left to iOS, which
    /// honors connected headsets and the Call Audio Routing setting.
    func prepareForCall(hasVideo: Bool) {
        queue.sync {
            guard !inCall else { return }
            callHasVideo = hasVideo
            hiddenBluetooth = []
            session.configure(CallAudioConfiguration(videoMode: hasVideo, allowsBluetooth: true))
            session.overrideToSpeaker(false)
            session.preferInput(id: nil)
        }
    }

    func callKitActivated(callHasVideo: Bool) {
        queue.async { [self] in
            inCall = true
            self.callHasVideo = callHasVideo
            if session.configuration() == nil {
                session.configure(CallAudioConfiguration(videoMode: callHasVideo,
                                                         allowsBluetooth: true))
            }
            refresh()
        }
    }

    func callKitDeactivated() {
        queue.async { [self] in
            inCall = false
            hiddenBluetooth = []
            session.reset()
            stateSubject.send(.idle)
        }
    }

    /// An audio call turned its camera on: it now defaults to the speaker
    /// and leaves the earpiece once. Headsets and later choices stay.
    func cameraTurnedOn() {
        queue.async { [self] in
            guard inCall, !callHasVideo else { return }
            callHasVideo = true
            if currentState().current == .iPhone {
                apply(.speaker)
            } else {
                refresh()
            }
        }
    }

    func select(_ output: AudioOutput) {
        queue.async { [self] in apply(output) }
    }

    /// Waits for queued routing work; for tests.
    func waitUntilIdle() {
        queue.sync {}
    }

    // MARK: - Queue-confined

    private func apply(_ output: AudioOutput) {
        let snapshot = session.snapshot()
        switch output {
        case .iPhone:
            let bluetooth = snapshot.availableInputs.filter { $0.kind == .bluetooth }
            if !bluetooth.isEmpty {
                hiddenBluetooth = bluetooth
            }
            // Mode and category changes drop the speaker override, so they
            // come first. The earpiece needs voiceChat, and Bluetooth
            // disallowed when a headset is connected.
            ensure(CallAudioConfiguration(videoMode: false,
                                          allowsBluetooth: hiddenBluetooth.isEmpty))
            session.overrideToSpeaker(false)
        case .speaker:
            ensure(CallAudioConfiguration(videoMode: callHasVideo,
                                          allowsBluetooth: hiddenBluetooth.isEmpty))
            session.overrideToSpeaker(true)
        case .wired, .bluetooth:
            let input = (snapshot.availableInputs + hiddenBluetooth).first {
                Self.port($0, belongsTo: output)
            }
            hiddenBluetooth = []
            ensure(CallAudioConfiguration(videoMode: callHasVideo, allowsBluetooth: true))
            session.overrideToSpeaker(false)
            session.preferInput(id: input?.id)
        }
        refresh()
    }

    private func ensure(_ configuration: CallAudioConfiguration) {
        if session.configuration() != configuration {
            session.configure(configuration)
        }
    }

    private func refresh() {
        guard inCall else { return }
        stateSubject.send(currentState())
    }

    private func currentState() -> AudioOutputState {
        var snapshot = session.snapshot()
        snapshot.availableInputs += hiddenBluetooth
        let available = AudioOutputs.available(in: snapshot)
        let current = AudioOutputs.current(in: snapshot)
        let isDefault = current.map {
            AudioOutputs.isDefault($0, among: available, callHasVideo: callHasVideo)
        } ?? true
        return AudioOutputState(available: available, current: current, isDefault: isDefault)
    }

    private static func port(_ port: AudioPort, belongsTo output: AudioOutput) -> Bool {
        switch output {
        case .wired:
            return port.kind == .wired
        case let .bluetooth(id, name):
            return port.kind == .bluetooth && (port.id == id || port.name == name)
        case .iPhone, .speaker:
            return false
        }
    }
}

final class SystemCallAudioSession: CallAudioSession {

    private let hasReceiver: Bool
    private var session: AVAudioSession { .sharedInstance() }

    init(hasReceiver: Bool = UIDevice.current.userInterfaceIdiom == .phone) {
        self.hasReceiver = hasReceiver
    }

    func snapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(outputs: session.currentRoute.outputs.map(Self.port),
                           availableInputs: (session.availableInputs ?? []).map(Self.port),
                           hasReceiver: hasReceiver)
    }

    func configuration() -> CallAudioConfiguration? {
        guard session.category == .playAndRecord else { return nil }
        return CallAudioConfiguration(
            videoMode: session.mode == .videoChat,
            allowsBluetooth: session.categoryOptions.contains(.allowBluetoothHFP))
    }

    func configure(_ configuration: CallAudioConfiguration) {
        do {
            try session.setCategory(.playAndRecord,
                                    mode: configuration.videoMode ? .videoChat : .voiceChat,
                                    options: configuration.allowsBluetooth ? [.allowBluetoothHFP] : [])
        } catch {
            NSLog("Audio session configuration failed: %@", error.localizedDescription)
        }
    }

    func overrideToSpeaker(_ enabled: Bool) {
        do {
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
        } catch {
            NSLog("Audio output override failed: %@", error.localizedDescription)
        }
    }

    func preferInput(id: String?) {
        let input = id.flatMap { id in session.availableInputs?.first { $0.uid == id } }
        do {
            try session.setPreferredInput(input)
        } catch {
            NSLog("Preferred audio input failed: %@", error.localizedDescription)
        }
    }

    func reset() {
        try? session.overrideOutputAudioPort(.none)
        try? session.setPreferredInput(nil)
        try? session.setCategory(.soloAmbient, mode: .default, options: [])
    }

    private static func port(_ description: AVAudioSessionPortDescription) -> AudioPort {
        AudioPort(kind: kind(of: description.portType),
                  id: description.uid,
                  name: description.portName)
    }

    private static func kind(of type: AVAudioSession.Port) -> AudioPort.Kind {
        switch type {
        case .builtInReceiver: return .receiver
        case .builtInSpeaker: return .speaker
        case .headphones, .headsetMic, .usbAudio: return .wired
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE, .carAudio: return .bluetooth
        default: return .other
        }
    }
}
