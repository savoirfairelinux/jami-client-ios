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

    private enum TestConstants {
        static let videoCodec = "H264"
        static let audioLabel = "audio_0"
        static let videoLabel = "video_0"
        static let newVideoLabel = "video_new"
    }

    private var mediaManagementService: MediaManagementService!
    private var mockCallsAdapter: ObjCMockCallsAdapter!
    private var calls: SynchronizedRelay<CallsDictionary>!
    private var callUpdates: ReplaySubject<CallModel>!
    private var disposeBag: DisposeBag!
    private var testCall: CallModel!
    private var queueHelper: ThreadSafeQueueHelper!
    private var responseStream: PublishSubject<ServiceEvent>!

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
        queueHelper = nil
        responseStream = nil
        super.tearDown()
    }

    private func setupMocks() {
        mockCallsAdapter = ObjCMockCallsAdapter()
        callUpdates = ReplaySubject<CallModel>.create(bufferSize: 1)
        queueHelper = ThreadSafeQueueHelper(label: "com.ring.callsManagementTest", qos: .userInitiated)
        calls = SynchronizedRelay<CallsDictionary>(initialValue: [:], queueHelper: queueHelper)
        responseStream = PublishSubject<ServiceEvent>()
        disposeBag = DisposeBag()
    }

    private func setupTestCall() {
        testCall = CallModel.createTestCall()
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }
    }

    private func setupService() {
        mediaManagementService = MediaManagementService(
            callsAdapter: mockCallsAdapter,
            calls: calls,
            callUpdates: callUpdates,
            responseStream: responseStream
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

    func testAudioMuted() async {
        let expectation = XCTestExpectation(description: "Audio mute event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertTrue(call.audioMuted)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.audioMuted(call: CallTestConstants.callId, mute: true)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testAudioUnmuted() async {
        testCall.audioMuted = true
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Audio unmute event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertFalse(call.audioMuted)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.audioMuted(call: CallTestConstants.callId, mute: false)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testAudioMutedWithInvalidCallId() async {
        await mediaManagementService.audioMuted(call: CallTestConstants.invalidCallId, mute: true)

        XCTAssertEqual(testCall.audioMuted, false, "Call audio mute state should not change")
    }

    // MARK: - Video Tests

    func testVideoMuted() async {
        let expectation = XCTestExpectation(description: "Video mute event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertTrue(call.videoMuted)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.videoMuted(call: CallTestConstants.callId, mute: true)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testVideoUnmuted() async {
        testCall.videoMuted = true
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Video unmute event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertFalse(call.videoMuted)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.videoMuted(call: CallTestConstants.callId, mute: false)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testVideoMutedWithInvalidCallId() async {
        await mediaManagementService.videoMuted(call: CallTestConstants.invalidCallId, mute: true)

        XCTAssertEqual(testCall.videoMuted, false, "Call video mute state should not change")
    }

    // MARK: - Remote Recording Tests

    func testHandleRemoteRecordingChanged() async {
        let expectation = XCTestExpectation(description: "Remote recording event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertTrue(call.callRecorded)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.callId, record: true)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleRemoteRecordingDisabled() async {
        testCall.callRecorded = true
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Remote recording disabled event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertFalse(call.callRecorded)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.callId, record: false)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleRemoteRecordingWithInvalidCallId() async {
        await mediaManagementService.handleRemoteRecordingChanged(callId: CallTestConstants.invalidCallId, record: true)

        XCTAssertEqual(testCall.callRecorded, false, "Call recording state should not change")
    }

    // MARK: - Call Hold Tests

    func testHandleCallPlacedOnHold() async {
        let expectation = XCTestExpectation(description: "Call hold event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertTrue(call.peerHolding)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.handleCallPlacedOnHold(callId: CallTestConstants.callId, holding: true)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Media Update Tests

    func testCallMediaUpdatedWithExistingMedia() async {
        let mediaList: [[String: String]] = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]

        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec
        ]

        testCall.mediaList = mediaList
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Call media updated event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertEqual(call.mediaList.count, mediaList.count)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.callMediaUpdated(call: testCall)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testCallMediaUpdatedWithNoExistingMedia() async {
        let mediaList: [[String: String]] = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]

        mockCallsAdapter.currentMediaListReturnValue = mediaList
        mockCallsAdapter.callDetailsReturnValue = [
            CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec
        ]

        testCall.mediaList = []
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Call media updated event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertEqual(call.mediaList.count, mediaList.count)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.callMediaUpdated(call: testCall)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testUpdateCallMediaIfNeeded() async {
        let currentMediaList: [[String: String]] = []
        let newMediaList: [[String: String]] = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]

        mockCallsAdapter.currentMediaListReturnValue = newMediaList

        testCall.mediaList = currentMediaList
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Call media updated event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertEqual(call.mediaList.count, newMediaList.count)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.updateCallMediaIfNeeded(call: testCall)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleMediaNegotiationStatus() async {
        let mediaList: [[String: String]] = [TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel)]

        mockCallsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: TestConstants.videoCodec]

        let expectation = XCTestExpectation(description: "Media negotiation event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertEqual(call.mediaList.count, mediaList.count)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.handleMediaNegotiationStatus(callId: CallTestConstants.callId, event: "negotiated", media: mediaList)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testHandleMediaChangeRequest() async {
        let originalMedia: [[String: String]] = [
            TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel, muted: false, enabled: true)
        ]

        let requestedMedia: [[String: String]] = [
            [MediaAttributeKey.mediaType.rawValue: TestMediaTypes.audio,
             MediaAttributeKey.label.rawValue: TestConstants.audioLabel],
            [MediaAttributeKey.mediaType.rawValue: TestMediaTypes.video,
             MediaAttributeKey.label.rawValue: TestConstants.newVideoLabel]
        ]

        testCall.mediaList = originalMedia
        calls.update { calls in
            calls[CallTestConstants.callId] = self.testCall
        }

        let expectation = XCTestExpectation(description: "Media change request event published")

        callUpdates
            .take(1)
            .subscribe(onNext: { call in
                XCTAssertEqual(call.callId, self.testCall.callId)
                XCTAssertEqual(call.mediaList.count, 2)

                // Check that the original audio media settings are preserved
                let audioMedia = call.mediaList.first { $0[MediaAttributeKey.label.rawValue] == TestConstants.audioLabel }
                XCTAssertNotNil(audioMedia)
                XCTAssertEqual(audioMedia?[MediaAttributeKey.muted.rawValue], "false")
                XCTAssertEqual(audioMedia?[MediaAttributeKey.enabled.rawValue], "true")

                // Check that the new video media has default values
                let videoMedia = call.mediaList.first { $0[MediaAttributeKey.label.rawValue] == TestConstants.newVideoLabel }
                XCTAssertNotNil(videoMedia)
                XCTAssertEqual(videoMedia?[MediaAttributeKey.muted.rawValue], "true")
                XCTAssertEqual(videoMedia?[MediaAttributeKey.enabled.rawValue], "true")

                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        await mediaManagementService.handleMediaChangeRequest(accountId: CallTestConstants.accountId, callId: CallTestConstants.callId, media: requestedMedia)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 1)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallId, CallTestConstants.callId)
        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestAccountId, CallTestConstants.accountId)
    }

    func testHandleMediaChangeRequestWithInvalidCallId() async {
        await mediaManagementService.handleMediaChangeRequest(accountId: CallTestConstants.accountId, callId: CallTestConstants.invalidCallId, media: [])

        XCTAssertEqual(mockCallsAdapter.answerMediaChangeResquestCallCount, 0, "Should not process invalid call ID")
    }

    func testProcessMediaChangeRequest() {
        let originalMedia: [[String: String]] = [
            TestMediaFactory.createAudioMedia(label: TestConstants.audioLabel, muted: false, enabled: true)
        ]

        let requestedMedia: [[String: String]] = [
            [MediaAttributeKey.mediaType.rawValue: TestMediaTypes.audio,
             MediaAttributeKey.label.rawValue: TestConstants.audioLabel],
            [MediaAttributeKey.mediaType.rawValue: TestMediaTypes.video,
             MediaAttributeKey.label.rawValue: TestConstants.newVideoLabel]
        ]

        testCall.mediaList = originalMedia

        let result = mediaManagementService.processMediaChangeRequest(call: testCall, requestedMedia: requestedMedia)

        XCTAssertEqual(result.count, 2, "Should return two media entries")

        let resultAudio = result.first { $0[MediaAttributeKey.label.rawValue] == TestConstants.audioLabel }
        XCTAssertNotNil(resultAudio, "Audio media should be present")
        XCTAssertEqual(resultAudio?[MediaAttributeKey.muted.rawValue], "false", "Audio mute state should be preserved")
        XCTAssertEqual(resultAudio?[MediaAttributeKey.enabled.rawValue], "true", "Audio enabled state should be preserved")

        let resultVideo = result.first { $0[MediaAttributeKey.label.rawValue] == TestConstants.newVideoLabel }
        XCTAssertNotNil(resultVideo, "Video media should be present")
        XCTAssertEqual(resultVideo?[MediaAttributeKey.muted.rawValue], "true", "New video should be muted by default")
        XCTAssertEqual(resultVideo?[MediaAttributeKey.enabled.rawValue], "true", "New video should be enabled by default")
    }
}

extension CallModel {
    convenience init(id: String, accountId: String) {
        self.init()
        self.callId = id
        self.accountId = accountId
    }
}
