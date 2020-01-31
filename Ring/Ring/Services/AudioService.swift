/*
 *  Copyright (C) 2018-2019 Savoir-faire Linux Inc.
 *
 *  Author: Andreas Traczyk <andreas.traczyk@savoirfairelinux.com>
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

import Foundation
import SwiftyBeaver
import RxSwift

enum OutputPortType: Int {
    case builtinspk     = 0
    case bluetooth      = 1
    case headphones     = 2
    case receiver       = 3
}

class AudioService {
    fileprivate let disposeBag = DisposeBag()
    fileprivate let log = SwiftyBeaver.self

    fileprivate let audioAdapter: AudioAdapter

    var isHeadsetConnected = Variable<Bool>(false)
    var isOutputToSpeaker = Variable<Bool>(true)

    var enableSwitchAudio: Observable<Bool> {
        return self.isHeadsetConnected.asObservable()
    }

    init(withAudioAdapter audioAdapter: AudioAdapter) {
        self.audioAdapter = audioAdapter

        // Listen for audio route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChangeListener(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil)
    }

    func startAVAudioSession() {
        do {
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [AVAudioSession.CategoryOptions.allowBluetooth, AVAudioSession.CategoryOptions.mixWithOthers])
            } else {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [AVAudioSession.CategoryOptions.allowBluetooth, AVAudioSession.CategoryOptions.mixWithOthers])
            }
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            log.error("\(error)")
        }
        if useCallKit, #available(iOS 10.0, *) {
            return
        }
        setToRing()
    }

    // swiftlint:disable force_cast
    @objc private func audioRouteChangeListener(_ notification: Notification) {
        let reasonRaw = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as! UInt
        self.log.debug("Audio route change: \(reasonRaw)")
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
            return
        }
        overrideAudioRoute(reason)
    }
    // swiftlint:enable force_cast

    func overrideAudioRoute(_ reason: AVAudioSession.RouteChangeReason) {
        let wasHeadsetConnected = isHeadsetConnected.value
        let bluetoothConnected = bluetoothAudioConnected()
        let headphonesConnected = headphoneAudioConnected()
        self.log.debug("Audio route override - reason: \(reason.rawValue), status: bluetooth: \(bluetoothConnected), headphones: \(headphonesConnected)")
        isHeadsetConnected.value = bluetoothConnected || headphonesConnected
        if reason == .override && !isHeadsetConnected.value {
            setAudioOutputDevice(port: OutputPortType.builtinspk)
        } else if wasHeadsetConnected != isHeadsetConnected.value {
            if bluetoothConnected {
                setAudioOutputDevice(port: OutputPortType.bluetooth)
            } else if headphonesConnected {
                setAudioOutputDevice(port: OutputPortType.headphones)
            } else if wasHeadsetConnected {
                let outputPort = isOutputToSpeaker.value ? OutputPortType.builtinspk : OutputPortType.receiver
                setAudioOutputDevice(port: outputPort)
            }
        }
    }

    func switchSpeaker() {
        guard let isSpeaker = self.speakerIsActive() else {
            return
        }
        if isSpeaker {
            overrideToReceiver()
        } else {
            overrideToSpeaker()
        }
    }

    func setToRing() {
        if !isHeadsetConnected.value {
            setAudioOutputDevice(port: OutputPortType.builtinspk)
        }
    }

    func overrideToSpeaker() {
        isOutputToSpeaker.value = true
        setAudioOutputDevice(port: OutputPortType.builtinspk)
    }

    func overrideToReceiver() {
        isOutputToSpeaker.value = false
        setAudioOutputDevice(port: OutputPortType.receiver)
    }

    func bluetoothAudioConnected() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        for output in outputs {
            if  output.portType == AVAudioSession.Port.bluetoothA2DP ||
                output.portType == AVAudioSession.Port.bluetoothHFP ||
                output.portType == AVAudioSession.Port.bluetoothLE {
                return true
            }
        }
        return false
    }

    func headphoneAudioConnected() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        for output in outputs where output.portType == AVAudioSession.Port.headphones {
            return true
        }
        return false
    }

    func speakerIsActive() -> Bool? {
        if let output = AVAudioSession.sharedInstance().currentRoute.outputs.first {
            return output.uid == AVAudioSession.Port.builtInSpeaker.rawValue
        }
        return nil
    }

    func setAudioOutputDevice(port: OutputPortType) {
        self.audioAdapter.setAudioOutputDevice(port.rawValue)
    }

    func setAudioRingtoneDevice(port: OutputPortType) {
        self.audioAdapter.setAudioRingtoneDevice(port.rawValue)
    }

    func startAudio() {
        self.audioAdapter.startAudio()
    }
}
