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

struct AudioRouteState: Sendable, Equatable {
    let speakerActive: Bool
    let bluetoothConnected: Bool
    let headphonesConnected: Bool
}

final class AudioService {

    private let audio: LibJamiAudioAPI
    private let currentRoute: () -> AudioRouteState
    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private var prefersSpeaker = true
    private let speakerActiveSubject = CurrentValueSubject<Bool, Never>(false)
    private let routeQueue = DispatchQueue(label: "com.savoirfairelinux.jami.audio.route")
    private var observer: NSObjectProtocol?

    /// Emits on an unspecified queue; receive on main before binding to the UI.
    var speakerActive: AnyPublisher<Bool, Never> {
        speakerActiveSubject.removeDuplicates().eraseToAnyPublisher()
    }

    convenience init(audioAdapter: AudioAdapter = AudioAdapter()) {
        self.init(audio: LibJamiAudioClient(adapter: audioAdapter))
    }

    convenience init(audio: LibJamiAudioAPI) {
        self.init(audio: audio,
                  currentRoute: { AudioService.systemRouteState() },
                  notificationCenter: .default)
    }

    init(audio: LibJamiAudioAPI,
         currentRoute: @escaping () -> AudioRouteState,
         notificationCenter: NotificationCenter) {
        self.audio = audio
        self.currentRoute = currentRoute
        self.notificationCenter = notificationCenter
        refreshRouteState()
        observer = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let reasonValue = notification
                    .userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
                  reason == .newDeviceAvailable
                    || reason == .oldDeviceUnavailable
                    || reason == .categoryChange else {
                return
            }
            self?.routeQueue.async { self?.applyAutomaticRoute() }
        }
    }

    deinit {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
    }

    func callKitActivated(callHasVideo: Bool, direction: CallDirection) {
        setPrefersSpeaker(AudioRoutePolicy.defaultSpeakerPreference(callHasVideo: callHasVideo))
        if AudioRoutePolicy.shouldOverrideOnActivation(direction: direction) {
            applyAutomaticRoute()
        } else {
            refreshRouteState()
        }
    }

    func toggleSpeaker() {
        // A button tap is an explicit override: match the old client behavior
        // and invert the real route even when a headset is connected.
        let route: AudioRoute = speakerActiveSubject.value
            ? .receiver : .builtinSpeaker
        setPrefersSpeaker(route == .builtinSpeaker)
        select(route)
    }

    private func applyAutomaticRoute() {
        let current = currentRoute()
        let route = AudioRoutePolicy.route(bluetoothConnected: current.bluetoothConnected,
                                           headphonesConnected: current.headphonesConnected,
                                           prefersSpeaker: currentPrefersSpeaker())
        select(route)
    }

    private func select(_ route: AudioRoute) {
        audio.setAudioOutputDevice(route.rawValue)
        speakerActiveSubject.send(route == .builtinSpeaker)
    }

    private func refreshRouteState() {
        speakerActiveSubject.send(currentRoute().speakerActive)
    }

    private func setPrefersSpeaker(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        prefersSpeaker = value
    }

    private func currentPrefersSpeaker() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return prefersSpeaker
    }

    private static func systemRouteState() -> AudioRouteState {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return AudioRouteState(
            speakerActive: outputs.contains { $0.portType == .builtInSpeaker },
            bluetoothConnected: outputs.contains {
                $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
                    || $0.portType == .bluetoothLE
            },
            headphonesConnected: outputs.contains { $0.portType == .headphones }
        )
    }
}
