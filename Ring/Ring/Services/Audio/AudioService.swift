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

final class AudioService {

    private let audio: LibJamiAudioAPI
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

    init(audio: LibJamiAudioAPI) {
        self.audio = audio
        refreshRouteState()
        observer = NotificationCenter.default.addObserver(
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
            self?.routeQueue.async { self?.applyRoute() }
        }
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func callKitActivated(callHasVideo: Bool, direction: CallDirection) {
        setPrefersSpeaker(AudioRoutePolicy.defaultSpeakerPreference(callHasVideo: callHasVideo))
        if AudioRoutePolicy.shouldOverrideOnActivation(direction: direction) {
            applyRoute()
        } else {
            refreshRouteState()
        }
    }

    func toggleSpeaker() {
        lock.lock()
        prefersSpeaker.toggle()
        lock.unlock()
        applyRoute()
    }

    private func applyRoute() {
        let bluetooth = bluetoothConnected()
        let headphones = headphonesConnected()
        let route = AudioRoutePolicy.route(bluetoothConnected: bluetooth,
                                           headphonesConnected: headphones,
                                           prefersSpeaker: currentPrefersSpeaker())
        audio.setAudioOutputDevice(route.rawValue)
        speakerActiveSubject.send(route == .builtinSpeaker)
    }

    private func refreshRouteState() {
        speakerActiveSubject.send(
            AVAudioSession.sharedInstance().currentRoute.outputs.first?
                .portType == .builtInSpeaker)
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

    private func bluetoothConnected() -> Bool {
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
                || $0.portType == .bluetoothLE
        }
    }

    private func headphonesConnected() -> Bool {
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .headphones
        }
    }
}
