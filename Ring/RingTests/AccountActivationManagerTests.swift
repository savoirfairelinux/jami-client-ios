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

final class AccountActivationManagerTests: XCTestCase {

    private var applied: [Bool] = []

    override func setUp() {
        super.setUp()
        applied = []
    }

    private func makeManager(isForeground: Bool,
                             callActive: Bool = false) -> AccountActivationManager {
        return AccountActivationManager(
            isForeground: isForeground,
            callActive: callActive,
            apply: { [weak self] active in self?.applied.append(active) }
        )
    }

    func testBackgroundLaunch_NeverActivates() {
        let manager = makeManager(isForeground: false)
        manager.waitForPendingWork()

        XCTAssertFalse(applied.contains(true),
                       "Account must not be activated when the app is launched into the background")
        XCTAssertEqual(applied.last, false)
    }

    func testForegroundLaunch_Activates() {
        let manager = makeManager(isForeground: true)
        manager.waitForPendingWork()

        XCTAssertEqual(applied.last, true)
    }

    func testForegroundThenBackground_SettlesInactive() {
        let manager = makeManager(isForeground: true)
        manager.setForeground(false)
        manager.setForeground(true)
        manager.setForeground(false)
        manager.waitForPendingWork()

        XCTAssertEqual(applied.last, false,
                       "When the app ends up backgrounded, the account must be inactive")
    }

    func testCallEndsWhileBackground_Deactivates() {
        let manager = makeManager(isForeground: false, callActive: true)
        manager.waitForPendingWork()
        XCTAssertEqual(applied.last, true, "A pending/active call keeps the account active")

        manager.setCallActive(false)
        manager.waitForPendingWork()

        XCTAssertEqual(applied.last, false,
                       "When a call ends and the app is not foreground, the account must deactivate")
    }

    func testIncomingCallWhileBackground_Activates() {
        let manager = makeManager(isForeground: false)
        manager.waitForPendingWork()
        XCTAssertEqual(applied.last, false)

        manager.setCallActive(true)
        manager.waitForPendingWork()
        XCTAssertEqual(applied.last, true,
                       "An incoming/pending call must reactivate the account while backgrounded")
    }

    func testRedundantTransitions_ApplyOnce() {
        let manager = makeManager(isForeground: true)
        manager.setForeground(true)
        manager.setCallActive(false)
        manager.waitForPendingWork()

        XCTAssertEqual(applied, [true],
                       "Only genuine state changes should reach the daemon")
    }

    func testForegroundKeepsActiveEvenWithoutCall() {
        let manager = makeManager(isForeground: true)
        manager.waitForPendingWork()
        XCTAssertEqual(applied.last, true)

        manager.setCallActive(false)
        manager.waitForPendingWork()
        XCTAssertEqual(applied, [true])
    }
}
