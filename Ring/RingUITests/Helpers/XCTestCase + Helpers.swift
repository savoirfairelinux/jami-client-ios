/*
 *  Copyright (C) 2024 Savoir-faire Linux Inc.
 *
 *  Author: Kateryna Kostiuk <kateryna.kostiuk@savoirfairelinux.com>
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

extension XCTestCase {

    var defaultTimeout: TimeInterval { 30 }

    @discardableResult
    func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let timeout = timeout ?? defaultTimeout
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element did not appear within \(timeout) seconds")
        return exists
    }

    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeout = timeout ?? defaultTimeout
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: timeout), .completed,
                       "Element still present after \(timeout) seconds")
    }

    func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval? = nil) {
        let timeout = timeout ?? defaultTimeout
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: timeout), .completed,
                       "Element not hittable within \(timeout) seconds")
        element.tap()
    }

    func waitForLabel(_ element: XCUIElement, toEqual expected: String, timeout: TimeInterval? = nil) {
        let timeout = timeout ?? defaultTimeout
        let matched = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [matched], timeout: timeout), .completed,
                       "Label did not become '\(expected)' within \(timeout) seconds")
    }

    func waitForSeconds(_ seconds: TimeInterval) {
        let expectation = XCTestExpectation(description: "Waiting for \(seconds) seconds")
        let result = XCTWaiter.wait(for: [expectation], timeout: seconds)
        if result != .timedOut {
            print("Wait finished earlier than expected")
        }
    }
}
