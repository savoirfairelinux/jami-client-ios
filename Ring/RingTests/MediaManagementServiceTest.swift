/*
 *  Copyright (C) 2025-2025 Savoir-faire Linux Inc.
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
import RxRelay
@testable import Ring

class MediaManagementServiceTests: XCTestCase {
    
    private var mediaManagementService: MediaManagementService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var callUpdates: ReplaySubject<CallModel>!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!
    
    private let testCallId = "test-call-id"
    private let testAccountId = "test-account-id"
    
    override func setUp() {
        super.setUp()
        
        mockCallsAdapter = ObjCMockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)
        disposeBag = DisposeBag()
        
        testCall = CallModel(id: testCallId, accountId: testAccountId)
        calls.accept([testCallId: testCall])
        
        mediaManagementService = MediaManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            callUpdates: callUpdates
        )
    }
    
    override func tearDown() {
        mockCallsAdapter = nil
        calls = nil
        callUpdates = nil
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
    }
    
    func testGetVideoCodecWithNilResponse() {
        mockCallsAdapter.callDetailsReturnValue = nil
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        
        XCTAssertNil(result)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
    }
    
    func testGetVideoCodecWithEmptyDictionary() {
        mockCallsAdapter.callDetailsReturnValue = [:]
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        
        XCTAssertNil(result)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
    }
    
    func testGetVideoCodecWithMissingCodecKey() {
        mockCallsAdapter.callDetailsReturnValue = ["some_other_key": "some_value"]
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        
        XCTAssertNil(result)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
    }
    
    func testGetVideoCodecWithEmptyCodecValue() {
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: ""]
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        XCTAssertEqual(result, "")
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
    }
    
    func testAudioMuted() {
        var updatedCall: CallModel?

        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.audioMuted(call: testCallId, mute: true)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.audioMuted ?? false, "Call audio should be muted")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Event should refer to the correct call")
    }
    
    func testAudioUnmuted() {
        mediaManagementService.audioMuted(call: testCallId, mute: true)
        
        var updatedCall: CallModel?
        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.audioMuted(call: testCallId, mute: false)
        
        XCTAssertNotNil(updatedCall)
        XCTAssertFalse(updatedCall?.audioMuted ?? true, "Call audio should be unmuted")
    }
    
    func testAudioMutedWithInvalidCallId() {
        let invalidCallId = "non-existent-call-id"
        
        // This shouldn't crash
        mediaManagementService.audioMuted(call: invalidCallId, mute: true)
        
        // Create an expectation that should not be fulfilled
        let expectation = expectation(description: "No events published for invalid call")
        expectation.isInverted = true
        
        // Subscribe with a slightly longer timeout
        let disposable = callUpdates
            .take(1)
            .timeout(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: { _ in
                // If we get an event, fulfill the expectation (which will fail the test)
                expectation.fulfill()
            }, onError: { _ in
            })
        
        // Wait for the expectation with enough time for the timeout to occur
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        disposable.dispose()
    }
    
    func testVideoMuted() {
        var updatedCall: CallModel?

        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.videoMuted(call: testCallId, mute: true)

        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.videoMuted ?? false, "Call video should be muted")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Event should refer to the correct call")
    }
    
    func testVideoUnmuted() {
        mediaManagementService.videoMuted(call: testCallId, mute: true)
        
        var updatedCall: CallModel?
        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.videoMuted(call: testCallId, mute: false)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertFalse(updatedCall?.videoMuted ?? true, "Call video should be unmuted")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Event should refer to the correct call")
    }
    
    func testVideoMutedWithInvalidCallId() {
        let invalidCallId = "non-existent-call-id"
        
        // This shouldn't crash
        mediaManagementService.videoMuted(call: invalidCallId, mute: true)
        
        // No event should be published for an invalid call
        let expectation = XCTestExpectation(description: "No events published for invalid call")
        expectation.isInverted = true
        
        callUpdates
            .take(1)
            .timeout(.milliseconds(300), scheduler: MainScheduler.instance)
            .subscribe(onNext: { _ in
                XCTFail("An event was unexpectedly published for an invalid call ID")
            }, onError: { _ in
            })
            .disposed(by: disposeBag)
        
        wait(for: [expectation], timeout: 0.5)
    }

    func testHandleRemoteRecordingChanged() {
        testCall.callRecorded = false

        var updatedCall: CallModel?

        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)

        mediaManagementService.handleRemoteRecordingChanged(callId: testCallId, record: true)

        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.callRecorded ?? false, "Call should be marked as recorded")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Updated call should have the correct ID")
    }

    func testHandleRemoteRecordingDisabled() {
        testCall.callRecorded = true

        var updatedCall: CallModel?

        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)

        mediaManagementService.handleRemoteRecordingChanged(callId: testCallId, record: false)

        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertFalse(updatedCall?.callRecorded ?? true, "Call should not be marked as recorded")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Updated call should have the correct ID")
    }

    func testHandleRemoteRecordingWithInvalidCallId() {
        let invalidCallId = "non-existent-call-id"

        // This shouldn't crash
        mediaManagementService.handleRemoteRecordingChanged(callId: invalidCallId, record: true)

        // Ensure no event is published
        let expectation = XCTestExpectation(description: "No events published for invalid call")
        expectation.isInverted = true

        callUpdates
            .take(1)
            .timeout(.milliseconds(300), scheduler: MainScheduler.instance)
            .subscribe(onNext: { _ in
                XCTFail("An event was unexpectedly published for an invalid call ID")
            }, onError: { _ in
            })
            .disposed(by: disposeBag)

        wait(for: [expectation], timeout: 0.5)
    }

    func testHandleCallPlacedOnHold() {
        var updatedCall: CallModel?

        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)

        mediaManagementService.handleCallPlacedOnHold(callId: testCallId, holding: true)

        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.peerHolding ?? false, "Call should be marked as on hold")
        XCTAssertEqual(updatedCall?.callId, testCallId, "Updated call should have the correct ID")
    }

    func testCallMediaUpdatedWithExistingMedia() {
        let existingMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        testCall.mediaList = existingMedia

        let expectedCallDetails = [CallDetailKey.videoCodec.rawValue: "H264"]
        mockCallsAdapter.callDetailsReturnValue = expectedCallDetails

        var updatedCall: CallModel?
        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.callMediaUpdated(call: testCall)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1, "Call details should be requested once")
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 0, "Current media list should not be requested when media already exists")
    }
    
    func testCallMediaUpdatedWithNoExistingMedia() {
        let expectedMediaList: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        mockCallsAdapter.currentMediaListReturnValue = expectedMediaList
        
        let expectedCallDetails = [CallDetailKey.videoCodec.rawValue: "H264"]
        mockCallsAdapter.callDetailsReturnValue = expectedCallDetails
        
        XCTAssertTrue(testCall.mediaList.isEmpty, "Test call should start with no media")
        
        var updatedCall: CallModel?
        callUpdates
            .take(1)
            .timeout(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { call in
                updatedCall = call
            }, onError: { error in
                XCTFail("No call event was published within timeout: \(error)")
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.callMediaUpdated(call: testCall)
        
        // Assert: Verify results
        XCTAssertNotNil(updatedCall, "Call event should be published")
        
        // Verify adapter interactions
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 1, 
                      "Should fetch media list exactly once")
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1, 
                      "Should fetch call details exactly once")
        
        // Verify call state
        XCTAssertEqual(updatedCall?.mediaList.count, 1, 
                      "Updated call should have exactly one media item")
        
        // Verify media content
        if let firstMedia = updatedCall?.mediaList.first {
            XCTAssertEqual(firstMedia[MediaAttributeKey.mediaType.rawValue], 
                          MediaAttributeValue.audio.rawValue,
                          "Media type should be audio")
            XCTAssertEqual(firstMedia[MediaAttributeKey.label.rawValue], 
                          "audio_0",
                          "Media label should match expected value")
        } else {
            XCTFail("Media list should contain at least one item")
        }
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
        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)

        // Currently event not used. Provide any value
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
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 1,
                     "answerMediaChangeResquestCallCount should be 1 but was \(mockCallsAdapter.answerMediaChangeResquestCallCount)")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallId, testCallId,
                     "Call ID should match test call ID")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestAccountId, testAccountId,
                     "Account ID should match test account ID")
        
        guard let mediaArray = mockCallsAdapter.answerMediaChangeResquestMedia else {
            XCTFail("Expected media array to be non-nil")
            return
        }
        
        XCTAssertEqual(mediaArray.count, 2, "Expected media array to have 2 items")
        
        // Verify audio media item (should preserve existing settings)
        if let audio = mediaArray.first,
           audio[MediaAttributeKey.mediaType.rawValue] == MediaAttributeValue.audio.rawValue {
            XCTAssertEqual(audio[MediaAttributeKey.muted.rawValue], "false", 
                         "Audio should preserve existing muted state")
            XCTAssertEqual(audio[MediaAttributeKey.enabled.rawValue], "true", 
                         "Audio should preserve existing enabled state")
        } else {
            XCTFail("Audio media item not found or not of type [String: String]")
        }
        
        // Verify video media item (should use default settings)
        if let video = mediaArray.last as? [String: String],
            video[MediaAttributeKey.mediaType.rawValue] == MediaAttributeValue.video.rawValue {
            XCTAssertEqual(video[MediaAttributeKey.muted.rawValue], "true",
                         "New video should be muted by default")
            XCTAssertEqual(video[MediaAttributeKey.enabled.rawValue], "true", 
                         "New video should be enabled by default")
        } else {
            XCTFail("Video media item not found or not of type [String: String]")
        }
    }
    
    func testHandleMediaChangeRequestWithInvalidCallId() {
        let invalidCallId = "non-existent-call-id"
        let requestedMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0"
            ]
        ]
        
        // This shouldn't crash
        mediaManagementService.handleMediaChangeRequest(accountId: testAccountId, callId: invalidCallId, media: requestedMedia)
        
        // Verify the adapter method wasn't called
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 0,
                     "Method should not be called for invalid call ID")
    }
    
    func testProcessMediaChangeRequestWithNewMedia() {
        let requestedMedia: [[String: String]] = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
                MediaAttributeKey.label.rawValue: "video_new" // Label not in existing media
            ]
        ]
        
        XCTAssertTrue(testCall.mediaList.isEmpty, "Test call should start with empty media list")
        
        mediaManagementService.handleMediaChangeRequest(accountId: testAccountId, callId: testCallId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 1,
                      "Method should be called exactly once")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallId, testCallId,
                      "Call ID should match test call ID")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestAccountId, testAccountId,
                      "Account ID should match test account ID")
        
        guard let mediaArray = mockCallsAdapter.answerMediaChangeResquestMedia else {
            XCTFail("Expected media array to be non-nil")
            return
        }
        
        XCTAssertEqual(mediaArray.count, 1, "Expected media array to have 1 item")
        
        // Verify new video media item has default values
        if let newVideo = mediaArray.first as? [String: String] {
            XCTAssertEqual(newVideo[MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.video.rawValue,
                          "Media type should be video")
            XCTAssertEqual(newVideo[MediaAttributeKey.label.rawValue], "video_new",
                          "Media label should match requested value")
            XCTAssertEqual(newVideo[MediaAttributeKey.muted.rawValue], "true",
                          "New video should be muted by default")
            XCTAssertEqual(newVideo[MediaAttributeKey.enabled.rawValue], "true",
                          "New video should be enabled by default")
        } else {
            XCTFail("Expected media item not found or not of type [String: String]")
        }
    }
}

extension CallModel {
    convenience init(id: String, accountId: String) {
        self.init()
        self.callId = id
        self.accountId = accountId
    }
}
