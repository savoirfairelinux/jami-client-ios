//
//  Untitled.swift
//  Ring
//
//  Created by kateryna on 2025-03-28.
//  Copyright © 2025 Savoir-faire Linux. All rights reserved.
//

import XCTest
import RxSwift
import RxRelay
@testable import Ring

class MediaManagementServiceTests: XCTestCase {
    
    private var mediaManagementService: MediaManagementService!
    private var mockCallsAdapter: MockCallsAdapter!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var currentCallsEvents: ReplaySubject<CallModel>!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!
    
    private let testCallId = "test-call-id"
    private let testAccountId = "test-account-id"
    
    override func setUp() {
        super.setUp()
        
        mockCallsAdapter = MockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 1)
        disposeBag = DisposeBag()
        
        testCall = CallModel(id: testCallId, accountId: testAccountId)
        calls.accept([testCallId: testCall])
        
        mediaManagementService = MediaManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            currentCallsEvents: currentCallsEvents
        )
    }
    
    override func tearDown() {
        mockCallsAdapter = nil
        calls = nil
        currentCallsEvents = nil
        disposeBag = nil
        testCall = nil
        mediaManagementService = nil
        
        super.tearDown()
    }
    
    func testGetVideoCodec() {
        let expectedCodec = "H264"
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: expectedCodec]
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        
        XCTAssertEqual(result, expectedCodec)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallId, testCallId)
        XCTAssertEqual(mockCallsAdapter.callDetailsAccountId, testAccountId)
    }
    
    func testAudioMuted() {
        var capturedCall: CallModel?
        
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.audioMuted(call: testCallId, mute: true)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertTrue(capturedCall?.audioMuted ?? false)
        XCTAssertEqual(capturedCall?.callId, testCallId)
    }
    
    func testVideoMuted() {
        var capturedCall: CallModel?
        
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.videoMuted(call: testCallId, mute: true)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertTrue(capturedCall?.videoMuted ?? false)
        XCTAssertEqual(capturedCall?.callId, testCallId)
    }
    
    func testCallMediaUpdatedWithExistingMedia() {
        let existingMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        testCall.mediaList = existingMedia
        
        let callDetails = [CallDetailKey.videoCodec.rawValue: "H264"]
        mockCallsAdapter.callDetailsReturnValue = callDetails
        
        var capturedCall: CallModel?
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.callMediaUpdated(call: testCall)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallId, testCallId)
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 0)
    }
    
    func testCallMediaUpdatedWithNoExistingMedia() {
        let mediaList: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        mockCallsAdapter.currentMediaListReturnValue = mediaList
        
        let callDetails = [CallDetailKey.videoCodec.rawValue: "H264"]
        mockCallsAdapter.callDetailsReturnValue = callDetails
        
        var capturedCall: CallModel?
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.callMediaUpdated(call: testCall)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallId, testCallId)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(capturedCall?.mediaList.count, 1)
    }
    
    func testUpdateCallMediaIfNeeded() {
        let mediaList: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        mockCallsAdapter.currentMediaListReturnValue = mediaList
        
        XCTAssertTrue(testCall.mediaList.isEmpty)
        
        mediaManagementService.updateCallMediaIfNeeded(call: testCall)
        
        XCTAssertEqual(testCall.mediaList.count, 1)
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallId, testCallId)
    }
    
    func testHandleRemoteRecordingChanged() {
        var capturedCall: CallModel?
        
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.handleRemoteRecordingChanged(callId: testCallId, record: true)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertTrue(capturedCall?.callRecorded ?? false)
    }
    
    func testHandleCallPlacedOnHold() {
        var capturedCall: CallModel?
        
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.handleCallPlacedOnHold(callId: testCallId, holding: true)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertTrue(capturedCall?.peerHolding ?? false)
    }
    
    func testHandleMediaNegotiationStatus() {
        let mediaList: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        
        let callDetails = [CallDetailKey.videoCodec.rawValue: "H264"]
        mockCallsAdapter.callDetailsReturnValue = callDetails
        
        var capturedCall: CallModel?
        currentCallsEvents
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.handleMediaNegotiationStatus(callId: testCallId, event: "media_negotiation", media: mediaList)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(capturedCall?.mediaList.count, 1)
    }
    
    func testHandleMediaChangeRequest() {
        let requestedMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ],
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
                MediaAttributeKey.label.rawValue: "video_0"
            ]
        ]
        
        testCall.mediaList = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0",
                MediaAttributeKey.muted.rawValue: "false",
                MediaAttributeKey.enabled.rawValue: "true"
            ]
        ]
        
        mediaManagementService.handleMediaChangeRequest(accountId: testAccountId, callId: testCallId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeRequestCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeRequestCallId, testCallId)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeRequestAccountId, testAccountId)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeRequestMedia.count, 2)
        
        let audio = mockCallsAdapter.answerMediaChangeRequestMedia.first
        XCTAssertEqual(audio?[MediaAttributeKey.muted.rawValue], "false")
        XCTAssertEqual(audio?[MediaAttributeKey.enabled.rawValue], "true")
        
        let video = mockCallsAdapter.answerMediaChangeRequestMedia.last
        XCTAssertEqual(video?[MediaAttributeKey.muted.rawValue], "true")
        XCTAssertEqual(video?[MediaAttributeKey.enabled.rawValue], "true")
    }
    
    func testProcessMediaChangeRequestWithNewMedia() {
        let requestedMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
                MediaAttributeKey.label.rawValue: "video_new"
            ]
        ]
        
        mediaManagementService.handleMediaChangeRequest(accountId: testAccountId, callId: testCallId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeRequestMedia.count, 1)
        let newVideo = mockCallsAdapter.answerMediaChangeRequestMedia.first
        XCTAssertEqual(newVideo?[MediaAttributeKey.muted.rawValue], "true")
        XCTAssertEqual(newVideo?[MediaAttributeKey.enabled.rawValue], "true")
    }
}

extension CallModel {
    convenience init(id: String, accountId: String) {
        self.init()
        self.callId = id
        self.accountId = accountId
    }
}
