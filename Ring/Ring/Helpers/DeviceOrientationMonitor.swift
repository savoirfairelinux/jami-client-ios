/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

import UIKit

struct DeviceOrientationInput: Equatable {
    let device: UIDeviceOrientation
    let interface: UIInterfaceOrientation
}

private final class OrientationObservation {

    private(set) static var count = 0

    private var observers: [NSObjectProtocol] = []

    init(onChange: @escaping () -> Void) {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        OrientationObservation.count += 1
        observers = [UIDevice.orientationDidChangeNotification,
                     UIApplication.didBecomeActiveNotification].map { name in
                        NotificationCenter.default.addObserver(forName: name, object: nil,
                                                               queue: .main) { _ in onChange() }
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        let end = {
            OrientationObservation.count -= 1
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        Thread.isMainThread ? end() : DispatchQueue.main.async(execute: end)
    }
}

@MainActor
final class DeviceOrientationMonitor {

    static var generationCount: Int { OrientationObservation.count }

    private var handler: ((DeviceOrientationInput) -> Void)?
    private var observation: OrientationObservation?

    var isGenerating: Bool { observation != nil }

    func start(handler: @escaping (DeviceOrientationInput) -> Void) {
        self.handler = handler
        if observation == nil {
            observation = OrientationObservation { [weak self] in
                Task { @MainActor in self?.emit() }
            }
        }
        emit()
    }

    func stop() {
        handler = nil
        observation = nil
    }

    private func emit() {
        handler?(DeviceOrientationInput(device: UIDevice.current.orientation,
                                        interface: ScreenHelper.currentOrientation()))
    }
}
