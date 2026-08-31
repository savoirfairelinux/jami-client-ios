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

// swiftlint:disable file_length
@MainActor
final class CallViewModelTests: XCTestCase { // swiftlint:disable:this type_body_length

    private func makeModel(call: CallState, callService: CallService,
                           videoService: VideoService = VideoService(
                            video: TestLibJamiVideoAPI()),
                           pipController: PiPControlling = PiPController()) -> CallViewModel {
        let database = DBManager(conversationHelper: ConversationDataHelper(),
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

    private func makeCall(status: CallStatus = .current,
                          media: [MediaItem] = [.audio(), .video()],
                          conversationId: String? = conversationId1,
                          isAudioOnly: Bool = false) -> CallState {
        CallTestFixtures.call(conversationId: conversationId,
                              peerUri: CallTestFixtures.peerUri,
                              status: status,
                              media: media,
                              isAudioOnly: isAudioOnly)
    }

    func testConnectingCallPopulatesFirstRenderedState() {
        let call = makeCall(status: .connecting)
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let videoService = VideoService(video: TestLibJamiVideoAPI())
        let model = makeModel(call: call, callService: callService,
                              videoService: videoService)

        XCTAssertEqual(model.call, call)
        XCTAssertNotNil(model.controls, "hang-up controls must exist on the first render")
        XCTAssertEqual(model.header.title, CallTestFixtures.peerUri)
        XCTAssertFalse(model.statusLine.isEmpty)
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

    func testAddParticipantWaitsForRosterDismissalBeforeRequestingPicker() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel()
        model.showsParticipants = true
        var didRequestPicker = false
        model.onAddParticipant = { didRequestPicker = true }

        model.addParticipantTapped()

        XCTAssertFalse(model.showsParticipants)
        XCTAssertFalse(didRequestPicker)

        model.participantsDismissed()

        XCTAssertTrue(didRequestPicker)
    }

    func testCallThatEndedBeforeObservationStillTransitionsScreenToEnded() async throws {
        let callAPI = TestLibJamiCallAPI()
        callAPI.placeCallReturn = CallTestFixtures.callId.raw
        let callService = CallService(callClient: callAPI, callEvents: AsyncStream { _ in })
        let call = try await callService.placeCall(accountId: accountId1, to: CallTestFixtures.peerUri,
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

    func testPictureInPictureMinimizesWhileTheShrinkAnimationRuns() {
        let call = makeCall()
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
                       CallConversationRoute(conversationId: conversationId1,
                                             peerUri: CallTestFixtures.peerUri,
                                             accountId: accountId1),
                       "the call screen must leave while AVKit shrinks it into the PiP window")
    }

    func testFailedPictureInPictureStartBringsTheCallScreenBack() {
        let call = makeCall()
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
        let call = makeCall()
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
        let call = makeCall()
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
        let call = makeCall()
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
        let call = makeCall(conversationId: nil)
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
        let focusedParticipantId = CallTestFixtures.remoteSinkId
        let conferenceId = CallTestFixtures.conferenceId.raw
        harness.callAPI.conferenceCallsReturn[conferenceId] = [harness.callId.raw]
        harness.send(.conferenceCreated(conferenceId: conferenceId, conversationId: String(),
                                        accountId: Harness.accountId,
                                        state: ConferenceLifecycle.activeAttached.rawValue,
                                        memberCallIds: [harness.callId.raw],
                                        participants: [],
                                        media: [.audio(), .video()]))
        func sendInfos(activeId: String?, othersSide: Int) {
            func entry(_ uri: String, _ device: String, _ sink: String)
            -> ConferenceParticipantInfo {
                let isActive = sink == activeId
                let side = isActive ? 600 : othersSide
                return CallTestFixtures.participant(
                    uri: uri,
                    device: device,
                    sinkId: sink,
                    isActive: isActive,
                    frameSize: CGSize(width: CGFloat(side), height: CGFloat(side)))
            }
            harness.send(.conferenceInfosUpdated(
                            conferenceId: conferenceId,
                            participants: [entry(CallTestFixtures.peerUri,
                                                 deviceId1,
                                                 CallTestFixtures.remoteSinkId),
                                           entry(CallTestFixtures.secondaryPeerUri,
                                                 deviceId2,
                                                 CallTestFixtures.secondaryRemoteSinkId)]))
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

    func testOnlyAConferenceRendersTilesAsCards() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)

        XCTAssertEqual(model.canvas.style, .plain,
                       "a one-to-one call fills the screen")

        harness.send(.conferenceInfosUpdated(
                        conferenceId: harness.callId.raw,
                        participants: [CallTestFixtures.participant(
                                        uri: jamiId1, device: deviceId1,
                                        sinkId: CallTestFixtures.remoteSinkId),
                                       CallTestFixtures.participant(
                                        uri: CallTestFixtures.peerUri,
                                        device: CallTestFixtures.remoteDeviceId,
                                        sinkId: CallTestFixtures.secondaryRemoteSinkId)]))
        await Harness.wait { model.conference?.participants.count == 2 }

        XCTAssertEqual(model.canvas.style, .cards)

        harness.send(.callStateChanged(callId: harness.callId.raw, state: .over,
                                       rawState: LibJamiCallState.over.rawValue,
                                       accountId: Harness.accountId,
                                       code: 0, negotiatedMedia: [], videoCodec: nil))
        await harness.waitForEnded(model)

        XCTAssertEqual(model.canvas.style, .plain,
                       "the ending drops the conference tiles, so it must drop the cards too")
    }

    func testPeerHostedConferenceUsesParticipantSinksInsteadOfMixedCallSink() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)

        harness.send(.conferenceInfosUpdated(
                        conferenceId: harness.callId.raw,
                        participants: [CallTestFixtures.participant(
                                        uri: jamiId1,
                                        device: deviceId1,
                                        sinkId: CallTestFixtures.remoteSinkId,
                                        frameSize: CGSize(width: 320, height: 240)),
                                       CallTestFixtures.participant(
                                        uri: CallTestFixtures.peerUri,
                                        device: CallTestFixtures.remoteDeviceId,
                                        sinkId: CallTestFixtures.secondaryRemoteSinkId,
                                        frameSize: CGSize(width: 320, height: 240)),
                                       CallTestFixtures.participant(
                                        uri: CallTestFixtures.secondaryPeerUri,
                                        device: CallTestFixtures.secondaryRemoteDeviceId,
                                        sinkId: CallTestFixtures.tertiaryRemoteSinkId,
                                        frameSize: CGSize(width: 320, height: 240))]))

        await Harness.wait { model.conference?.participants.count == 3 }

        let renderedSources = Set(model.tiles.compactMap { $0.distributor?.source })
        XCTAssertEqual(renderedSources,
                       [.localCamera,
                        .remote(SinkId(raw: CallTestFixtures.secondaryRemoteSinkId)),
                        .remote(SinkId(raw: CallTestFixtures.tertiaryRemoteSinkId))])
        XCTAssertFalse(renderedSources.contains(.remote(SinkId(raw: harness.callId.raw))),
                       "the original call sink contains the peer's mixed conference frame")
    }

    func testModeratorMuteTogglesTheModeratorFlagNotTheirOwnMicrophone() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        let conferenceId = CallTestFixtures.conferenceId.raw
        let remoteId = CallTestFixtures.remoteSinkId
        harness.callAPI.conferenceCallsReturn[conferenceId] = [harness.callId.raw]
        harness.send(.conferenceCreated(conferenceId: conferenceId, conversationId: String(),
                                        accountId: Harness.accountId,
                                        state: ConferenceLifecycle.activeAttached.rawValue,
                                        memberCallIds: [harness.callId.raw],
                                        participants: [], media: []))
        func sendInfos(moderatorMuted: Bool) {
            harness.send(.conferenceInfosUpdated(
                            conferenceId: conferenceId,
                            participants: [
                                CallTestFixtures.participant(uri: String()),
                                CallTestFixtures.participant(
                                    uri: CallTestFixtures.peerUri,
                                    device: CallTestFixtures.remoteDeviceId,
                                    sinkId: CallTestFixtures.remoteSinkId,
                                    audioLocalMuted: true,
                                    audioModeratorMuted: moderatorMuted)
                            ]))
        }

        func muteCommands() -> [String] {
            harness.callAPI.moderationCommands.filter { $0.hasPrefix("muteStream:") }
        }

        func remoteRow() -> ConferenceParticipantRow? {
            model.participantRows.first { $0.id == remoteId }
        }

        sendInfos(moderatorMuted: false)
        await Harness.wait { remoteRow()?.isAudioModeratorMuted == false }

        model.perform(.muteAudio, on: remoteId)
        await Harness.wait { muteCommands().count == 1 }
        XCTAssertEqual(muteCommands().last?.hasSuffix(":true"), true,
                       "their own microphone mute is not a moderator mute")

        sendInfos(moderatorMuted: true)
        await Harness.wait { remoteRow()?.isAudioModeratorMuted == true }

        model.perform(.muteAudio, on: remoteId)
        await Harness.wait { muteCommands().count == 2 }
        XCTAssertEqual(muteCommands().last?.hasSuffix(":false"), true,
                       "the same action must lift the mute it applied")
    }

    func testHostedConferenceCameraTileUsesConferenceMediaState() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        let conferenceId = CallTestFixtures.conferenceId.raw
        let local = CallTestFixtures.participant(uri: String())
        let remote = CallTestFixtures.participant(
            uri: CallTestFixtures.peerUri, device: CallTestFixtures.remoteDeviceId,
            sinkId: CallTestFixtures.remoteSinkId)

        harness.send(.conferenceCreated(
                        conferenceId: conferenceId, conversationId: String(),
                        accountId: Harness.accountId,
                        state: ConferenceLifecycle.activeAttached.rawValue,
                        memberCallIds: [harness.callId.raw], participants: [local, remote],
                        media: [.audio(), .video(muted: true)]))
        await Harness.wait { model.conference?.id == CallTestFixtures.conferenceId }

        let localTile = model.tiles.first { $0.participant.id == local.id }
        XCTAssertTrue(localTile?.distributor === harness.videoService.localFrames)
        XCTAssertEqual(localTile?.tileState.showsVideo, false,
                       "the hosted conference camera is muted even if its member leg is not")
    }

    func testHostedConferenceVideoMuteHidesLocalCameraAndRevealsChrome() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        model.screenTapped()
        XCTAssertFalse(model.chromeVisible, "precondition: video call chrome can hide")
        let conferenceId = CallTestFixtures.conferenceId.raw

        harness.send(.conferenceCreated(
                        conferenceId: conferenceId, conversationId: "", accountId: Harness.accountId,
                        state: ConferenceLifecycle.activeAttached.rawValue,
                        memberCallIds: [harness.callId.raw],
                        participants: [],
                        media: [.audio(), .video(muted: true)]))
        harness.send(.conferenceInfosUpdated(
                        conferenceId: conferenceId,
                        participants: [CallTestFixtures.participant(
                                        uri: jamiId1, sinkId: "\(conferenceId)_video_0")]))

        await Harness.wait { model.conference?.participants.count == 1 }
        let localTile = model.tiles.first { $0.distributor === harness.videoService.localFrames }
        XCTAssertEqual(localTile?.tileState.showsVideo, false)
        XCTAssertTrue(model.chromeVisible,
                      "muting the effective host video makes the chrome persistent")
    }

    func testOnlyLocalModeratorCanAddToPeerHostedConference() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        func participant(_ uri: String, moderator: Bool) -> ConferenceParticipantInfo {
            CallTestFixtures.participant(uri: uri, device: uri, sinkId: "\(uri)_video_0",
                                         isModerator: moderator)
        }

        harness.send(.conferenceInfosUpdated(
                        conferenceId: harness.callId.raw,
                        participants: [participant(jamiId1, moderator: false),
                                       participant(CallTestFixtures.secondaryPeerUri,
                                                   moderator: true)]))
        await Harness.wait { model.conference?.participants.count == 2 }
        XCTAssertFalse(model.canAddParticipant)

        harness.send(.conferenceInfosUpdated(
                        conferenceId: harness.callId.raw,
                        participants: [participant(jamiId1, moderator: true),
                                       participant(CallTestFixtures.secondaryPeerUri,
                                                   moderator: true)]))
        await Harness.wait { model.canAddParticipant }
        XCTAssertTrue(model.canAddParticipant)
    }

    func testRaisingOurOwnHandLetsLibJamiResolveTheLocalDevice() async {
        let harness = await Harness(callHasVideo: true)
        let model = harness.makeModel(localJamiId: jamiId1)
        func roster(handRaised: Bool) -> LibJamiCallEvent {
            let participants = [
                CallTestFixtures.participant(uri: jamiId1, device: jamiId1,
                                             handRaised: handRaised),
                CallTestFixtures.participant(uri: CallTestFixtures.secondaryPeerUri,
                                             device: CallTestFixtures.secondaryPeerUri)
            ]
            return .conferenceInfosUpdated(conferenceId: harness.callId.raw,
                                           participants: participants)
        }

        harness.send(roster(handRaised: false))
        await Harness.wait { model.controlsPlan?.raiseHand != nil }

        model.perform(.toggleRaiseHand)
        await Harness.wait { !harness.callAPI.moderationCommands.isEmpty }
        XCTAssertEqual(harness.callAPI.moderationCommands, ["raiseHand:::true"],
                       "an empty uri and device raise the hand of this device")

        harness.send(roster(handRaised: true))
        await Harness.wait { model.localHandRaised }

        model.perform(.toggleRaiseHand)
        await Harness.wait { harness.callAPI.moderationCommands.count == 2 }
        XCTAssertEqual(harness.callAPI.moderationCommands.last, "raiseHand:::false")
    }

    func testOngoingOneToOneCallListsBothPeople() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)

        XCTAssertEqual(model.participantRows.map(\.uri),
                       [jamiId1, CallTestFixtures.peerUri],
                       "the roster is who is on the call, conference or not")
        XCTAssertTrue(model.pendingRows.isEmpty)
        XCTAssertFalse(model.header.showsRoster,
                       "but a two-person list has nothing in it to act on")
    }

    func testRingingCallHasNoRosterYet() {
        let call = makeCall(status: .ringing,
                            media: [.audio()],
                            isAudioOnly: true)
        let callService = CallService(callClient: TestLibJamiCallAPI(),
                                      callEvents: AsyncStream { _ in })
        let model = makeModel(call: call, callService: callService)

        XCTAssertTrue(model.participantRows.isEmpty,
                      "nobody is on a call that has not connected")
        XCTAssertFalse(model.header.showsRoster)
    }

    func testCancellingTheOnlyInviteLeavesTheCallRosterStanding() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)
        harness.callAPI.placeCallReturn = CallTestFixtures.secondaryCallId.raw

        harness.callService.addParticipant(uri: CallTestFixtures.secondaryPeerUri,
                                           toCall: harness.callId,
                                           requestedBy: jamiId1)
        await Harness.wait { model.pendingRows.count == 1 }
        XCTAssertEqual(model.participantRows.count, 2)
        XCTAssertTrue(model.header.showsRoster,
                      "a pending invite is something the roster can act on")

        model.cancelInvite(CallTestFixtures.secondaryCallId)
        await Harness.wait { model.pendingRows.isEmpty }

        XCTAssertEqual(model.participantRows.map(\.uri), [jamiId1, CallTestFixtures.peerUri],
                       "cancelling one invite must remove one row, not the whole list")
        XCTAssertFalse(model.header.showsRoster,
                       "with the invite gone this is a plain two-person call again")
    }

    func testConferenceStopsBeingTitledByTheAnsweringPeer() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)
        XCTAssertEqual(model.header.title, CallTestFixtures.peerUri,
                       "precondition: a one-to-one call")
        XCTAssertFalse(model.header.showsRoster, "two people are not worth a sheet")

        let conferenceId = CallTestFixtures.conferenceId.raw
        harness.callAPI.conferenceCallsReturn[conferenceId] = [harness.callId.raw]
        harness.send(.conferenceCreated(conferenceId: conferenceId, conversationId: "",
                                        accountId: Harness.accountId,
                                        state: ConferenceLifecycle.activeAttached.rawValue,
                                        memberCallIds: [harness.callId.raw],
                                        participants: [],
                                        media: [.audio()]))
        harness.send(.conferenceInfosUpdated(
                        conferenceId: conferenceId,
                        participants: [CallTestFixtures.participant(
                                        uri: CallTestFixtures.secondaryPeerUri,
                                        device: deviceId1),
                                       CallTestFixtures.participant(
                                        uri: CallTestFixtures.tertiaryPeerUri,
                                        device: deviceId2)]))
        await Harness.wait { model.conference?.participants.count == 2 }

        XCTAssertEqual(model.header.title, L10n.Calls.participantsInCall("2"),
                       "conference events must reach the header — it stops showing "
                        + "whoever answered first")
        XCTAssertTrue(model.header.showsRoster)
    }

    func testConferenceWithNoInfosYetStillCountsThePeopleTalking() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)
        let conferenceId = CallTestFixtures.conferenceId.raw
        harness.callAPI.conferenceCallsReturn[conferenceId] = [harness.callId.raw]

        harness.send(.conferenceCreated(conferenceId: conferenceId, conversationId: "",
                                        accountId: Harness.accountId,
                                        state: ConferenceLifecycle.activeAttached.rawValue,
                                        memberCallIds: [harness.callId.raw],
                                        participants: [],
                                        media: [.audio()]))
        await Harness.wait { model.conference != nil }

        XCTAssertEqual(model.header.title, L10n.Calls.participantsInCall("2"),
                       "the conference exists before its first infos arrive — "
                        + "the two people already talking are not nobody")
    }

    func testConferenceRetargetDropsThePreviousPeersResolvedName() async {
        let harness = await Harness(callHasVideo: false)
        let nameService = NameService(
            withNameRegistrationAdapter: NameRegistrationAdapter())
        let model = harness.makeModel(localJamiId: jamiId1, nameService: nameService)

        let response = LookupNameResponse()
        response.state = .found
        response.address = CallTestFixtures.peerUri
        response.name = profileName1
        response.requestedName = ""
        nameService.usernameLookupStatus.onNext(response)
        await Harness.wait { model.header.title == profileName1 }

        let conferenceId = CallTestFixtures.conferenceId.raw
        let survivorId = CallTestFixtures.hostCallId.raw
        harness.send(.incomingCall(accountId: Harness.accountId, callId: survivorId,
                                   peerUri: CallTestFixtures.tertiaryPeerUri,
                                   media: [.audio()], details: nil))
        harness.send(.callStateChanged(callId: survivorId, state: .current,
                                       rawState: LibJamiCallState.current.rawValue,
                                       accountId: Harness.accountId,
                                       code: 0, negotiatedMedia: [.audio()], videoCodec: nil))
        harness.send(.conferenceCreated(conferenceId: conferenceId, conversationId: "",
                                        accountId: Harness.accountId,
                                        state: ConferenceLifecycle.activeAttached.rawValue,
                                        memberCallIds: [harness.callId.raw, survivorId],
                                        participants: [], media: [.audio()]))
        await Harness.wait { model.conference?.memberCallIds.count == 2 }

        harness.send(.callStateChanged(callId: harness.callId.raw, state: .over,
                                       rawState: LibJamiCallState.over.rawValue,
                                       accountId: Harness.accountId,
                                       code: 0, negotiatedMedia: [], videoCodec: nil))
        await Harness.wait {
            model.currentCallId == CallId(raw: survivorId)
                && model.call?.peerUri == CallTestFixtures.tertiaryPeerUri
        }
        harness.send(.conferenceRemoved(conferenceId: conferenceId))
        await Harness.wait { model.conference == nil }

        XCTAssertEqual(model.header.title, CallTestFixtures.tertiaryPeerUri,
                       "the survivor must not inherit the previous peer's resolved name")
    }

    func testStatusLineCarriesTheDurationOnceTheCallIsUp() async {
        let harness = await Harness(callHasVideo: false)
        let model = harness.makeModel(localJamiId: jamiId1)

        XCTAssertNotNil(model.statusLine.range(of: "^[0-9]{2}:[0-9]{2}$",
                                               options: .regularExpression),
                        "a connected call shows its duration, not a status word")
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
        let callId = CallTestFixtures.callId
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
                               peerUri: CallTestFixtures.peerUri, media: media, details: nil))
            send(.callStateChanged(callId: callId.raw, state: .current,
                                   rawState: LibJamiCallState.current.rawValue, accountId: Self.accountId,
                                   code: 0, negotiatedMedia: media, videoCodec: nil))
            self.call = await Self.waitForCall(callService, callId) { $0.status == .current }
        }

        @MainActor
        func makeModel(localJamiId: String = "",
                       pipController: PiPControlling = PiPController(),
                       nameService: NameService = NameService(
                        withNameRegistrationAdapter: NameRegistrationAdapter()))
        -> CallViewModel {
            let database = DBManager(conversationHelper: ConversationDataHelper(),
                                     interactionHepler: InteractionDataHelper(),
                                     dbConnections: DBContainer())
            return CallViewModel(
                call: call,
                callService: callService,
                videoService: videoService,
                audio: AudioService(audio: LibJamiAudioClient(adapter: AudioAdapter())),
                profileService: ProfilesService(withProfilesAdapter: ProfilesAdapter(),
                                                dbManager: database),
                nameService: nameService,
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
            return CallTestFixtures.call(id: id,
                                         conversationId: nil,
                                         accountId: Harness.accountId,
                                         direction: .incoming,
                                         peerUri: CallTestFixtures.peerUri)
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
