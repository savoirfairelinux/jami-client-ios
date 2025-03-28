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
    
    // MARK: - Test Constants
    
    private enum TestConstants {
        static let videoCodec = "H264"
        static let audioLabel = "audio_0"
        static let videoLabel = "video_0"
        static let newVideoLabel = "video_new"
    }
    
    // MARK: - Properties
    
    private var mediaManagementService: MediaManagementService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var callUpdates: ReplaySubject<CallModel>!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupMocks()
        setupTestCall()
        setupService()
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
    
    // MARK: - Test Setup Helpers
    
    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)
        disposeBag = DisposeBag()
    }
    
    private func setupTestCall() {
        testCall = CallModel.createTestCall()
        calls.accept([CallTestConstants.callId: testCall])
    }
    
    private func setupService() {
        mediaManagementService = MediaManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            callUpdates: callUpdates
        )
    }
    
    // MARK: - Codec Tests
    
    func testGetVideoCodec() {
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec]
        
        let result = mediaManagementService.getVideoCodec(call: testCall)
        
        XCTAssertEqual(result, TestConstants.videoCodec)
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
    
    // MARK: - Audio Tests
    
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
        
        mediaManagementService.audioMuted(call: CallTestConstants.callId, mute: true)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.audioMuted ?? false, "Call audio should be muted")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Event should refer to the correct call")
    }
    
    func testAudioUnmuted() {
        mediaManagementService.audioMuted(call: CallTestConstants.callId, mute: true)
        
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
        
        mediaManagementService.audioMuted(call: CallTestConstants.callId, mute: false)
        
        XCTAssertNotNil(updatedCall)
        XCTAssertFalse(updatedCall?.audioMuted ?? true, "Call audio should be unmuted")
    }
    
    func testAudioMutedWithInvalidCallId() {
        let expectation = expectation(description: "No events published for invalid call")
        expectation.isInverted = true
        
        let disposable = callUpdates
            .take(1)
            .timeout(.milliseconds(500), scheduler: MainScheduler.instance)
            .subscribe(onNext: { _ in
                expectation.fulfill()
            }, onError: { _ in
            })
        
        mediaManagementService.audioMuted(call: CallTestConstants.invalidCallId, mute: true)
        
        wait(for: [expectation], timeout: 1.0)
        disposable.dispose()
    }
    
    // MARK: - Video Tests
    
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
        
        mediaManagementService.videoMuted(call: CallTestConstants.callId, mute: true)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.videoMuted ?? false, "Call video should be muted")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Event should refer to the correct call")
    }
    
    func testVideoUnmuted() {
        mediaManagementService.videoMuted(call: CallTestConstants.callId, mute: true)
        
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
        
        mediaManagementService.videoMuted(call: CallTestConstants.callId, mute: false)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertFalse(updatedCall?.videoMuted ?? true, "Call video should be unmuted")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Event should refer to the correct call")
    }
    
    func testVideoMutedWithInvalidCallId() {
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
        
        mediaManagementService.videoMuted(call: CallTestConstants.invalidCallId, mute: true)
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Remote Recording Tests
    
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
        
        mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.callId, record: true)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.callRecorded ?? false, "Call should be marked as recorded")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Updated call should have the correct ID")
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
        
        mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.callId, record: false)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertFalse(updatedCall?.callRecorded ?? true, "Call should not be marked as recorded")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Updated call should have the correct ID")
    }
    
    func testHandleRemoteRecordingWithInvalidCallId() {
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
        
        mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.invalidCallId, record: true)
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Call Hold Tests
    
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
        
        mediaManagementService.handleCallPlacedOnHold(callId: CallTestConstants.callId, holding: true)
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertTrue(updatedCall?.peerHolding ?? false, "Call should be marked as on hold")
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Updated call should have the correct ID")
    }
    
    // MARK: - Media Update Tests
    
    func testCallMediaUpdatedWithExistingMedia() {
        let existingMedia = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]
        testCall.mediaList = existingMedia
        
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec]
        
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
        XCTAssertEqual(updatedCall?.callId, CallTestConstants.callId, "Updated call should have the correct ID")
    }
    
    func testCallMediaUpdatedWithNoExistingMedia() {
        let expectedMediaList = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]
        mockCallsAdapter.currentMediaListReturnValue = expectedMediaList
        
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec]
        
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
        
        XCTAssertNotNil(updatedCall, "Call event should be published")
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 1, "Should fetch media list exactly once")
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1, "Should fetch call details exactly once")
        
        XCTAssertEqual(updatedCall?.mediaList.count, 1, "Updated call should have exactly one media item")
        
        if let firstMedia = updatedCall?.mediaList.first {
            XCTAssertEqual(firstMedia[MediaAttributeKey.mediaType.rawValue], TestMediaTypes.audio, "Media type should be audio")
            XCTAssertEqual(firstMedia[MediaAttributeKey.label.rawValue], TestConstants.audioLabel, "Media label should match expected value")
        } else {
            XCTFail("Media list should contain at least one item")
        }
    }
    
    func testUpdateCallMediaIfNeeded() {
        let mediaList = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]
        mockCallsAdapter.currentMediaListReturnValue = mediaList
        
        XCTAssertTrue(testCall.mediaList.isEmpty, "Test call should start with empty media list")
        
        mediaManagementService.updateCallMediaIfNeeded(call: testCall)
        
        XCTAssertEqual(testCall.mediaList.count, 1, "Call should have updated media list")
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallCount, 1, "Current media list should be requested once")
        XCTAssertEqual(mockCallsAdapter.currentMediaListCallId, CallTestConstants.callId, "Call ID should match test call ID")
    }
    
    // MARK: - Media Negotiation Tests
    
    func testHandleMediaNegotiationStatus() {
        let mediaList = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]
        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec]
        
        var capturedCall: CallModel?
        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                capturedCall = call
            })
            .disposed(by: disposeBag)
        
        mediaManagementService.handleMediaNegotiationStatus(callId: CallTestConstants.callId, event: "media_negotiation", media: mediaList)
        
        XCTAssertNotNil(capturedCall)
        XCTAssertEqual(mockCallsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(capturedCall?.mediaList.count, 1)
    }
    
    // MARK: - Media Change Request Tests
    
    func testHandleMediaChangeRequest() {
        let requestedMedia = [
            TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel),
            TestMediaFactory.createVideoMedia(label: TestConstants.videoLabel)
        ]
        
        testCall.mediaList = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel, muted: false, enabled: true)]
        
        mediaManagementService.handleMediaChangeRequest(accountId: CallTestConstants.accountId, callId: CallTestConstants.callId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 1, "Answer media change request should be called once")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallId, CallTestConstants.callId, "Call ID should match test call ID")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestAccountId, CallTestConstants.accountId, "Account ID should match test account ID")
        
        guard let mediaArray = mockCallsAdapter.answerMediaChangeResquestMedia else {
            XCTFail("Expected media array to be non-nil")
            return
        }
        
        XCTAssertEqual(mediaArray.count, 2, "Expected media array to have 2 items")
        
        if let audio = mediaArray.first,
           audio[MediaAttributeKey.mediaType.rawValue] == TestMediaTypes.audio {
            XCTAssertEqual(audio[MediaAttributeKey.muted.rawValue], "false", "Audio should preserve existing muted state")
            XCTAssertEqual(audio[MediaAttributeKey.enabled.rawValue], "true", "Audio should preserve existing enabled state")
        } else {
            XCTFail("Audio media item not found or not of type [String: String]")
        }
        
        if let video = mediaArray.last as? [String: String],
            video[MediaAttributeKey.mediaType.rawValue] == TestMediaTypes.video {
            XCTAssertEqual(video[MediaAttributeKey.muted.rawValue], "true", "New video should be muted by default")
            XCTAssertEqual(video[MediaAttributeKey.enabled.rawValue], "true", "New video should be enabled by default")
        } else {
            XCTFail("Video media item not found or not of type [String: String]")
        }
    }
    
    func testHandleMediaChangeRequestWithInvalidCallId() {
        let requestedMedia = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]
        
        mediaManagementService.handleMediaChangeRequest(accountId: CallTestConstants.accountId, callId: CallTestConstants.invalidCallId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 0, "Method should not be called for invalid call ID")
    }
    
    func testProcessMediaChangeRequestWithNewMedia() {
        let requestedMedia = [TestMediaFactory.createVideoMedia(label: TestConstants.newVideoLabel)]
        
        XCTAssertTrue(testCall.mediaList.isEmpty, "Test call should start with empty media list")
        
        mediaManagementService.handleMediaChangeRequest(accountId: CallTestConstants.accountId, callId: CallTestConstants.callId, media: requestedMedia)
        
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 1, "Method should be called exactly once")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallId, CallTestConstants.callId, "Call ID should match test call ID")
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestAccountId, CallTestConstants.accountId, "Account ID should match test account ID")
        
        guard let mediaArray = mockCallsAdapter.answerMediaChangeResquestMedia else {
            XCTFail("Expected media array to be non-nil")
            return
        }
        
        XCTAssertEqual(mediaArray.count, 1, "Expected media array to have 1 item")
        
        if let newVideo = mediaArray.first {
            XCTAssertEqual(newVideo[MediaAttributeKey.mediaType.rawValue], TestMediaTypes.video, "Media type should be video")
            XCTAssertEqual(newVideo[MediaAttributeKey.label.rawValue], TestConstants.newVideoLabel, "Media label should match requested value")
            XCTAssertEqual(newVideo[MediaAttributeKey.muted.rawValue], "true", "New video should be muted by default")
            XCTAssertEqual(newVideo[MediaAttributeKey.enabled.rawValue], "true", "New video should be enabled by default")
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
