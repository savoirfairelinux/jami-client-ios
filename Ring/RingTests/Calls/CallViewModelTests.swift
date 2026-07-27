/*
 * Copyright (C) 2026-2026 Savoir-faire Linux Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA.
 */

import XCTest
import Combine
@testable import Ring

@MainActor
final class CallViewModelTests: XCTestCase { // swiftlint:disable:this type_body_length

    private func makeModel(call: CallState, callService: CallService,
                           videoService: VideoService = VideoService(
                            video: TestLibJamiVideoAPI()),
                           pipController: PiPControlling = PiPController()) -> CallViewModel {
        let database = DBManager(profileHepler: ProfileDataHelper(),
                                 conversationHelper: ConversationDataHelper(),
                                 interactionHepler: InteractionDataHelper(),
                                 dbConnections: DBContainer())
        return CallViewModel(
            call: call,
            callService: callService,
            videoService: videoService,
            audio: AudioService(audio: LibJamiAudioClient(adapter: AudioAdapter())),
            profileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                            dbManager: database),
            nameService: NameService(withNameRegistrationAdapter: NameRegistrationAdapter()),
            pipController: pipController)
    }

    func testConnectingCallPopulatesFirstRenderedState() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .connecting,
                             media: [.audio(), .video()],
                             isAudioOnly: false)
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let videoService = VideoService(video: TestLibJamiVideoAPI())
        let model = makeModel(call: call, callService: callService,
                              videoService: videoService)

        XCTAssertEqual(model.call, call)
        XCTAssertNotNil(model.controls, "hang-up controls must exist on the first render")
        XCTAssertEqual(model.title, "bob")
        XCTAssertFalse(model.statusText.isEmpty)
        XCTAssertTrue(model.chromeVisible)
        XCTAssertEqual(model.tiles.count, 1)
        let preview = model.tiles.first
        XCTAssertEqual(preview?.participant,
                       CanvasParticipant(id: CanvasParticipant.localId,
                                         isLocalPreview: true))
        XCTAssertEqual(preview?.tileState.showsVideo, true)
        XCTAssertTrue(preview?.distributor === videoService.localFrames,
                      "the first rendered tile must display captured local frames")
    }

    func testCallThatEndedBeforeObservationStillTransitionsScreenToEnded() async throws {
        let callAPI = TestLibJamiCallAPI()
        callAPI.placeCallReturn = "call-out"
        let callService = CallService(callClient: callAPI, callEvents: AsyncStream { _ in })
        let call = try await callService.placeCall(accountId: accountId1, to: "bob",
                                                   audioOnly: true)
        await callService.hangUp(call.id)

        let model = makeModel(call: call, callService: callService)
        let ended = expectation(description: "screen consumes replayed terminal state")
        let cancellable = model.$shouldDismiss
            .filter { $0 }
            .prefix(1)
            .sink { _ in ended.fulfill() }

        await fulfillment(of: [ended], timeout: 2)

        XCTAssertTrue(model.shouldDismiss)
        XCTAssertEqual(model.call?.status, .terminated(.endedLocally))
        withExtendedLifetime(cancellable) {}
    }

    func testRemoteEndDropsVideoTilesAndAnnouncesTheEnding() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel()
        model.screenTapped()
        XCTAssertFalse(model.chromeVisible, "precondition: chrome hidden mid-call")

        harness.send(.callStateChanged(callId: harness.callId.raw, state: .over,
                                       rawState: "OVER", accountId: Harness.accountId,
                                       code: 0, negotiatedMedia: [], videoCodec: nil))
        await harness.waitForEnded(model)

        XCTAssertTrue(model.chromeVisible, "the ending must bring the chrome back")
        XCTAssertEqual(model.statusText, L10n.Calls.callFinished)
        XCTAssertNil(model.tiles.first { $0.participant.isLocalPreview },
                     "the self-preview must not outlive the call")
        XCTAssertEqual(model.tiles.count, 1, "the peer stays, as an avatar")
        XCTAssertEqual(model.tiles.first?.tileState.showsVideo, false)
        XCTAssertNil(model.tiles.first?.distributor,
                     "a frozen last frame must not keep a distributor attached")
    }

    func testLocalEndDropsVideoTilesWithoutAnnouncing() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel()

        await harness.callService.hangUp(harness.callId)
        await harness.waitForEnded(model)

        XCTAssertEqual(model.statusText, "")
        XCTAssertNil(model.tiles.first { $0.participant.isLocalPreview })
        XCTAssertEqual(model.tiles.first?.tileState.showsVideo, false)
        XCTAssertTrue(model.shouldDismiss, "a local end leaves on the tap")
    }

    func testPictureInPictureMinimizesWhileTheShrinkAnimationRuns() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false,
                             conversationId: "conversation")
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        var openedRoute: CallConversationRoute?
        model.onMinimize = { openedRoute = $0 }

        model.minimizeToPictureInPicture()

        XCTAssertEqual(pipController.startCallCount, 1)
        XCTAssertEqual(openedRoute,
                       CallConversationRoute(conversationId: "conversation",
                                             peerUri: "bob",
                                             accountId: accountId1),
                       "the call screen must leave while AVKit shrinks it into the PiP window")
    }

    func testFailedPictureInPictureStartBringsTheCallScreenBack() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false,
                             conversationId: "conversation")
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        model.onMinimize = { _ in }
        var restoreCount = 0
        model.onRestore = { completion in
            restoreCount += 1
            completion(true)
        }

        model.minimizeToPictureInPicture()
        pipController.onDidFailToStart?()

        XCTAssertEqual(restoreCount, 1,
                       "a PiP that never started must not leave the user without call UI")
    }

    func testRestoringFromAMinimizedCallHidesTheScreenUntilTheWindowFinishesGrowing() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false,
                             conversationId: "conversation")
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        model.onMinimize = { _ in }
        model.onRestore = { $0(true) }

        model.minimizeToPictureInPicture()
        pipController.onRestoreRequested? { _ in }

        XCTAssertTrue(model.contentHidden,
                      "the restored screen must stay blank under the growing PiP window")

        pipController.onDidStop?()

        XCTAssertFalse(model.contentHidden)
    }

    func testRestoringAnAutomaticPictureInPictureKeepsTheScreenVisible() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false,
                             conversationId: "conversation")
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        model.onRestore = { $0(true) }

        pipController.onRestoreRequested? { _ in }

        XCTAssertFalse(model.contentHidden,
                       "the call screen never left, so blanking it would flash")
    }

    func testRestoreThatNeverPresentsRevealsTheCallScreen() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false,
                             conversationId: "conversation")
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        model.onMinimize = { _ in }
        model.onRestore = { $0(false) }

        model.minimizeToPictureInPicture()
        pipController.onRestoreRequested? { _ in }

        XCTAssertFalse(model.contentHidden)
    }

    func testPictureInPictureRestoreWaitsForCallScreenPresentation() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .current,
                             media: [.audio(), .video()],
                             isAudioOnly: false)
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let pipController = TestPiPController()
        let model = makeModel(call: call, callService: callService,
                              pipController: pipController)
        model.showsDialpad = true
        model.showsParticipants = true
        var restoreCompletion: PiPRestoreCompletion?
        model.onRestore = { restoreCompletion = $0 }
        var restored: Bool?

        pipController.onRestoreRequested? { restored = $0 }

        XCTAssertFalse(model.showsDialpad)
        XCTAssertFalse(model.showsParticipants)
        XCTAssertNil(restored, "AVKit completion must wait for the call screen presentation")

        restoreCompletion?(true)

        XCTAssertEqual(restored, true)
    }

    func testLosingThePictureInPictureSubjectBringsTheCallScreenBack() async {
        let harness = await Harness(callHasVideo: true)
        let pipController = TestPiPController()
        let model = harness.makeModel(pipController: pipController)
        var restoreCount = 0
        model.onRestore = { completion in
            restoreCount += 1
            completion(true)
        }
        XCTAssertTrue(model.canStartPictureInPicture,
                      "an ongoing video call must have a picture-in-picture subject")

        harness.send(.mediaNegotiationStatus(callId: harness.callId.raw,
                                             event: .success, media: [.audio()]))
        await Harness.wait { !model.canStartPictureInPicture }

        XCTAssertEqual(restoreCount, 1,
                       "a running call must never be left without a window")
    }

    func testCallEndingDoesNotAskForARestore() async {
        let harness = await Harness(callHasVideo: true)
        let pipController = TestPiPController()
        let model = harness.makeModel(pipController: pipController)
        var restoreCount = 0
        model.onRestore = { completion in
            restoreCount += 1
            completion(true)
        }

        await harness.callService.hangUp(harness.callId)
        await harness.waitForEnded(model)

        XCTAssertEqual(restoreCount, 0, "the screen leaves on its own when the call ends")
    }

    func testMaximizeAndMinimizeWalkTheSharedLayoutLadder() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel()
        let focusedParticipantId = "u1|\(deviceId1)"
        harness.callAPI.conferenceCallsReturn["conf-1"] = [harness.callId.raw]
        harness.send(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                        accountId: Harness.accountId,
                                        state: "ACTIVE_ATTACHED",
                                        memberCallIds: [harness.callId.raw],
                                        participants: [], media: []))
        func sendInfos(activeId: String?, othersSide: Int) {
            func entry(_ uri: String, _ device: String, _ sink: String)
            -> ConferenceParticipantInfo {
                let isActive = "\(uri)|\(device)" == activeId
                let side = isActive ? 600 : othersSide
                return CallTestFixtures.participant(
                    uri: uri,
                    device: device,
                    sinkId: sink,
                    isActive: isActive,
                    frameSize: CGSize(width: CGFloat(side), height: CGFloat(side)))
            }
            harness.send(.conferenceInfosUpdated(
                            conferenceId: "conf-1",
                            participants: [entry("u1", deviceId1, "conf-1_video_0"),
                                           entry("u2", deviceId2, "conf-1_video_1")]))
        }
        sendInfos(activeId: nil, othersSide: 300)
        await Harness.wait { model.conference?.participants.count == 2 }
        XCTAssertEqual(model.canvasMode, .grid)

        model.perform(.maximize, on: focusedParticipantId)
        await Harness.wait { model.conference?.layout == .oneWithSmall }
        XCTAssertEqual(model.canvasMode, .grid,
                       "the stale setLayout echo must not start the animation")
        XCTAssertTrue(model.tiles.contains { $0.expectedVideoSize == .zero },
                      "the echo must freeze remote tiles until the daemon "
                        + "recomposes — old-crop frames carry garbage")
        sendInfos(activeId: focusedParticipantId, othersSide: 120)
        await Harness.wait { model.canvasMode == .spotlight(focusedParticipantId) }
        XCTAssertFalse(model.tiles.contains { $0.expectedVideoSize == .zero },
                       "new geometry reopens the frame gates")
        XCTAssertTrue(model.tiles.contains { $0.expectedVideoSize == CGSize(width: 600,
                                                                            height: 600)
        },
        "the focused tile expects its new crop size")

        model.perform(.maximize, on: focusedParticipantId)
        await Harness.wait { model.conference?.layout == .one }
        XCTAssertEqual(model.canvasMode, .spotlight(focusedParticipantId),
                       "still spotlight until the daemon zeroes the others")
        sendInfos(activeId: focusedParticipantId, othersSide: 0)
        await Harness.wait { model.canvasMode == .fullscreen(focusedParticipantId) }

        model.perform(.minimize, on: focusedParticipantId)
        await Harness.wait { model.conference?.layout == .oneWithSmall }
        XCTAssertEqual(model.canvasMode, .fullscreen(focusedParticipantId),
                       "still fullscreen until the others regain pixels")
        sendInfos(activeId: focusedParticipantId, othersSide: 120)
        await Harness.wait { model.canvasMode == .spotlight(focusedParticipantId) }

        model.perform(.minimize, on: focusedParticipantId)
        await Harness.wait { model.conference?.layout == .grid }
        sendInfos(activeId: nil, othersSide: 300)
        await Harness.wait { model.canvasMode == .grid }
    }

    func testPeerHostedConferenceUsesParticipantSinksInsteadOfMixedCallSink() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)

        harness.send(.conferenceInfosUpdated(
                        conferenceId: harness.callId.raw,
                        participants: [CallTestFixtures.participant(
                                        uri: jamiId1,
                                        device: "local",
                                        sinkId: "member-1_video_0",
                                        frameSize: CGSize(width: 320, height: 240)),
                                       CallTestFixtures.participant(
                                        uri: "bob",
                                        device: "remote-1",
                                        sinkId: "member-1_video_1",
                                        frameSize: CGSize(width: 320, height: 240)),
                                       CallTestFixtures.participant(
                                        uri: "carol",
                                        device: "remote-2",
                                        sinkId: "member-1_video_2",
                                        frameSize: CGSize(width: 320, height: 240))]))

        await Harness.wait { model.conference?.participants.count == 3 }

        let renderedSinks = Set(model.tiles.compactMap { $0.distributor?.sinkId })
        XCTAssertEqual(renderedSinks,
                       [SinkId(raw: "local"), SinkId(raw: "member-1_video_1"),
                        SinkId(raw: "member-1_video_2")])
        XCTAssertFalse(renderedSinks.contains(SinkId(raw: harness.callId.raw)),
                       "the original call sink contains the peer's mixed conference frame")
    }

    func testOngoingOneToOneCallListsBothPeople() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)

        XCTAssertEqual(model.participantRows.map(\.uri), [jamiId1, "bob"])
        XCTAssertTrue(model.pendingRows.isEmpty)
        XCTAssertTrue(model.hasParticipantList,
                      "the roster is who is on the call, conference or not")
    }

    func testRingingCallHasNoRosterYet() {
        let call = CallState(id: CallId(raw: "call-out"),
                             accountId: accountId1,
                             direction: .outgoing,
                             peerUri: "bob",
                             status: .ringing,
                             media: [.audio()],
                             isAudioOnly: true)
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let model = makeModel(call: call, callService: callService)

        XCTAssertTrue(model.participantRows.isEmpty,
                      "nobody is on a call that has not connected")
        XCTAssertFalse(model.hasParticipantList)
    }

    func testCancellingTheOnlyInviteLeavesTheCallRosterStanding() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)
        harness.callAPI.placeCallReturn = "sub-call"

        harness.callService.addParticipant(uri: "carol", toCall: harness.callId,
                                           requestedBy: jamiId1)
        await Harness.wait { model.pendingRows.count == 1 }
        XCTAssertEqual(model.participantRows.count, 2)
        XCTAssertEqual(model.participantCount, 3)

        model.cancelInvite(CallId(raw: "sub-call"))
        await Harness.wait { model.pendingRows.isEmpty }

        XCTAssertEqual(model.participantRows.map(\.uri), [jamiId1, "bob"],
                       "cancelling one invite must remove one row, not the whole list")
        XCTAssertTrue(model.hasParticipantList,
                      "the list stays reachable — the call is still running")
    }

    func testTileTapOnAOneToOneCallStillTogglesTheCanvas() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        guard let peerId = model.tiles.first(where: { !$0.participant.isLocalPreview })?
                .participant.id else {
            return XCTFail("a video call renders a peer tile")
        }

        model.tileTapped(peerId)

        XCTAssertEqual(model.canvasMode, .fullscreen(peerId))
        XCTAssertFalse(model.showsParticipants,
                       "tapping a tile is a layout gesture outside a conference")
    }

    private struct Harness {
        static let accountId = accountId1
        let callService: CallService
        let videoService: VideoService
        let callAPI = TestLibJamiCallAPI()
        let send: (LibJamiCallEvent) -> Void
        let callId = CallId(raw: "call-in")
        let call: CallState

        init(callHasVideo: Bool) async {
            let video = TestLibJamiVideoAPI()
            var continuation: AsyncStream<LibJamiCallEvent>.Continuation!
            let stream = AsyncStream<LibJamiCallEvent>(bufferingPolicy: .unbounded) {
                continuation = $0
            }
            let send: (LibJamiCallEvent) -> Void = { continuation.yield($0) }
            let callService = CallService(callClient: callAPI, callEvents: stream)
            callService.start()
            self.callService = callService
            self.videoService = VideoService(video: video)
            self.send = send

            let media: [MediaItem] = callHasVideo ? [.audio(), .video()] : [.audio()]
            send(.incomingCall(accountId: Self.accountId, callId: callId.raw,
                               peerUri: "bob", media: media, details: nil))
            send(.callStateChanged(callId: callId.raw, state: .current,
                                   rawState: "CURRENT", accountId: Self.accountId,
                                   code: 0, negotiatedMedia: media, videoCodec: nil))
            self.call = await Self.waitForCall(callService, callId) { $0.status == .current }
        }

        @MainActor
        func makeModel(localJamiId: String = "",
                       pipController: PiPControlling = PiPController()) -> CallViewModel {
            let database = DBManager(profileHepler: ProfileDataHelper(),
                                     conversationHelper: ConversationDataHelper(),
                                     interactionHepler: InteractionDataHelper(),
                                     dbConnections: DBContainer())
            return CallViewModel(
                call: call,
                callService: callService,
                videoService: videoService,
                audio: AudioService(audio: LibJamiAudioClient(adapter: AudioAdapter())),
                profileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                                dbManager: database),
                nameService: NameService(withNameRegistrationAdapter: NameRegistrationAdapter()),
                localJamiId: localJamiId,
                pipController: pipController)
        }

        @MainActor
        static func wait(for condition: () -> Bool) async {
            for _ in 0..<200 where !condition() {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertTrue(condition(), "the model never reached the expected state")
        }

        @MainActor
        func waitForEnded(_ model: CallViewModel) async {
            for _ in 0..<200 where !model.shouldDismiss {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTAssertTrue(model.shouldDismiss, "the screen never saw the call end")
        }

        private static func waitForCall(_ callService: CallService, _ id: CallId,
                                        where predicate: @escaping (CallState) -> Bool)
        async -> CallState {
            for _ in 0..<200 {
                if let call = await callService.snapshot().call(id), predicate(call) {
                    return call
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("the call service never reached the expected call state")
            return CallState(id: id, accountId: Harness.accountId, direction: .incoming,
                             peerUri: "bob", status: .current)
        }
    }
}

private final class TestPiPController: PiPControlling {
    var onDidFailToStart: (() -> Void)?
    var onDidStop: (() -> Void)?
    var onRestoreRequested: PiPRestoreHandler?
    let sourceView = PiPSourceLayerView()
    var isSupported = true
    private(set) var startCallCount = 0

    func start() {
        startCallCount += 1
    }

    func update(distributor: FrameDistributor?) {}

    func stop() {}
}
