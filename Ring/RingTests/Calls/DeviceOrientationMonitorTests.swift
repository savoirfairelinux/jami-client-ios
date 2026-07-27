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
import UIKit
@testable import Ring

@MainActor
final class DeviceOrientationMonitorTests: XCTestCase {

    private func postOrientationChange() {
        NotificationCenter.default.post(name: NSNotification.Name.UIDeviceOrientationDidChange,
                                        object: nil)
    }

    private func postDidBecomeActive() {
        NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidBecomeActive,
                                        object: nil)
    }

    private final class EmissionCounter {
        private(set) var count = 0
        private let target: Int
        private let expectation: XCTestExpectation

        init(target: Int, expectation: XCTestExpectation) {
            self.target = target
            self.expectation = expectation
        }

        func record() {
            count += 1
            if count == target { expectation.fulfill() }
        }
    }

    func testStartEmitsCurrentOrientationImmediately() {
        let monitor = DeviceOrientationMonitor()
        var received: [DeviceOrientationInput] = []

        monitor.start { received.append($0) }
        defer { monitor.stop() }

        XCTAssertEqual(received.count, 1,
                       "a preview must be oriented before its first frame")
    }

    func testOrientationNotificationEmits() {
        let monitor = DeviceOrientationMonitor()
        let counter = EmissionCounter(target: 2,
                                      expectation: expectation(description: "rotation"))
        monitor.start { _ in counter.record() }
        defer { monitor.stop() }

        postOrientationChange()

        waitForExpectations(timeout: 2)
    }

    func testBecomingActiveEmits() {
        let monitor = DeviceOrientationMonitor()
        let counter = EmissionCounter(target: 2,
                                      expectation: expectation(description: "foreground"))
        monitor.start { _ in counter.record() }
        defer { monitor.stop() }

        postDidBecomeActive()

        waitForExpectations(timeout: 2)
    }

    func testRestartingAdoptsTheNewHandler() {
        let monitor = DeviceOrientationMonitor()
        var firstCount = 0
        let counter = EmissionCounter(target: 2,
                                      expectation: expectation(description: "restarted"))

        monitor.start { _ in firstCount += 1 }
        monitor.stop()
        monitor.start { _ in counter.record() }
        defer { monitor.stop() }

        postOrientationChange()

        waitForExpectations(timeout: 2)
        XCTAssertEqual(firstCount, 1, "the retired handler must stop receiving")
    }

    func testStartingTwiceAdoptsTheNewHandlerWithoutDuplicating() {
        let monitor = DeviceOrientationMonitor()
        var firstCount = 0
        let counter = EmissionCounter(target: 2,
                                      expectation: expectation(description: "restarted"))

        monitor.start { _ in firstCount += 1 }
        monitor.start { _ in counter.record() }
        defer { monitor.stop() }

        postOrientationChange()

        waitForExpectations(timeout: 2)
        XCTAssertEqual(firstCount, 1, "one observer, feeding the newest handler")
    }

    func testStoppedMonitorReceivesNothing() {
        let monitor = DeviceOrientationMonitor()
        var count = 0
        let silence = expectation(description: "no further emissions")
        silence.isInverted = true
        monitor.start { _ in
            count += 1
            if count > 1 { silence.fulfill() }
        }
        monitor.stop()

        postOrientationChange()

        waitForExpectations(timeout: 0.5)
        XCTAssertEqual(count, 1)
    }

    func testStopWithoutStartDoesNotUnbalanceGeneration() {
        let monitor = DeviceOrientationMonitor()

        monitor.stop()

        XCTAssertFalse(monitor.isGenerating)
        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 0)
    }

    func testGenerationIsBalancedAcrossRepeatedCycles() {
        let monitor = DeviceOrientationMonitor()

        for _ in 0..<3 {
            monitor.start { _ in }
            monitor.stop()
        }
        monitor.stop()

        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 0)
    }

    func testReleasingAStartedMonitorEndsGeneration() {
        autoreleasepool {
            let monitor = DeviceOrientationMonitor()
            monitor.start { _ in }
            XCTAssertEqual(DeviceOrientationMonitor.generationCount, 1)
        }

        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 0,
                       "a screen torn down without onDisappear must not leak the "
                        + "generation window")
    }

    func testConcurrentMonitorsKeepGenerationUntilTheLastStops() {
        let call = DeviceOrientationMonitor()
        let recorder = DeviceOrientationMonitor()

        call.start { _ in }
        recorder.start { _ in }
        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 2)

        recorder.stop()
        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 1,
                       "the call preview still needs rotation updates")

        call.stop()
        XCTAssertEqual(DeviceOrientationMonitor.generationCount, 0)
    }
}
