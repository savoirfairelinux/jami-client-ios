/*
 *  Copyright (C) 2023 Savoir-faire Linux Inc.
 *
 * Author: Alireza Toghiani Khorasgani alireza.toghiani@savoirfairelinux.com *
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
import RxSwift
import CoreLocation
@testable import Ring

class LocationSharingServiceTests: XCTestCase {

    private var locationSharingService: LocationSharingService!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        locationSharingService = LocationSharingService()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        locationSharingService = nil
        disposeBag = nil

        super.tearDown()
    }

    func testLocationSerialization() {
        // Test if the location serialization works as expected

        let location = SerializableLocation(type: "Position", lat: 37.7749, long: -122.4194, alt: 56.078, time: 1681923)
        let serializedLocation = LocationSharingService.serializeLocation(location: location)
        XCTAssertNotNil(serializedLocation, "Serialization should return a non-nil String")
    }

    func testLocationDeserialization() {
        // Test if the location deserialization works as expected
        let json = "{\"lat\":45.534305783044914,\"long\":-73.6208561630721,\"time\":1681923961249,\"type\":\"Position\"}"
        let deserializedLocation = LocationSharingService.deserializeLocation(json: json)
        XCTAssertNotNil(deserializedLocation, "Deserialization should return a non-nil SerializableLocation")
    }

    func testSendLocationEvent() {
        // Test if the send location event is triggered correctly
        let expect = expectation(description: "Send location event triggered")

        locationSharingService.getLocationServiceEventStream()
            .subscribe(onNext: { event in
                if event.eventType == .sendLocation {
                    XCTAssertEqual(event.getEventInput(ServiceEventInput.accountId), accountId1)
                    XCTAssertEqual(event.getEventInput(.peerUri), jamiId1)
                    let contentTuple: (String, Bool)? = event.getEventInput(.content)
                    XCTAssertEqual(contentTuple?.0, "content")
                    XCTAssertEqual(contentTuple?.1, true)
                    expect.fulfill()
                }
            })
            .disposed(by: disposeBag)

        locationSharingService.triggerSendLocation(accountId: accountId1, peerUri: jamiId1, content: "content", shouldTryToSave: true)

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testStopSharingEvent() {
        // Test if the stop sharing event is triggered correctly
        let expect = expectation(description: "Stop sharing event triggered")

        locationSharingService.getLocationServiceEventStream()
            .subscribe(onNext: { event in
                if event.eventType == .stopLocationSharing {
                    XCTAssertEqual(event.getEventInput(.accountId), "accountId")
                    XCTAssertEqual(event.getEventInput(.peerUri), "peerUri")
                    XCTAssertEqual(event.getEventInput(.content), "content")
                    expect.fulfill()
                }
            })
            .disposed(by: disposeBag)

        locationSharingService.triggerStopSharing(accountId: "accountId", peerUri: "peerUri", content: "content")

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testHandleReceivedLocationUpdate() {
        let accountId = "accountId"
        let peerUri = "peerUri"
        let messageId = "messageId"
        let content = "{\"type\":\"Position\",\"lat\":37.7749,\"long\":-122.4194,\"time\":10000}"

        locationSharingService.handleReceivedLocationUpdate(from: peerUri, to: accountId, messageId: messageId, locationJSON: content)

        let peerUriAndData = locationSharingService.peerUriAndLocationReceived.value
        XCTAssertEqual(peerUriAndData.0, peerUri)
        XCTAssertEqual(peerUriAndData.1?.latitude, 37.7749)
        XCTAssertEqual(peerUriAndData.1?.longitude, -122.4194)
        XCTAssertEqual(peerUriAndData.2, 10000 / 60000)
    }

    func testPositionResentWithSameTimeKeepsReceiving() {
        let position = "{\"type\":\"Position\",\"lat\":37.7749,\"long\":-122.4194,\"time\":10000}"
        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId1", locationJSON: position)
        let incomingInstance = locationSharingService.getIncomingInstances().get(accountId1, jamiId1)
        let nineMinutesAgo = Date(timeIntervalSinceNow: -9 * 60)
        incomingInstance?.lastReceivedDate = nineMinutesAgo

        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId2", locationJSON: position)

        XCTAssertNotNil(incomingInstance)
        XCTAssertGreaterThan(incomingInstance?.lastReceivedDate ?? nineMinutesAgo, nineMinutesAgo)
    }

    func testStopWithSameTimeAsLastPositionStopsReceiving() {
        let position = "{\"type\":\"Position\",\"lat\":37.7749,\"long\":-122.4194,\"time\":10000}"
        let stop = "{\"type\":\"Stop\",\"time\":10000}"
        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId1", locationJSON: position)

        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId2", locationJSON: stop)

        XCTAssertFalse(locationSharingService.isAlreadySharing(accountId: accountId1, contactUri: jamiId1))
        XCTAssertNil(locationSharingService.peerUriAndLocationReceived.value.1)
    }

    func testOlderPositionIsIgnored() {
        let newerPosition = "{\"type\":\"Position\",\"lat\":37.7749,\"long\":-122.4194,\"time\":20000}"
        let olderPosition = "{\"type\":\"Position\",\"lat\":45.5017,\"long\":-73.5673,\"time\":10000}"
        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId1", locationJSON: newerPosition)

        locationSharingService.handleReceivedLocationUpdate(from: jamiId1, to: accountId1, messageId: "messageId2", locationJSON: olderPosition)

        XCTAssertEqual(locationSharingService.peerUriAndLocationReceived.value.1?.latitude, 37.7749)
    }

    func testStopReceivingLocation() {
        let accountId = "accountId"
        let contactUri = "contactUri"

        locationSharingService.stopReceivingLocation(accountId: accountId, contactUri: contactUri)

        let peerUriAndData = locationSharingService.peerUriAndLocationReceived.value
        XCTAssertEqual(peerUriAndData.0, contactUri)
        XCTAssertNil(peerUriAndData.1)
        XCTAssertNil(peerUriAndData.2)
    }

    func testStartAndStopReceivingService() {
        locationSharingService.startReceivingService()
        XCTAssertNotNil(locationSharingService.receivingService, "receivingService should not be nil after starting")

        locationSharingService.stopReceivingService()
        XCTAssertNil(locationSharingService.receivingService, "receivingService should be nil after stopping")
    }

    func testIsAlreadySharing() {
        let accountId = "accountId"
        let contactUri = "contactUri"

        XCTAssertFalse(locationSharingService.isAlreadySharing(accountId: accountId, contactUri: contactUri))

        locationSharingService.getIncomingInstances().insertOrUpdate(IncomingLocationSharingInstance(accountId: accountId,
                                                                                                     contactUri: contactUri,
                                                                                                     lastReceivedDate: Date(),
                                                                                                     lastReceivedTimeStamp: 0))

        XCTAssertTrue(locationSharingService.isAlreadySharing(accountId: accountId, contactUri: contactUri))
    }

    func testIsAlreadySharingMyLocation() {
        let accountId = "accountId"
        let contactUri = "contactUri"

        XCTAssertFalse(locationSharingService.isAlreadySharingMyLocation(accountId: accountId, contactUri: contactUri))

        locationSharingService.getOutgoingInstances().insertOrUpdate(OutgoingLocationSharingInstance(locationSharingService: locationSharingService,
                                                                                                     accountId: accountId,
                                                                                                     contactUri: contactUri))

        XCTAssertTrue(locationSharingService.isAlreadySharingMyLocation(accountId: accountId, contactUri: contactUri))
    }

    func testGetMyLocationSharingRemainedTime() {
        let accountId = "accountId"
        let contactUri = "contactUri"
        let duration: TimeInterval = 300

        locationSharingService.getOutgoingInstances().insertOrUpdate(OutgoingLocationSharingInstance(locationSharingService: locationSharingService,
                                                                                                     accountId: accountId,
                                                                                                     contactUri: contactUri,
                                                                                                     duration: duration))

        let remainedTime = locationSharingService.getMyLocationSharingRemainedTime(accountId: accountId, contactUri: contactUri)
        XCTAssertGreaterThanOrEqual(remainedTime, 0)
        XCTAssertLessThanOrEqual(remainedTime, Int(duration / 60))
    }

    func testStartAndStopSharingLocation() {
        let accountId = "accountId"
        let contactUri = "contactUri"

        locationSharingService.startSharingLocation(from: accountId, to: contactUri)
        XCTAssertTrue(locationSharingService.isAlreadySharingMyLocation(accountId: accountId, contactUri: contactUri))

        locationSharingService.stopSharingLocation(accountId: accountId, contactUri: contactUri)
        XCTAssertFalse(locationSharingService.isAlreadySharingMyLocation(accountId: accountId, contactUri: contactUri))
    }
}
