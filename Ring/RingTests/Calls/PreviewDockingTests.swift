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

import XCTest
@testable import Ring

final class PreviewDockingTests: XCTestCase {

    func testDockingAndRestorationSemanticsForBothEdges() {
        XCTAssertFalse(PreviewDocking.shouldDock(
            outwardDistance: 35, outwardVelocity: 0, previewWidth: 120))
        XCTAssertTrue(PreviewDocking.shouldDock(
            outwardDistance: 40, outwardVelocity: 0, previewWidth: 120))
        XCTAssertTrue(PreviewDocking.shouldDock(
            outwardDistance: 0, outwardVelocity: 650, previewWidth: 120))
        XCTAssertEqual(PreviewDockSide.left.outwardComponent(of: -80), 80)
        XCTAssertEqual(PreviewDockSide.right.outwardComponent(of: 80), 80)
        XCTAssertFalse(PreviewDocking.shouldRestore(
            inwardDistance: 31, inwardVelocity: 0))
        XCTAssertTrue(PreviewDocking.shouldRestore(
            inwardDistance: 32, inwardVelocity: 0))
        XCTAssertTrue(PreviewDocking.shouldRestore(
            inwardDistance: 0, inwardVelocity: 500))
        let leftHandle = PreviewDockHandleView()
        leftHandle.configure(side: .left)
        leftHandle.updateRestorationProgress(distance: 40, previewWidth: 120)
        let rightHandle = PreviewDockHandleView()
        rightHandle.configure(side: .right)
        rightHandle.updateRestorationProgress(distance: 40, previewWidth: 120)
        XCTAssertEqual(leftHandle.transform.tx, 40)
        XCTAssertEqual(rightHandle.transform.tx, -40)
    }
}
