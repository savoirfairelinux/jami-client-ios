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

    func testGetMenuItemsForLocalCallNil() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = nil
        let active = true
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name])
    }

    func testGetMenuItemsForeLocalCallWithoutActiveCall() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        let active: Bool? = nil
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name])
    }

    func testGetMenuItemsForLocalCallWithConferenceGridLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .grid
        let active = true
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name, .maximize, .muteAudio])
    }

    func testGetMenuItemsForActiveLocalCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = true
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name, .maximize, .minimize, .muteAudio])
    }

    func testGetMenuItemsForNotActiveLocalCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .oneWithSmal
        let active = false
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name, .maximize, .muteAudio])
    }

    func testGetMenuItemsForActiveLocalCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = true
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name, .minimize, .muteAudio])
    }

    func testGetMenuItemsForNotActiveLocalCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference = CallModel()
        conference.layout = .one
        let active = false
        XCTAssertTrue(manager.getMenuItemsForLocalCall(conference: conference, active: active) == [.name, .maximize, .muteAudio])
    }

    func testGetMenuItemsForNilConference() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = nil
        let call: CallModel? = CallModel()
        let active = true
        let role = RoleInCall.host
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name])
    }

    func testGetMenuItemsForNilCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = nil
        let active = true
        let role = RoleInCall.host
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name])
    }

    func testGetMenuItemsWithoutActiveCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .current
        let role = RoleInCall.host
        let active: Bool? = nil
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name])
    }

    func testGetMenuItemsForConnectingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .connecting
        let role = RoleInCall.host
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .hangup])
    }

    func testGetMenuItemsForRingingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .ringing
        let role = RoleInCall.host
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .hangup])
    }

    func testGetMenuItemsForHoldingCall() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        let call: CallModel? = CallModel()
        call?.state = .hold
        let role = RoleInCall.host
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .hangup])
    }

    func testGetMenuItemsForCallWithConferenceGridLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .grid
        let call: CallModel? = CallModel()
        call?.state = .current
        let role = RoleInCall.host
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .maximize, .muteAudio, .setModerator, .hangup])
    }

    func testGetMenuItemsForActiveCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .oneWithSmal
        let call: CallModel? = CallModel()
        let role = RoleInCall.host
        call?.state = .current
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .maximize, .minimize, .muteAudio, .setModerator, .hangup])
    }

    func testGetMenuItemsForNotActiveCallWithConferenceOneWithSmalLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .oneWithSmal
        let call: CallModel? = CallModel()
        let role = RoleInCall.host
        call?.state = .current
        let active: Bool? = false
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .maximize, .muteAudio, .setModerator, .hangup])
    }

    func testGetMenuItemsForActiveCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .one
        let call: CallModel? = CallModel()
        call?.state = .current
        let role = RoleInCall.host
        let active: Bool? = true
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .minimize, .muteAudio, .setModerator, .hangup])
    }

    func testGetMenuItemsForNotActiveCallWithConferenceOneLayout() {
        let manager = ConferenceMenuItemsManager()
        let conference: CallModel? = CallModel()
        conference?.layout = .one
        let call: CallModel? = CallModel()
        call?.state = .current
        let role = RoleInCall.host
        let active: Bool? = false
        let isHost = false
        XCTAssertTrue(manager.getMenuItemsFor(call: call, isHost: isHost, conference: conference, active: active, role: role) == [.name, .maximize, .muteAudio, .setModerator, .hangup])
    }
}
