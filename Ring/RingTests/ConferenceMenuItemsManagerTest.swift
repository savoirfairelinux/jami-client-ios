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
        let conference: CallModel? = nil
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForeMasterCallWithoutActiveCall() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        let active: Bool? = nil
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForMasterCallWithConferenceGridLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .grid
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.withoutHangUPAndMinimize)
    }

    func testGetMenuItemsForActiveMasterCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.withoutHangUp)
    }

    func testGetMenuItemsForNotActiveMasterCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = false
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.withoutHangUPAndMinimize)
    }

    func testGetMenuItemsForActiveMasterCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = true
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.withoutHangUPAndMaximize)
    }

    func testGetMenuItemsForNotActiveMasterCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = false
        XCTAssertTrue(manager.getMenuItemsForMasterCall(conference: conference, active: active) == MenuMode.withoutHangUPAndMinimize)
    }

    func testGetMenuItemsForNilConference() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = nil
        let call: CallModel? = CallModel()
        let active = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForNilCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = nil
        let active = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.onlyName)
    }

    func testGetMenuItemsWithoutActiveCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = nil
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.onlyName)
    }

    func testGetMenuItemsForConnectingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .connecting
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMaximizeAndMinimize)
    }

    func testGetMenuItemsForRingingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .ringing
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMaximizeAndMinimize)
    }

    func testGetMenuItemsForHoldingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .hold
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMaximizeAndMinimize)
    }

    func testGetMenuItemsForCallWithConferenceGridLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .grid
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMinimize)
    }

    func testGetMenuItemsForActiveCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .oneWithSmal
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.all)
    }

    func testGetMenuItemsForNotActiveCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .oneWithSmal
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMinimize)
    }

    func testGetMenuItemsForActiveCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .one
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = true
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMaximize)
    }

    func testGetMenuItemsForNotActiveCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .one
        let call: CallModel? = CallModel()
        call?.state = .current
        let active: Bool? = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, conference: conference, active: active) == MenuMode.withoutMinimize)
    }
}
