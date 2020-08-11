/*
 *  Copyright (C) 2017-2019 Savoir-faire Linux Inc.
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

import XCTest
@testable import Ring

/**
 A test class designed to validate that the ServiceEvent class is reacting properly.
 */
class ServiceEventTests: XCTestCase {

    /// The ServiceEvent that will be used during the tests.
    private var event: ServiceEvent?

    override func setUp() {
        super.setUp()
        self.event = ServiceEvent(withEventType: .accountsChanged)
    }

    /**
     Tests that the event is properly created and populated.
     */
    func testCreateEvent() {
        XCTAssertNotNil(self.event)
        XCTAssertTrue(self.event?.eventType == ServiceEventType.accountsChanged)
    }

    /**
     Tests that the event has its String metadata properly created and populated.
     */
    func testAddStringMetadata() {
        let testString = "Identifier"
        self.event?.addEventInput(.id, value: testString)

        let resultString: String = (self.event?.getEventInput(.id))!
        XCTAssertEqual(resultString, testString)
    }

    /**
     Tests that the event has its Int metadata properly created and populated.
     */
    func testAddIntMetadata() {
        let testInt = 1
        self.event?.addEventInput(.id, value: testInt)

        let resultInt: Int = (self.event?.getEventInput(.id))!
        XCTAssertEqual(resultInt, testInt)
    }
}
