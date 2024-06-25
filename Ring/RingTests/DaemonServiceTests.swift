/*
 *  Copyright (C) 2016-2019 Savoir-faire Linux Inc.
 *
 *  Author: Romain Bertozzi <romain.bertozzi@savoirfairelinux.com>
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

@testable import Ring
import XCTest

/**
 A test class designed to validate that the daemon service runs as expected.
 It will test for example that:
 - the daemon correctly starts
 - correctly stops
 - fails to achieve one or the other as we expect it to do.
 */
class DaemonServiceTests: XCTestCase {
    /**
     Tests that the Ring Daemon Service starts the daemon correctly

     - Returns: the DaemonService used to do the test
     */
    func testStart() -> DaemonService {
        var hasStartError = false
        let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
        do {
            try daemonService.startDaemon()
        } catch {
            hasStartError = true
        }
        XCTAssertFalse(hasStartError)
        XCTAssertTrue(daemonService.daemonStarted)
        return daemonService
    }

    /**
     Tests that the Ring Daemon Service stops the daemon correctly

     - Returns: the DaemonService used to do the test
     */
    func testStop() -> DaemonService {
        var hasStopError = false
        let daemonService = testStart()
        do {
            try daemonService.stopDaemon()
        } catch {
            hasStopError = true
        }
        XCTAssertFalse(hasStopError)
        XCTAssertFalse(daemonService.daemonStarted)
        return daemonService
    }

    /**
     Tests that the Ring Daemon Service does not stop if it is not currently running.
     */
    func testDaemonNotRunningException() {
        let daemonService = DaemonService(dRingAdaptor: DRingAdapter())
        XCTAssertThrowsError(try daemonService.stopDaemon()) { error in
            XCTAssertEqual(error as? StopDaemonError, StopDaemonError.daemonNotRunning)
        }
    }

    /**
     Tests that the Ring Daemon Service fails to initialize.
     This test use a dedicated DRingAdaptor fixture.
     */
    func testDaemonFailToInit() {
        let daemonService = DaemonService(dRingAdaptor: FixtureFailInitDRingAdapter())
        XCTAssertThrowsError(try daemonService.startDaemon()) { error in
            XCTAssertEqual(error as? StartDaemonError, StartDaemonError.initializationFailure)
        }
    }

    /**
     Tests that the Ring Daemon Service fails to start.
     This test use a dedicated DRingAdaptor fixture.
     */
    func testDaemonFailToStart() {
        let daemonService = DaemonService(dRingAdaptor: FixtureFailStartDRingAdapter())
        XCTAssertThrowsError(try daemonService.startDaemon()) { error in
            XCTAssertEqual(error as? StartDaemonError, StartDaemonError.startFailure)
        }
    }
}
