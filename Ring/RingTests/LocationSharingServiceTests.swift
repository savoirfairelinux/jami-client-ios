//
//  LocationSharingUnitTest.swift
//  RingTests
//
//  Created by Alireza Toghiani on 4/19/23.
//  Copyright © 2023 Savoir-faire Linux. All rights reserved.
//

import XCTest
import RxSwift
import CoreLocation
@testable import Ring

class LocationSharingServiceTests: XCTestCase {

    private var locationSharingService: LocationSharingService!
    private var dbManager: DBManager!
    private var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()

        dbManager = DBManager(profileHepler: ProfileDataHelper(),
                              conversationHelper: ConversationDataHelper(),
                              interactionHepler: InteractionDataHelper(),
                              dbConnections: DBContainer())
        locationSharingService = LocationSharingService(dbManager: dbManager)
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        locationSharingService = nil
        dbManager = nil
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
                    XCTAssertEqual(event.getEventInput(ServiceEventInput.accountId), "accountId")
                    XCTAssertEqual(event.getEventInput(.peerUri), "peerUri")
                    let contentTuple: (String, Bool)? = event.getEventInput(.content)
                    XCTAssertEqual(contentTuple?.0, "content")
                    XCTAssertEqual(contentTuple?.1, true)
                    expect.fulfill()
                }
            })
            .disposed(by: disposeBag)

        locationSharingService.triggerSendLocation(accountId: "accountId", peerUri: "peerUri", content: "content", shouldTryToSave: true)

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
}
