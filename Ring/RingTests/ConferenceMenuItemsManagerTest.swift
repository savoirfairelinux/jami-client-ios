/*
*  Copyright (C) 2020 Savoir-faire Linux Inc.
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
@testable import Ring

class ConferenceMenuItemsManagerTest: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testGetMenuItemsForMasterCallNil() {
        let manager = ConferenceMenuItemsManager()
        let conference = nil
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForNotActiveMasterCall() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        let active = false
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForMasterCallWithConferenceGridLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .grid
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.withoutHangUPAndMinimize)
    }

    func testGetMenuItemsForActiveMasterCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.withoutHangUp)
    }

    func testGetMenuItemsForNotActiveMasterCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = false
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.withoutHangUPAndMinimize)
    }

    func testGetMenuItemsForActiveMasterCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.withoutHangUPAndMaximize)
    }

    func testGetMenuItemsForNotActiveMasterCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = false
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference, active) == MenuMode.withoutHangUPAndMinimize)
    }
}
