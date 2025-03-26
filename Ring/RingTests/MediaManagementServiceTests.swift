import XCTest
import RxSwift
import RxSwift
import RxRelay
import RxRelay
@testable import Ring
@testable import Ring

final class MediaManagementServiceTests: XCTestCase {


    // MARK: - Properties
    // MARK: - Properties


    private var callsAdapter: MockCallsAdapter!
    private var callsAdapter: MockCallsAdapter!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var calls: BehaviorRelay<[String: CallModel]>!
    private var currentCallsEvents: ReplaySubject<CallModel>!
    private var currentCallsEvents: ReplaySubject<CallModel>!
    private var service: MediaManagementService!
    private var service: MediaManagementService!
    private var disposeBag: DisposeBag!
    private var disposeBag: DisposeBag!


    private let callId = "test-call-id"
    private let callId = "test-call-id"
    private let accountId = "test-account-id"
    private let accountId = "test-account-id"


    // MARK: - Setup & Teardown
    // MARK: - Setup & Teardown


    override func setUp() {
        override func setUp() {
        super.setUp()
        super.setUp()


        callsAdapter = MockCallsAdapter()
        callsAdapter = MockCallsAdapter()
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        calls = BehaviorRelay<[String: CallModel]>(value: [:])
        currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 10)
        currentCallsEvents = ReplaySubject<CallModel>.create(bufferSize: 10)
        service = MediaManagementService(
        service = MediaManagementService(
        callsAdapter: callsAdapter,
            callsAdapter: callsAdapter,
            calls: calls,
            calls: calls,
            currentCallsEvents: currentCallsEvents
            currentCallsEvents: currentCallsEvents
    )
    )
        disposeBag = DisposeBag()
        disposeBag = DisposeBag()
    }
    }

override func tearDown() {
        callsAdapter = nil
        callsAdapter = nil
        calls = nil
        calls = nil
        currentCallsEvents = nil
        currentCallsEvents = nil
        service = nil
        service = nil
        disposeBag = nil
        disposeBag = nil


        super.tearDown()
        super.tearDown()
    }
}

// MARK: - Helper Methods

private func createTestCall() -> CallModel {
            let call = CallModel(id: callId)
            let call = CallModel(id: callId)
            call.accountId = accountId
            call.accountId = accountId
            return call
            return call
        }
        }

private func setupTestCall() -> CallModel {
                let call = createTestCall()
                let call = createTestCall()
                calls.accept([callId: call])
                calls.accept([callId: call])
                return call
                return call
            }
            }

// MARK: - Tests

func testGetVideoCodec() {
        // Given
        // Given
        let call = createTestCall()
        let call = createTestCall()
        let expectedCodec = "H264"
        let expectedCodec = "H264"
        callsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: expectedCodec]
        callsAdapter.callDetailsReturnValue = [CallDetailKey.videoCodec.rawValue: expectedCodec]


        // When
        // When
        let result = service.getVideoCodec(call: call)
        let result = service.getVideoCodec(call: call)


                // Then
                // Then
                XCTAssertEqual(result, expectedCodec)
                XCTAssertEqual(result, expectedCodec)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertEqual(callsAdapter.callDetailsCallId, call.callId)
                XCTAssertEqual(callsAdapter.callDetailsCallId, call.callId)
                XCTAssertEqual(callsAdapter.callDetailsAccountId, call.accountId)
                XCTAssertEqual(callsAdapter.callDetailsAccountId, call.accountId)
            }
}

func testAudioMuted() {
            // Given
            // Given
            let call = setupTestCall()
            let call = setupTestCall()
            var receivedCall: CallModel?
            var receivedCall: CallModel?
            currentCallsEvents
            currentCallsEvents
    .take(1)
    .take(1)
    .subscribe(onNext: { call in
    .subscribe(onNext: { call in
                receivedCall = call
                receivedCall = call
            })
            })
    .disposed(by: disposeBag)
    .disposed(by: disposeBag)


            // When
            // When
            service.audioMuted(call: callId, mute: true)
            service.audioMuted(call: callId, mute: true)


            // Then
            // Then
XCTAssertTrue(call.audioMuted)
XCTAssertTrue(call.audioMuted)
XCTAssertNotNil(receivedCall)
XCTAssertNotNil(receivedCall)
            XCTAssertEqual(receivedCall?.callId, callId)
            XCTAssertEqual(receivedCall?.callId, callId)
            XCTAssertTrue(receivedCall?.audioMuted ?? false)
            XCTAssertTrue(receivedCall?.audioMuted ?? false)
        }
}

func testAudioMutedWithNonExistentCall() {
                // Given
                // Given
                let nonExistentCallId = "non-existent-call"
                let nonExistentCallId = "non-existent-call"


                // When
                // When
                service.audioMuted(call: nonExistentCallId, mute: true)
                service.audioMuted(call: nonExistentCallId, mute: true)


                // Then - No crash, no event emitted
                // Then - No crash, no event emitted
            }
            }

func testVideoMuted() {
            // Given
            // Given
            let call = setupTestCall()
            let call = setupTestCall()
            var receivedCall: CallModel?
            var receivedCall: CallModel?
            currentCallsEvents
            currentCallsEvents
            .take(1)
            .take(1)
            .subscribe(onNext: { call in
            .subscribe(onNext: { call in
            receivedCall = call
            receivedCall = call
        })
        })
            .disposed(by: disposeBag)
            .disposed(by: disposeBag)


                // When
                // When
                service.videoMuted(call: callId, mute: true)
                service.videoMuted(call: callId, mute: true)


                // Then
                // Then
                XCTAssertTrue(call.videoMuted)
                XCTAssertTrue(call.videoMuted)
                XCTAssertNotNil(receivedCall)
                XCTAssertNotNil(receivedCall)
XCTAssertEqual(receivedCall?.callId, callId)
XCTAssertEqual(receivedCall?.callId, callId)
XCTAssertTrue(receivedCall?.videoMuted ?? false)
XCTAssertTrue(receivedCall?.videoMuted ?? false)
            }
}

func testVideoMutedWithNonExistentCall() {
    // Given
    // Given
    let nonExistentCallId = "non-existent-call"
    let nonExistentCallId = "non-existent-call"


    // When
    // When
    service.videoMuted(call: nonExistentCallId, mute: true)
    service.videoMuted(call: nonExistentCallId, mute: true)


    // Then - No crash, no event emitted
    // Then - No crash, no event emitted
}
}

func testCallMediaUpdatedWithEmptyMediaList() {
        // Given
        // Given
        let call = setupTestCall()
        let call = setupTestCall()
        let mediaList = [["key": "value"]]
        let mediaList = [["key": "value"]]
        callsAdapter.currentMediaListReturnValue = mediaList
        callsAdapter.currentMediaListReturnValue = mediaList
        callsAdapter.callDetailsReturnValue = ["state": "active"]
        callsAdapter.callDetailsReturnValue = ["state": "active"]


        var receivedCall: CallModel?
        var receivedCall: CallModel?
        currentCallsEvents
        currentCallsEvents
        .take(1)
        .take(1)
        .subscribe(onNext: { call in
        .subscribe(onNext: { call in
                receivedCall = call
                receivedCall = call
            })
            })
        .disposed(by: disposeBag)
        .disposed(by: disposeBag)


                // When
                // When
                service.callMediaUpdated(call: call)
                service.callMediaUpdated(call: call)


                // Then
                // Then
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 1)
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 1)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertNotNil(receivedCall)
                XCTAssertNotNil(receivedCall)
            }
}

func testCallMediaUpdatedWithExistingMediaList() {
                // Given
                // Given
                let call = setupTestCall()
                let call = setupTestCall()
                call.mediaList = [["key": "value"]]
                call.mediaList = [["key": "value"]]
                callsAdapter.callDetailsReturnValue = ["state": "active"]
                callsAdapter.callDetailsReturnValue = ["state": "active"]


                var receivedCall: CallModel?
                var receivedCall: CallModel?
                currentCallsEvents
                currentCallsEvents
                    .take(1)
                    .take(1)
                    .subscribe(onNext: { call in
                    .subscribe(onNext: { call in
                    receivedCall = call
                    receivedCall = call
                })
                })
                    .disposed(by: disposeBag)
                    .disposed(by: disposeBag)


                // When
                // When
                service.callMediaUpdated(call: call)
                service.callMediaUpdated(call: call)


                // Then
                // Then
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 0)
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 0)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
                XCTAssertNotNil(receivedCall)
                XCTAssertNotNil(receivedCall)
            }
}

func testUpdateCallMediaIfNeeded() {
                // Given
                // Given
                let call = setupTestCall()
                let call = setupTestCall()
                let mediaList = [["key": "value"]]
                let mediaList = [["key": "value"]]
                callsAdapter.currentMediaListReturnValue = mediaList
                callsAdapter.currentMediaListReturnValue = mediaList


                // When
                // When
                service.updateCallMediaIfNeeded(call: call)
                service.updateCallMediaIfNeeded(call: call)


                // Then
                // Then
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 1)
                XCTAssertEqual(callsAdapter.currentMediaListCallCount, 1)
                XCTAssertEqual(call.mediaList, mediaList)
                XCTAssertEqual(call.mediaList, mediaList)
            }
            }

func testHandleRemoteRecordingChanged() {
            // Given
            // Given
            let call = setupTestCall()
            let call = setupTestCall()
            var receivedCall: CallModel?
            var receivedCall: CallModel?
            currentCallsEvents
            currentCallsEvents
                .take(1)
                .take(1)
                .subscribe(onNext: { call in
                .subscribe(onNext: { call in
                    receivedCall = call
                    receivedCall = call
                })
                })
                .disposed(by: disposeBag)
                .disposed(by: disposeBag)


            // When
            // When
            service.handleRemoteRecordingChanged(callId: callId, record: true)
            service.handleRemoteRecordingChanged(callId: callId, record: true)


            // Then
            // Then
            XCTAssertTrue(call.callRecorded)
            XCTAssertTrue(call.callRecorded)
    XCTAssertNotNil(receivedCall)
    XCTAssertNotNil(receivedCall)
    XCTAssertEqual(receivedCall?.callId, callId)
    XCTAssertEqual(receivedCall?.callId, callId)
    XCTAssertTrue(receivedCall?.callRecorded ?? false)
    XCTAssertTrue(receivedCall?.callRecorded ?? false)
}
}

func testHandleCallPlacedOnHold() {
    // Given
    // Given
    let call = setupTestCall()
    let call = setupTestCall()
    var receivedCall: CallModel?
    var receivedCall: CallModel?
    currentCallsEvents
    currentCallsEvents
        .take(1)
        .take(1)
        .subscribe(onNext: { call in
        .subscribe(onNext: { call in
        receivedCall = call
        receivedCall = call
    })
    })
        .disposed(by: disposeBag)
        .disposed(by: disposeBag)


    // When
    // When
    service.handleCallPlacedOnHold(callId: callId, holding: true)
    service.handleCallPlacedOnHold(callId: callId, holding: true)


    // Then
    // Then
    XCTAssertTrue(call.peerHolding)
    XCTAssertTrue(call.peerHolding)
    XCTAssertNotNil(receivedCall)
    XCTAssertNotNil(receivedCall)
                XCTAssertEqual(receivedCall?.callId, callId)
                XCTAssertEqual(receivedCall?.callId, callId)
                XCTAssertTrue(receivedCall?.peerHolding ?? false)
                XCTAssertTrue(receivedCall?.peerHolding ?? false)
            }
}

func testHandleMediaNegotiationStatus() {
            // Given
            // Given
            let call = setupTestCall()
            let call = setupTestCall()
            let media = [["key": "value"]]
            let media = [["key": "value"]]
            callsAdapter.callDetailsReturnValue = ["state": "active"]
            callsAdapter.callDetailsReturnValue = ["state": "active"]


            var receivedCall: CallModel?
            var receivedCall: CallModel?
            currentCallsEvents
            currentCallsEvents
            .take(1)
            .take(1)
            .subscribe(onNext: { call in
            .subscribe(onNext: { call in
            receivedCall = call
            receivedCall = call
        })
        })
            .disposed(by: disposeBag)
            .disposed(by: disposeBag)


            // When
            // When
            service.handleMediaNegotiationStatus(callId: callId, event: "media_negotiation", media: media)
            service.handleMediaNegotiationStatus(callId: callId, event: "media_negotiation", media: media)


            // Then
            // Then
        XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
        XCTAssertEqual(callsAdapter.callDetailsCallCount, 1)
        XCTAssertNotNil(receivedCall)
        XCTAssertNotNil(receivedCall)
    }
}

func testHandleMediaChangeRequest() {
                // Given
                // Given
                let call = setupTestCall()
                let call = setupTestCall()
                call.mediaList = [
                call.mediaList = [
            [
            [
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.muted.rawValue: "false",
                    MediaAttributeKey.muted.rawValue: "false",
                    MediaAttributeKey.enabled.rawValue: "true"
                    MediaAttributeKey.enabled.rawValue: "true"
                ]
                ]
        ]
        ]


                let requestedMedia = [
                let requestedMedia = [
                    [
                    [
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue
                ],
                ],
                    [
                    [
                    MediaAttributeKey.label.rawValue: "video_0",
                    MediaAttributeKey.label.rawValue: "video_0",
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue
                ]
                ]
                ]
                ]


            // When
            // When
            service.handleMediaChangeRequest(accountId: accountId, callId: callId, media: requestedMedia)
            service.handleMediaChangeRequest(accountId: accountId, callId: callId, media: requestedMedia)


            // Then
            // Then
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallCount, 1)
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallCount, 1)
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallId, callId)
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallId, callId)
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestAccountId, accountId)
            XCTAssertEqual(callsAdapter.answerMediaChangeRequestAccountId, accountId)


            // Verify that the existing media properties were preserved
            // Verify that the existing media properties were preserved
            let processedMedia = callsAdapter.answerMediaChangeRequestMedia
            let processedMedia = callsAdapter.answerMediaChangeRequestMedia
            XCTAssertEqual(processedMedia.count, 2)
            XCTAssertEqual(processedMedia.count, 2)


            let audioMedia = processedMedia.first { $0[MediaAttributeKey.label.rawValue] == "audio_0" }
            let audioMedia = processedMedia.first { $0[MediaAttributeKey.label.rawValue] == "audio_0" }
            XCTAssertNotNil(audioMedia)
            XCTAssertNotNil(audioMedia)
            XCTAssertEqual(audioMedia?[MediaAttributeKey.muted.rawValue], "false")
            XCTAssertEqual(audioMedia?[MediaAttributeKey.muted.rawValue], "false")
            XCTAssertEqual(audioMedia?[MediaAttributeKey.enabled.rawValue], "true")
            XCTAssertEqual(audioMedia?[MediaAttributeKey.enabled.rawValue], "true")


            let videoMedia = processedMedia.first { $0[MediaAttributeKey.label.rawValue] == "video_0" }
            let videoMedia = processedMedia.first { $0[MediaAttributeKey.label.rawValue] == "video_0" }
            XCTAssertNotNil(videoMedia)
            XCTAssertNotNil(videoMedia)
            XCTAssertEqual(videoMedia?[MediaAttributeKey.muted.rawValue], "true")
            XCTAssertEqual(videoMedia?[MediaAttributeKey.muted.rawValue], "true")
            XCTAssertEqual(videoMedia?[MediaAttributeKey.enabled.rawValue], "true")
            XCTAssertEqual(videoMedia?[MediaAttributeKey.enabled.rawValue], "true")
        }
}

func testHandleMediaChangeRequestWithMissingLabel() {
                        // Given
                        // Given
                        let call = setupTestCall()
                        let call = setupTestCall()
                        call.mediaList = [
                        call.mediaList = [
                    [
                    [
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.label.rawValue: "audio_0",
                    MediaAttributeKey.muted.rawValue: "false",
                    MediaAttributeKey.muted.rawValue: "false",
                    MediaAttributeKey.enabled.rawValue: "true"
                    MediaAttributeKey.enabled.rawValue: "true"
                ]
                ]
                ]
                ]


                        let requestedMedia = [
                        let requestedMedia = [
                    [
                    [
                    // No label provided
                    // No label provided
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue
                    MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue
                ]
                ]
                ]
                ]


                        // When
                        // When
                        service.handleMediaChangeRequest(accountId: accountId, callId: callId, media: requestedMedia)
                        service.handleMediaChangeRequest(accountId: accountId, callId: callId, media: requestedMedia)


                    // Then
                    // Then
                    XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallCount, 1)
                    XCTAssertEqual(callsAdapter.answerMediaChangeRequestCallCount, 1)


                    // Verify default values were set
                    // Verify default values were set
                    let processedMedia = callsAdapter.answerMediaChangeRequestMedia
                    let processedMedia = callsAdapter.answerMediaChangeRequestMedia
                    XCTAssertEqual(processedMedia.count, 1)
                    XCTAssertEqual(processedMedia.count, 1)


                    let mediaItem = processedMedia.first
                    let mediaItem = processedMedia.first
                    XCTAssertNotNil(mediaItem)
                    XCTAssertNotNil(mediaItem)
                    XCTAssertEqual(mediaItem?[MediaAttributeKey.muted.rawValue], "true")
                    XCTAssertEqual(mediaItem?[MediaAttributeKey.muted.rawValue], "true")
                    XCTAssertEqual(mediaItem?[MediaAttributeKey.enabled.rawValue], "true")
                    XCTAssertEqual(mediaItem?[MediaAttributeKey.enabled.rawValue], "true")
                }
}

func testMediaAttributeFactory() {
                    // Test audio media creation
                    // Test audio media creation
                    let audioMedia = MediaAttributeFactory.createAudioMedia()
                    let audioMedia = MediaAttributeFactory.createAudioMedia()
                    XCTAssertEqual(audioMedia[MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)
                    XCTAssertEqual(audioMedia[MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)
                    XCTAssertEqual(audioMedia[MediaAttributeKey.label.rawValue], "audio_0")
                    XCTAssertEqual(audioMedia[MediaAttributeKey.label.rawValue], "audio_0")
                    XCTAssertEqual(audioMedia[MediaAttributeKey.enabled.rawValue], "true")
                    XCTAssertEqual(audioMedia[MediaAttributeKey.enabled.rawValue], "true")
                    XCTAssertEqual(audioMedia[MediaAttributeKey.muted.rawValue], "false")
                    XCTAssertEqual(audioMedia[MediaAttributeKey.muted.rawValue], "false")


                    // Test video media creation
                    // Test video media creation
                    let videoMedia = MediaAttributeFactory.createVideoMedia(source: "camera")
                    let videoMedia = MediaAttributeFactory.createVideoMedia(source: "camera")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.video.rawValue)
                    XCTAssertEqual(videoMedia[MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.video.rawValue)
                    XCTAssertEqual(videoMedia[MediaAttributeKey.label.rawValue], "video_0")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.label.rawValue], "video_0")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.source.rawValue], "camera")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.source.rawValue], "camera")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.enabled.rawValue], "true")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.enabled.rawValue], "true")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.muted.rawValue], "false")
                    XCTAssertEqual(videoMedia[MediaAttributeKey.muted.rawValue], "false")


                    // Test default media list creation - audio only
                    // Test default media list creation - audio only
                    let audioOnlyMediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: true, videoSource: "camera")
                    let audioOnlyMediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: true, videoSource: "camera")
                    XCTAssertEqual(audioOnlyMediaList.count, 1)
                    XCTAssertEqual(audioOnlyMediaList.count, 1)
                    XCTAssertEqual(audioOnlyMediaList[0][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)
                    XCTAssertEqual(audioOnlyMediaList[0][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)


                    // Test default media list creation - with video
                    // Test default media list creation - with video
                    let fullMediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: false, videoSource: "camera")
                    let fullMediaList = MediaAttributeFactory.createDefaultMediaList(isAudioOnly: false, videoSource: "camera")
                    XCTAssertEqual(fullMediaList.count, 2)
                    XCTAssertEqual(fullMediaList.count, 2)
                    XCTAssertEqual(fullMediaList[0][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)
                    XCTAssertEqual(fullMediaList[0][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.audio.rawValue)
                    XCTAssertEqual(fullMediaList[1][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.video.rawValue)
                    XCTAssertEqual(fullMediaList[1][MediaAttributeKey.mediaType.rawValue], MediaAttributeValue.video.rawValue)
                }
}
}
}

// MARK: - Mock Classes

final class MockCallsAdapter: CallsAdapter {
                // CallDetails tracking
                // CallDetails tracking
                var callDetailsCallCount = 0
                var callDetailsCallCount = 0
                var callDetailsCallId: String?
                var callDetailsCallId: String?
                var callDetailsAccountId: String?
                var callDetailsAccountId: String?
                var callDetailsReturnValue: [String: String]?
                var callDetailsReturnValue: [String: String]?


                func callDetails(withCallId callId: String, accountId: String) -> [String: String]? {
                func callDetails(withCallId callId: String, accountId: String) -> [String: String]? {
                callDetailsCallCount += 1
                callDetailsCallCount += 1
                callDetailsCallId = callId
                callDetailsCallId = callId
                callDetailsAccountId = accountId
                callDetailsAccountId = accountId
                return callDetailsReturnValue
                return callDetailsReturnValue
            }
            }


                // CurrentMediaList tracking
                // CurrentMediaList tracking
                var currentMediaListCallCount = 0
                var currentMediaListCallCount = 0
                var currentMediaListCallId: String?
                var currentMediaListCallId: String?
                var currentMediaListAccountId: String?
                var currentMediaListAccountId: String?
                var currentMediaListReturnValue: [[String: String]]?
                var currentMediaListReturnValue: [[String: String]]?


                func currentMediaList(withCallId callId: String, accountId: String) -> [[String: String]]? {
                func currentMediaList(withCallId callId: String, accountId: String) -> [[String: String]]? {
        currentMediaListCallCount += 1
        currentMediaListCallCount += 1
        currentMediaListCallId = callId
        currentMediaListCallId = callId
        currentMediaListAccountId = accountId
        currentMediaListAccountId = accountId
        return currentMediaListReturnValue
        return currentMediaListReturnValue
    }
    }


                // AnswerMediaChangeRequest tracking
                // AnswerMediaChangeRequest tracking
                var answerMediaChangeRequestCallCount = 0
                var answerMediaChangeRequestCallCount = 0
                var answerMediaChangeRequestCallId: String?
                var answerMediaChangeRequestCallId: String?
var answerMediaChangeRequestAccountId: String?
var answerMediaChangeRequestAccountId: String?
var answerMediaChangeRequestMedia: [[String: String]] = []
var answerMediaChangeRequestMedia: [[String: String]] = []

func answerMediaChangeResquest(_ callId: String, accountId: String, withMedia media: [[String: String]]) {
            answerMediaChangeRequestCallCount += 1
            answerMediaChangeRequestCallCount += 1
            answerMediaChangeRequestCallId = callId
            answerMediaChangeRequestCallId = callId
            answerMediaChangeRequestAccountId = accountId
            answerMediaChangeRequestAccountId = accountId
            answerMediaChangeRequestMedia = media
            answerMediaChangeRequestMedia = media
        }
        }

// Add stubs for other required methods from CallsAdapter
}
}

// Extend CallModel for testing
extension CallModel {
extension CallModel {
        convenience init(id: String) {
        convenience init(id: String) {
        self.init()
        self.init()
        self.callId = id
        self.callId = id
    }
    }
    }
    }
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
import XCTest
