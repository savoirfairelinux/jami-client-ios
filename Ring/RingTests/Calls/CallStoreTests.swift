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
@testable import Ring

// This integration-style store suite intentionally exercises the complete actor API.
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class CallStoreTests: XCTestCase {

    private var callAPI: TestLibJamiCallAPI!
    private var store: CallStore!
    private var resolver: CallEventResolver!
    private var commandQueue: DispatchQueue!
    private var sendEvent: ((RawCallSignal) -> Void)!
    private var events: AsyncStream<CallSystemEvent>!

    override func setUp() async throws {
        try await super.setUp()
        callAPI = TestLibJamiCallAPI()
        resolver = CallEventResolver(api: callAPI)
        commandQueue = DispatchQueue(label: "com.savoirfairelinux.jami.calls.commands.test")
        sendEvent = { [resolver] in resolver?.handle($0) }
        store = CallStore(callAPI: callAPI, callEvents: resolver.events,
                          commandQueue: commandQueue)
        events = await store.events()
        await store.start()
    }

    private func flushCommands() {
        commandQueue.sync {}
    }

    @discardableResult
    private func expectEvent(_ description: String = "event",
                             matching predicate: @escaping (CallSystemEvent) -> Bool)
    async -> CallSystemEvent? {
        return await expectEvent(in: events, description, matching: predicate)
    }

    private func expectEvent(in stream: AsyncStream<CallSystemEvent>,
                             _ description: String = "event",
                             matching predicate: @escaping (CallSystemEvent) -> Bool)
    async -> CallSystemEvent? {
        return await withTaskGroup(of: CallSystemEvent?.self) { group in
            group.addTask {
                for await event in stream where predicate(event) { return event }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func receiveIncomingCall(callId: String = "call-in",
                                     peer: String = "peer1") async -> CallId {
        sendEvent(.incomingCall(accountId: accountId1, callId: callId, peerUri: peer,
                                media: [MediaItem.audio(), .video()].toDictionaries()))
        let event = await expectEvent { if case .callAdded = $0 { return true }; return false }
        XCTAssertNotNil(event, "incoming call should produce callAdded")
        return CallId(raw: callId)
    }

    func testAcceptingPendingCallAddsAConnectingCallWithNoLibJamiId() async {
        let call = await store.acceptPendingCall(peerId: "peer1", accountId: accountId1,
                                                 withVideo: true)
        flushCommands()

        XCTAssertTrue(call.id.isLocal, "no libjami id exists yet")
        XCTAssertEqual(call.status, .connecting)
        XCTAssertEqual(call.direction, .incoming)
        XCTAssertTrue(callAPI.accepted.isEmpty, "a local id must never reach libjami")

        let event = await expectEvent { if case .callAdded = $0 { return true }; return false }
        XCTAssertNotNil(event, "the screen is driven by callAdded")
    }

    func testLibJamiIncomingCallReplacesTheAcceptedPlaceholder() async {
        let placeholder = await store.acceptPendingCall(peerId: "peer1", accountId: accountId1,
                                                        withVideo: true)
        await expectEvent { if case .callAdded = $0 { return true }; return false }

        sendEvent(.incomingCall(accountId: accountId1, callId: "call-in", peerUri: "peer1",
                                media: [MediaItem.audio(), .video()].toDictionaries()))

        let event = await expectEvent { if case .callMatched = $0 { return true }; return false }
        guard case let .callMatched(replaced, matched)? = event else {
            return XCTFail("the libjami call must replace the placeholder")
        }
        XCTAssertEqual(replaced, placeholder.id)
        XCTAssertEqual(matched.id, CallId(raw: "call-in"))

        let state = await store.snapshot()
        XCTAssertEqual(state.calls.count, 1, "the placeholder is replaced, not duplicated")
        XCTAssertNil(state.call(placeholder.id))
    }

    func testAcceptedPlaceholderEndsWhenLibJamiNeverReportsTheCall() async {
        _ = await store.acceptPendingCall(peerId: "peer1", accountId: accountId1,
                                          withVideo: true, timeout: 0.1)
        await expectEvent { if case .callAdded = $0 { return true }; return false }

        let ended = await expectEvent { if case .callEnded = $0 { return true }; return false }
        XCTAssertNotNil(ended, "a placeholder libjami never confirms must not hang")
        let state = await store.snapshot()
        XCTAssertTrue(state.calls.isEmpty)
    }

    func testCancellingAnAcceptedPlaceholderSendsNoLibJamiCommand() async {
        let placeholder = await store.acceptPendingCall(peerId: "peer1", accountId: accountId1,
                                                        withVideo: true)
        await expectEvent { if case .callAdded = $0 { return true }; return false }

        await store.hangUp(placeholder.id)
        flushCommands()

        XCTAssertTrue(callAPI.hungUp.isEmpty, "there is no libjami call to hang up")
        let ended = await expectEvent { if case .callEnded = $0 { return true }; return false }
        XCTAssertNotNil(ended)
    }

    func testIncomingCallProducesIncomingState() async {
        let id = await receiveIncomingCall()
        let call = await store.snapshot().call(id)
        XCTAssertEqual(call?.status, .incoming)
        XCTAssertEqual(call?.direction, .incoming)
        XCTAssertEqual(call?.peerUri, "peer1")
        XCTAssertEqual(call?.media.count, 2)
    }

    func testAcceptSendsOfferedMediaToLibJami() async {
        let id = await receiveIncomingCall()

        await store.accept(id, withVideo: true)
        flushCommands()

        XCTAssertEqual(callAPI.accepted.count, 1)
        XCTAssertEqual(callAPI.accepted[0].callId, "call-in")
        XCTAssertEqual(callAPI.accepted[0].media.map(\.label), [.audio(0), .video(0)])
    }

    func testAcceptWithoutVideoMutesVideoInAnswer() async {
        let id = await receiveIncomingCall()

        await store.accept(id, withVideo: false)
        flushCommands()

        XCTAssertEqual(callAPI.accepted[0].media[1].muted, true)
    }

    func testAcceptIsRejectedWhenNotIncoming() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        await store.accept(id, withVideo: true)
        flushCommands()

        XCTAssertTrue(callAPI.accepted.isEmpty, "accept only valid from incoming")
    }

    func testRefuseSendsRefuse() async {
        let id = await receiveIncomingCall()
        await store.refuse(id)
        flushCommands()
        XCTAssertEqual(callAPI.refused, ["call-in"])
    }

    func testPlaceCallCreatesConnectingCall() async throws {
        callAPI.placeCallReturn = "call-out"

        let call = try await store.placeCall(accountId: accountId1, to: "peer2",
                                             audioOnly: false, videoSource: "camera://front")

        XCTAssertEqual(call.status, .connecting)
        XCTAssertEqual(call.direction, .outgoing)
        XCTAssertEqual(callAPI.placedCalls.count, 1)
        XCTAssertEqual(callAPI.placedCalls[0].media.map(\.label), [.audio(0), .video(0)])
        let stored = await store.snapshot().call(CallId(raw: "call-out"))
        XCTAssertNotNil(stored)
    }

    func testPlaceCallAudioOnly() async throws {
        _ = try await store.placeCall(accountId: accountId1, to: "peer2",
                                      audioOnly: true, videoSource: "camera://front")
        XCTAssertEqual(callAPI.placedCalls[0].media.map(\.label), [.audio(0)])
    }

    func testPlaceCallFailureThrows() async {
        callAPI.placeCallReturn = nil
        do {
            _ = try await store.placeCall(accountId: accountId1, to: "peer2",
                                          audioOnly: true, videoSource: "")
            XCTFail("should throw")
        } catch let error as CallStoreError {
            XCTAssertEqual(error, .placeCallFailed)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let count = await store.snapshot().calls.count
        XCTAssertEqual(count, 0)
    }

    func testPlaceCallWithRendezvousUriUsesCompleteMediaList() async throws {
        _ = try await store.placeCall(accountId: accountId1, to: "rdv:conv/uri/dev/id",
                                      audioOnly: true, videoSource: "camera://front")
        XCTAssertEqual(callAPI.placedCalls[0].media.map(\.label), [.audio(0), .video(0)])
        XCTAssertEqual(callAPI.placedCalls[0].media[1].muted, true)
    }

    func testRingingStateEmitsCallUpdated() async throws {
        callAPI.placeCallReturn = "call-out"
        _ = try await store.placeCall(accountId: accountId1, to: "p",
                                      audioOnly: true, videoSource: "")

        sendEvent(.callStateChanged(callId: "call-out", state: "RINGING",
                                    accountId: accountId1, code: 0))

        let event = await expectEvent { event in
            if case let .callUpdated(call) = event { return call.status == .ringing }
            return false
        }
        XCTAssertNotNil(event)
    }

    func testCurrentStateSetsStartDateAndFetchesMedia() async throws {
        callAPI.placeCallReturn = "call-out"
        callAPI.currentMediaReturn["call-out"] = [.audio(muted: true)]
        _ = try await store.placeCall(accountId: accountId1, to: "p",
                                      audioOnly: true, videoSource: "")

        sendEvent(.callStateChanged(callId: "call-out", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        let call = await store.snapshot().call(CallId(raw: "call-out"))
        XCTAssertEqual(call?.status, .current)
        XCTAssertNotNil(call?.startedAt)
        XCTAssertEqual(call?.media, [.audio(muted: true)], "media confirmed by libjami")
    }

    func testTerminalStateEmitsCallEndedAndRemovesCall() async {
        let id = await receiveIncomingCall()

        sendEvent(.callStateChanged(callId: id.raw, state: "OVER",
                                    accountId: accountId1, code: 0))

        let event = await expectEvent { if case .callEnded = $0 { return true }; return false }
        guard case let .callEnded(call, duration) = event else {
            return XCTFail("no callEnded")
        }
        XCTAssertEqual(call.id, id)
        XCTAssertEqual(duration, 0, "never connected -> zero duration (missed call)")
        let remaining = await store.snapshot().calls.count
        XCTAssertEqual(remaining, 0)
    }

    func testCallEventsReplayTerminalStateWhenObservationStartsAfterEnd() async throws {
        callAPI.placeCallReturn = "call-out"
        let placed = try await store.placeCall(accountId: accountId1, to: "peer2",
                                               audioOnly: true, videoSource: "")

        sendEvent(.callStateChanged(callId: placed.id.raw,
                                    state: "FAILURE", accountId: accountId1, code: 0))
        await expectEvent { if case .callEnded = $0 { return true }; return false }

        let screenEvents = await store.events(for: placed.id, fallback: placed)
        let replayed = await expectEvent(in: screenEvents) {
            if case .callEnded = $0 { return true }
            return false
        }

        guard case let .callEnded(call, duration) = replayed else {
            return XCTFail("late observation must replay callEnded")
        }
        XCTAssertEqual(call.id, placed.id)
        XCTAssertEqual(call.status, .terminated(.failure))
        XCTAssertEqual(duration, 0)
    }

    func testCallEventsReplayCurrentStateAndExcludeOtherCalls() async throws {
        callAPI.placeCallReturn = "target"
        let target = try await store.placeCall(accountId: accountId1, to: "peer2",
                                               audioOnly: true, videoSource: "")
        let screenEvents = await store.events(for: target.id, fallback: target)

        let replayed = await expectEvent(in: screenEvents) {
            if case .callUpdated = $0 { return true }
            return false
        }
        guard case let .callUpdated(call) = replayed else {
            return XCTFail("active observation must replay callUpdated")
        }
        XCTAssertEqual(call.id, target.id)
        XCTAssertEqual(call.status, .connecting)

        callAPI.placeCallReturn = "other"
        _ = try await store.placeCall(accountId: accountId1, to: "peer3",
                                      audioOnly: true, videoSource: "")
        sendEvent(.callStateChanged(callId: target.id.raw,
                                    state: "RINGING", accountId: accountId1, code: 0))

        let updated = await expectEvent(in: screenEvents) { event in
            switch event {
            case .callAdded, .callUpdated: return true
            default: return false
            }
        }
        guard case let .callUpdated(call) = updated else {
            return XCTFail("events for unrelated calls must be filtered out")
        }
        XCTAssertEqual(call.id, target.id)
        XCTAssertEqual(call.status, .ringing)
    }

    func testCallEventsReplayEndedCallWithoutAnyFallback() async throws {
        callAPI.placeCallReturn = "call-out"
        let placed = try await store.placeCall(accountId: accountId1, to: "peer2",
                                               audioOnly: true, videoSource: "")

        sendEvent(.callStateChanged(callId: placed.id.raw,
                                    state: "PEER_BUSY", accountId: accountId1, code: 0))
        await expectEvent { if case .callEnded = $0 { return true }; return false }

        let screenEvents = await store.events(for: placed.id)
        let replayed = await expectEvent(in: screenEvents) {
            if case .callEnded = $0 { return true }
            return false
        }

        guard case let .callEnded(call, _) = replayed else {
            return XCTFail("retarget subscribes without a snapshot and must still see the end")
        }
        XCTAssertEqual(call.id, placed.id)
        XCTAssertEqual(call.status, .terminated(.peerBusy))
    }

    func testCallEventsReportEndForStaleFallbackAfterTheEndedLogEvicted() async throws {
        callAPI.placeCallReturn = "call-out"
        let placed = try await store.placeCall(accountId: accountId1, to: "peer2",
                                               audioOnly: true, videoSource: "")
        sendEvent(.callStateChanged(callId: placed.id.raw,
                                    state: "FAILURE", accountId: accountId1, code: 0))
        await expectEvent { if case .callEnded = $0 { return true }; return false }

        for index in 0...EndedCallLog.limit {
            let id = "filler-\(index)"
            callAPI.placeCallReturn = id
            _ = try await store.placeCall(accountId: accountId1, to: "peer3",
                                          audioOnly: true, videoSource: "")
            sendEvent(.callStateChanged(callId: id, state: "OVER",
                                        accountId: accountId1, code: 0))
            await expectEvent { event in
                if case let .callEnded(call, _) = event { return call.id.raw == id }
                return false
            }
        }

        let screenEvents = await store.events(for: placed.id, fallback: placed)
        let replayed = await expectEvent(in: screenEvents) { event in
            switch event {
            case .callEnded, .callUpdated, .callAdded: return true
            default: return false
            }
        }

        guard case let .callEnded(call, _) = replayed else {
            return XCTFail("a call the store no longer knows has ended, whatever the snapshot says")
        }
        XCTAssertEqual(call.id, placed.id)
        XCTAssertTrue(call.status.isTerminal)
    }

    func testStateChangeForUnknownCallIsIgnored() async {
        sendEvent(.callStateChanged(callId: "ghost", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        sendEvent(.incomingCall(accountId: accountId1, callId: "real", peerUri: "p", media: []))
        await expectEvent { if case .callAdded = $0 { return true }; return false }
        let count = await store.snapshot().calls.count
        XCTAssertEqual(count, 1)
    }

    func testHangUpSendsHangUp() async {
        let id = await receiveIncomingCall()
        await store.hangUp(id)
        flushCommands()
        XCTAssertEqual(callAPI.hungUp, [id.raw])
    }

    func testHangUpEndsCallWithoutAnyLibJamiSignal() async {
        let id = await receiveIncomingCall()

        await store.hangUp(id)

        let event = await expectEvent { if case .callEnded = $0 { return true }; return false }
        guard case let .callEnded(call, _) = event else {
            return XCTFail("hangUp must end the call without waiting for libjami")
        }
        XCTAssertEqual(call.id, id)
        XCTAssertEqual(call.status, .terminated(.endedLocally))
        let remaining = await store.snapshot().calls.count
        XCTAssertEqual(remaining, 0, "call is gone before libjami confirms")
    }

    func testLibJamiOverAfterLocalHangUpIsIgnored() async {
        let id = await receiveIncomingCall()
        await store.hangUp(id)
        await expectEvent { if case .callEnded = $0 { return true }; return false }

        sendEvent(.callStateChanged(callId: id.raw, state: "OVER",
                                    accountId: accountId1, code: 0))

        let second = await expectEvent { if case .callEnded = $0 { return true }; return false }
        XCTAssertNil(second, "libjami's late OVER must not end the call twice")
    }

    func testHangUpEndsCallEvenWhenLibJamiRefusesTheCommand() async {
        let id = await receiveIncomingCall()
        callAPI.hangUpReturn = false

        await store.hangUp(id)
        flushCommands()

        XCTAssertEqual(callAPI.hungUp, [id.raw])
        let call = await store.snapshot().call(id)
        XCTAssertNil(call, "the user's decision does not wait on libjami")
    }

    func testRefuseEndsCallImmediatelyAsMissed() async {
        let id = await receiveIncomingCall()

        await store.refuse(id)
        flushCommands()

        XCTAssertEqual(callAPI.refused, [id.raw])
        let event = await expectEvent { if case .callEnded = $0 { return true }; return false }
        guard case let .callEnded(call, duration) = event else {
            return XCTFail("refuse must end the call without waiting for libjami")
        }
        XCTAssertEqual(call.status, .terminated(.endedLocally))
        XCTAssertEqual(duration, 0, "never connected -> zero duration (missed call)")
    }

    func testHoldOnlyFromCurrent() async {
        let id = await receiveIncomingCall()

        await store.hold(id, true)
        flushCommands()
        XCTAssertTrue(callAPI.held.isEmpty, "cannot hold before current")

        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        await store.hold(id, true)
        flushCommands()
        XCTAssertEqual(callAPI.held, [id.raw])

        sendEvent(.callStateChanged(callId: id.raw, state: "HOLD",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.status == .held(side: .local) }
            return false
        }
    }

    func testPeerHoldMergesIntoHoldSide() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        sendEvent(.peerHold(callId: id.raw, hold: true))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.status == .held(side: .peer) }
            return false
        }

        sendEvent(.peerHold(callId: id.raw, hold: false))
        let resumed = await expectEvent { event in
            if case let .callUpdated(call) = event { return call.status == .current }
            return false
        }
        XCTAssertNotNil(resumed)
    }

    func testIncomingMediaChangeRequestIsAnsweredPreservingState() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        sendEvent(.audioMuted(callId: id.raw, muted: false))
        sendEvent(.videoMuted(callId: id.raw, muted: true))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.isVideoMuted }
            return false
        }

        sendEvent(.mediaChangeRequested(accountId: accountId1, callId: id.raw,
                                        media: [MediaItem.audio(), .video()].toDictionaries()))
        sendEvent(.mediaNegotiationStatus(
                    callId: id.raw, event: "NEGOTIATION_SUCCESS",
                    media: [MediaItem.audio(),
                            MediaItem(type: .video, enabled: true, muted: true,
                                      label: .defaultVideo)].toDictionaries()))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.hasNegotiatedVideo }
            return false
        }

        flushCommands()
        XCTAssertEqual(callAPI.answeredMediaRequests.count, 1)
        let answer = callAPI.answeredMediaRequests[0].media
        XCTAssertEqual(answer.count, 2, "answer mirrors request size")
        XCTAssertEqual(answer[1].muted, true, "our muted video stays muted")
    }

    private func placeOngoingAudioCall(negotiated: [MediaItem] = [.audio()])
    async throws -> CallId {
        callAPI.placeCallReturn = "call-out"
        callAPI.currentMediaReturn["call-out"] = negotiated
        _ = try await store.placeCall(accountId: accountId1, to: "peer2",
                                      audioOnly: true, videoSource: "camera://front")
        sendEvent(.callStateChanged(callId: "call-out", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.status == .current }
            return false
        }
        return CallId(raw: "call-out")
    }

    func testPeerAddingVideoToAnAudioCallMakesTheCallVideoCapable() async throws {
        let id = try await placeOngoingAudioCall()
        var call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasNegotiatedVideo, false)

        sendEvent(.mediaChangeRequested(accountId: accountId1, callId: id.raw,
                                        media: [MediaItem.audio(), .video()].toDictionaries()))
        sendEvent(.mediaNegotiationStatus(
                    callId: id.raw, event: "NEGOTIATION_SUCCESS",
                    media: [MediaItem.audio(),
                            MediaItem(type: .video, enabled: true, muted: true,
                                      label: .defaultVideo)].toDictionaries()))
        await expectEvent { event in
            if case let .callUpdated(updated) = event { return updated.hasNegotiatedVideo }
            return false
        }
        flushCommands()

        call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasNegotiatedVideo, true,
                       "the peer's stream is what the remote tile renders")
        XCTAssertEqual(call?.isVideoMuted, true, "our own camera stays off")
        XCTAssertEqual(call?.isAudioOnly, true,
                       "the call was started audio-only; CallKit and the audio route keep that")

        let answer = callAPI.answeredMediaRequests[0].media
        XCTAssertEqual(answer.count, 2, "answer mirrors request size")
        XCTAssertEqual(answer[1].enabled, true)
        XCTAssertEqual(answer[1].muted, true)
    }

    func testUnnegotiatedMediaChangeRequestLeavesTheCallAudioOnly() async throws {
        let id = try await placeOngoingAudioCall()

        sendEvent(.mediaChangeRequested(accountId: accountId1, callId: id.raw,
                                        media: [MediaItem.audio(), .video()].toDictionaries()))
        sendEvent(.audioMuted(callId: id.raw, muted: true))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.isAudioMuted }
            return false
        }
        flushCommands()

        XCTAssertEqual(callAPI.answeredMediaRequests.count, 1, "the request is still answered")
        let call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasNegotiatedVideo, false,
                       "an answer is a proposal — only negotiation confirms media")
        XCTAssertEqual(call?.media, [.audio(muted: true)])
    }

    func testEnablingOurCameraOnAnAudioCallConfirmsOnNegotiation() async throws {
        let id = try await placeOngoingAudioCall()

        await store.toggleMute(id, label: .defaultVideo, cameraSource: "camera://front")
        flushCommands()

        let requested = callAPI.requestedMediaChanges[0].media
        XCTAssertEqual(requested.last?.type, .video)
        XCTAssertEqual(requested.last?.enabled, true)
        XCTAssertEqual(requested.last?.muted, false)

        var call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasNegotiatedVideo, false, "not confirmed by libjami yet")
        XCTAssertNotNil(call?.pendingMediaRequest)

        sendEvent(.mediaNegotiationStatus(
                    callId: id.raw, event: "NEGOTIATION_SUCCESS",
                    media: [MediaItem.audio(), .video()].toDictionaries()))
        await expectEvent { event in
            if case let .callUpdated(updated) = event { return updated.hasNegotiatedVideo }
            return false
        }

        call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasVideo, true)
        XCTAssertNil(call?.pendingMediaRequest)
    }

    func testMutingOurCameraKeepsTheCallVideoCapable() async throws {
        let id = try await placeOngoingAudioCall(negotiated: [.audio(), .video()])

        sendEvent(.videoMuted(callId: id.raw, muted: true))
        await expectEvent { event in
            if case let .callUpdated(updated) = event { return updated.isVideoMuted }
            return false
        }

        let call = await store.snapshot().call(id)
        XCTAssertEqual(call?.hasVideo, false, "our camera is off")
        XCTAssertEqual(call?.hasNegotiatedVideo, true,
                       "the stream is still negotiated, so the peer's video keeps rendering")
    }

    func testUpdateVideoSourceReInvitesUnmutedVideoWithTheNewSource() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        await store.updateVideoSource(id, source: "camera://mediumCamera")
        flushCommands()

        XCTAssertEqual(callAPI.requestedMediaChanges.count, 1)
        let media = callAPI.requestedMediaChanges[0].media
        XCTAssertEqual(media.first { $0.type == .video }?.source, "camera://mediumCamera")
        XCTAssertEqual(media.first { $0.type == .audio }?.source, "",
                       "audio streams keep their own source")
    }

    func testUpdateVideoSourceIgnoresMutedVideo() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }
        sendEvent(.mediaNegotiationStatus(
                    callId: id.raw, event: "NEGOTIATION_SUCCESS",
                    media: [MediaItem.audio(),
                            MediaItem(type: .video, enabled: true,
                                      muted: true, label: .defaultVideo)].toDictionaries()))
        await expectEvent { event in
            if case let .callUpdated(updated) = event { return updated.isVideoMuted }
            return false
        }

        await store.updateVideoSource(id, source: "camera://mediumCamera")
        flushCommands()

        XCTAssertTrue(callAPI.requestedMediaChanges.isEmpty)
    }

    func testToggleMuteSendsReInviteAndConfirmsOnNegotiation() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        await store.toggleMute(id, label: .defaultAudio, cameraSource: "camera://front")
        flushCommands()

        XCTAssertEqual(callAPI.requestedMediaChanges.count, 1)
        XCTAssertEqual(callAPI.requestedMediaChanges[0].media[0].muted, true)

        var call = await store.snapshot().call(id)
        XCTAssertEqual(call?.isAudioMuted, false)
        XCTAssertNotNil(call?.pendingMediaRequest)

        sendEvent(.mediaNegotiationStatus(
                    callId: id.raw, event: "NEGOTIATION_SUCCESS",
                    media: [MediaItem(type: .audio, enabled: true,
                                      muted: true, label: .audio(0)),
                            MediaItem.video()].toDictionaries()))
        await expectEvent { event in
            if case let .callUpdated(updated) = event { return updated.isAudioMuted }
            return false
        }
        call = await store.snapshot().call(id)
        XCTAssertNil(call?.pendingMediaRequest)
    }

    func testToggleMuteKeepsConfirmedStateWhenLibJamiRefuses() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }
        callAPI.requestMediaChangeReturn = false

        await store.toggleMute(id, label: .defaultAudio, cameraSource: "camera://front")
        flushCommands()

        XCTAssertEqual(callAPI.requestedMediaChanges.count, 1)
        let call = await store.snapshot().call(id)
        XCTAssertEqual(call?.isAudioMuted, false)
    }

    func testFailedNegotiationClearsThePendingRequest() async {
        let id = await receiveIncomingCall()
        sendEvent(.callStateChanged(callId: id.raw, state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        await store.toggleMute(id, label: .defaultAudio, cameraSource: "camera://front")
        var call = await store.snapshot().call(id)
        XCTAssertNotNil(call?.pendingMediaRequest)

        sendEvent(.mediaNegotiationStatus(callId: id.raw, event: "NEGOTIATION_FAIL",
                                          media: []))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        call = await store.snapshot().call(id)
        XCTAssertNil(call?.pendingMediaRequest)
        XCTAssertEqual(call?.isAudioMuted, false, "a failed negotiation changes nothing")
    }

    func testMuteIntentRejectedWhenNotOngoing() async {
        let id = await receiveIncomingCall()
        await store.toggleMute(id, label: .defaultAudio, cameraSource: "")
        flushCommands()
        XCTAssertTrue(callAPI.requestedMediaChanges.isEmpty)
    }

    func testRemoteRecordingChangedUpdatesCall() async {
        let id = await receiveIncomingCall()
        sendEvent(.remoteRecordingChanged(callId: id.raw, recording: true))
        let event = await expectEvent { event in
            if case let .callUpdated(call) = event { return call.peerIsRecording }
            return false
        }
        XCTAssertNotNil(event, "recording change should produce callUpdated")
        let call = await store.snapshot().call(id)
        XCTAssertEqual(call?.peerIsRecording, true)
    }

    func testAddParticipantLegCarriesVideoWheneverTheCallHasIt() async throws {
        let id = try await placeOngoingAudioCall(negotiated: [.audio(), .video()])

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id,
                                       videoSource: "camera://front")
        var media = callAPI.placedCalls[1].media
        XCTAssertEqual(media.map(\.label), [.audio(0), .video(0)])
        XCTAssertEqual(media[1].muted, false, "our camera is live, so the leg sends it")

        sendEvent(.videoMuted(callId: id.raw, muted: true))
        await expectEvent { event in
            if case let .callUpdated(call) = event { return call.isVideoMuted }
            return false
        }
        callAPI.placeCallReturn = "sub-call-2"
        try await store.addParticipant(peerUri: "peerC", toCall: id,
                                       videoSource: "camera://front")
        media = callAPI.placedCalls[2].media
        XCTAssertEqual(media.map(\.label), [.audio(0), .video(0)],
                       "the leg keeps a video stream so the new peer's video can reach us")
        XCTAssertEqual(media[1].muted, true,
                       "our camera is muted — the leg must not switch it back on")
    }

    func testAddParticipantMarksSubCallToJoinExistingCall() async throws {
        let id = try await placeOngoingAudioCall()

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id,
                                       videoSource: "camera://front")

        let added = await expectEvent { event in
            if case let .callAdded(call) = event { return call.id.raw == "sub-call" }
            return false
        }
        guard case let .callAdded(subCall)? = added else {
            return XCTFail("the sub-call is announced through callAdded")
        }
        XCTAssertTrue(subCall.joinsExistingCall,
                      "the leg folds into the current call, so it must not be presented")
    }

    func testPlacedCallIsNotMarkedAsJoiningExistingCall() async throws {
        callAPI.placeCallReturn = "call-out"

        let call = try await store.placeCall(accountId: accountId1, to: "peer2",
                                             audioOnly: false, videoSource: "camera://front")

        XCTAssertFalse(call.joinsExistingCall,
                       "a user-initiated call is its own foreground call")
    }

    func testAddParticipantToAnAudioOnlyCallPlacesAnAudioLeg() async throws {
        let id = try await placeOngoingAudioCall()

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id,
                                       videoSource: "camera://front")
        XCTAssertEqual(callAPI.placedCalls[1].media.map(\.label), [.audio(0)])
    }

    func testAddParticipantDefersJoinUntilSubCallIsCurrent() async throws {
        callAPI.placeCallReturn = "host-call"
        _ = try await store.placeCall(accountId: accountId1, to: "peerA",
                                      audioOnly: true, videoSource: "")
        sendEvent(.callStateChanged(callId: "host-call", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { if case .callUpdated = $0 { return true }; return false }

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: CallId(raw: "host-call"),
                                       videoSource: "")
        flushCommands()
        XCTAssertEqual(callAPI.placedCalls.count, 2)
        XCTAssertTrue(callAPI.joinedCalls.isEmpty, "join must wait for sub-call CURRENT")

        sendEvent(.callStateChanged(callId: "sub-call", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            guard case let .callUpdated(call) = event else { return false }
            return call.id == CallId(raw: "sub-call") && call.status == .current
        }
        flushCommands()
        XCTAssertEqual(callAPI.joinedCalls.count, 1)
        XCTAssertEqual(callAPI.joinedCalls[0].first, "host-call")
        XCTAssertEqual(callAPI.joinedCalls[0].second, "sub-call")
    }

    func testAddParticipantListsTheInviteOnTheHostCall() async throws {
        let id = try await placeOngoingAudioCall()

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")

        let event = await expectEvent { event in
            if case let .callUpdated(call) = event {
                return call.id == id && !call.pendingInvites.isEmpty
            }
            return false
        }
        XCTAssertNotNil(event, "the screen learns about the invite through the host call")
        let host = await store.snapshot().call(id)
        XCTAssertEqual(host?.pendingInvites,
                       [PendingConferenceInvite(callId: CallId(raw: "sub-call"),
                                                peerUri: "peerB",
                                                status: .connecting)])
    }

    func testInviteReportsTheLegsProgress() async throws {
        let id = try await placeOngoingAudioCall()
        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        sendEvent(.callStateChanged(callId: "sub-call", state: "RINGING",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callUpdated(call) = event {
                return call.id == id && call.pendingInvites.first?.status == .ringing
            }
            return false
        }

        let host = await store.snapshot().call(id)
        XCTAssertEqual(host?.pendingInvites.first?.status, .ringing,
                       "the row must say what the invitee's phone is doing")
    }

    func testAJoinedPeerIsNeverReportedAsStillInvited() async throws {
        let id = try await placeOngoingAudioCall()
        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        sendEvent(.callStateChanged(callId: "sub-call", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        let event = await expectEvent { event in
            guard case let .callUpdated(call) = event, call.id == id else { return false }
            return call.pendingInvites.contains { $0.status == .current }
        }
        XCTAssertNil(event,
                     "a peer who joined belongs in the conference, never in the invited list")
        let host = await store.snapshot().call(id)
        XCTAssertEqual(host?.pendingInvites, [])
    }

    func testInviteLeavesThePendingListWhenTheInviteeJoins() async throws {
        let id = try await placeOngoingAudioCall()
        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        sendEvent(.callStateChanged(callId: "sub-call", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callUpdated(call) = event {
                return call.id == id && call.pendingInvites.isEmpty
            }
            return false
        }

        let host = await store.snapshot().call(id)
        XCTAssertEqual(host?.pendingInvites, [],
                       "once joined, the invitee is a conference participant")
    }

    func testCancellingAnInviteRemovesItFromTheHostCall() async throws {
        let id = try await placeOngoingAudioCall()
        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        await store.hangUp(CallId(raw: "sub-call"))
        flushCommands()

        XCTAssertEqual(callAPI.hungUp, ["sub-call"])
        let host = await store.snapshot().call(id)
        XCTAssertEqual(host?.pendingInvites, [], "the cancelled leg leaves the list")
    }

    func testEndingTheHostCallHangsUpItsRingingInvite() async throws {
        let id = try await placeOngoingAudioCall()
        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerB", toCall: id, videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        await store.hangUp(id)
        flushCommands()

        XCTAssertTrue(callAPI.hungUp.contains("sub-call"),
                      "the leg has no session left to fold into")
        let state = await store.snapshot()
        XCTAssertTrue(state.calls.isEmpty)
    }

    func testInviteFollowsTheConferenceWhenItsHostLegEnds() async throws {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }
        sendEvent(.callStateChanged(callId: "member-1", state: "CURRENT",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callUpdated(call) = event {
                return call.id == CallId(raw: "member-1") && call.status == .current
            }
            return false
        }

        callAPI.placeCallReturn = "sub-call"
        try await store.addParticipant(peerUri: "peerC", toCall: CallId(raw: "member-1"),
                                       videoSource: "")
        await expectEvent { event in
            if case let .callUpdated(call) = event { return !call.pendingInvites.isEmpty }
            return false
        }

        sendEvent(.callStateChanged(callId: "member-1", state: "OVER",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .callEnded(call, _) = event { return call.id == CallId(raw: "member-1") }
            return false
        }
        flushCommands()

        XCTAssertFalse(callAPI.hungUp.contains("sub-call"),
                       "the conference lives on, so the invite is still wanted")
        let survivor = await store.snapshot().call(CallId(raw: "member-2"))
        XCTAssertEqual(survivor?.pendingInvites.map(\.callId), [CallId(raw: "sub-call")],
                       "the invite moves to a member that can still host the join")
    }

    func testConferenceCreatedLinksMemberCalls() async {
        let id = await receiveIncomingCall(callId: "member-1")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1"]

        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))

        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }
        let state = await store.snapshot()
        XCTAssertEqual(state.conferences.count, 1)
        XCTAssertEqual(state.call(id)?.conferenceId, ConfId(raw: "conf-1"))
        XCTAssertEqual(state.conferences[ConfId(raw: "conf-1")]?.memberCallIds,
                       [CallId(raw: "member-1")])
    }

    func testLocallyCreatedConferenceIsHosted() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]

        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conf) = event {
                return conf.id == ConfId(raw: "conf-1") && conf.isHost
            }
            return false
        }
        XCTAssertNotNil(event, "receiving conferenceCreated means the daemon hosts it here")
    }

    func testConferenceInfosUpdateParticipants() async {
        callAPI.conferenceCallsReturn["conf-1"] = []
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        let info = ["uri": "u1", "device": deviceId1,
                    "sinkId": "conf-1_video_0", "active": "true"]
        sendEvent(.conferenceInfosUpdated(conferenceId: "conf-1", info: [info]))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conf) = event { return !conf.participants.isEmpty }
            return false
        }
        XCTAssertNotNil(event)
    }

    func testPeerHostedConferenceInfosPromoteDirectCall() async {
        let id = await receiveIncomingCall(callId: "member-1", peer: "peer1")
        let infos = [
            ["uri": jamiId1, "device": "local", "sinkId": "member-1_video_0",
             "w": "320", "h": "240"],
            ["uri": "peer1", "device": "remote", "sinkId": "member-1_video_1",
             "w": "320", "h": "240"]
        ]

        sendEvent(.conferenceInfosUpdated(conferenceId: id.raw, info: infos))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
                    && conference.participants.count == 2
            }
            return false
        }
        XCTAssertNotNil(event)
        let state = await store.snapshot()
        XCTAssertEqual(state.call(id)?.conferenceId, ConfId(raw: id.raw))
        XCTAssertEqual(state.conferences[ConfId(raw: id.raw)]?.memberCallIds, [id])
        XCTAssertEqual(state.conferences[ConfId(raw: id.raw)]?.participants.map(\.sinkId),
                       [SinkId(raw: "member-1_video_0"),
                        SinkId(raw: "member-1_video_1")])
        XCTAssertEqual(state.conferences[ConfId(raw: id.raw)]?.isHost, false)
    }

    func testPeerHostedConferenceEndsWhenItsCallEnds() async {
        let id = await receiveIncomingCall(callId: "member-1", peer: "peer1")
        let infos = [
            ["uri": jamiId1, "device": "local", "sinkId": "member-1_video_0",
             "w": "320", "h": "240"],
            ["uri": "peer1", "device": "remote", "sinkId": "member-1_video_1",
             "w": "320", "h": "240"]
        ]
        sendEvent(.conferenceInfosUpdated(conferenceId: id.raw, info: infos))
        await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
            }
            return false
        }

        sendEvent(.callStateChanged(callId: id.raw, state: "OVER",
                                    accountId: accountId1, code: 0))

        let ended = await expectEvent { event in
            if case let .conferenceEnded(confId, remaining) = event {
                return confId == ConfId(raw: id.raw) && remaining == nil
            }
            return false
        }
        XCTAssertNotNil(ended, "a synthesized peer-hosted conference must end with its call")
        let state = await store.snapshot()
        XCTAssertNil(state.conferences[ConfId(raw: id.raw)],
                     "the synthesized conference must not leak after its call ends")
        XCTAssertNil(state.call(id))
    }

    func testPeerHostedConferenceCollapsesBackToOneToOneOnEmptyInfos() async {
        let id = await receiveIncomingCall(callId: "member-1", peer: "peer1")
        let infos = [
            ["uri": jamiId1, "device": "local", "sinkId": "member-1_video_0",
             "w": "320", "h": "240"],
            ["uri": "peer1", "device": "remote", "sinkId": "member-1_video_1",
             "w": "320", "h": "240"]
        ]
        sendEvent(.conferenceInfosUpdated(conferenceId: id.raw, info: infos))
        await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
            }
            return false
        }

        sendEvent(.conferenceInfosUpdated(conferenceId: id.raw, info: []))

        let ended = await expectEvent { event in
            if case let .conferenceEnded(confId, remaining) = event {
                return confId == ConfId(raw: id.raw) && remaining == id
            }
            return false
        }
        XCTAssertNotNil(ended, "an empty peer-hosted layout means the conference ended")
        let state = await store.snapshot()
        XCTAssertNil(state.conferences[ConfId(raw: id.raw)],
                     "the synthesized conference must be gone once the peer collapses it")
        XCTAssertNotNil(state.call(id), "the direct call continues as one-to-one")
        XCTAssertNil(state.call(id)?.conferenceId)
    }

    func testConferenceInfosWaitForTheirCall() async {
        let infos = [["uri": "peer1", "device": "remote",
                      "sinkId": "member-1_video_1", "w": "320", "h": "240"]]
        sendEvent(.conferenceInfosUpdated(conferenceId: "member-1", info: infos))

        let id = await receiveIncomingCall(callId: "member-1", peer: "peer1")

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
                    && conference.participants.map(\.sinkId)
                    == [SinkId(raw: "member-1_video_1")]
            }
            return false
        }
        XCTAssertNotNil(event)
        let state = await store.snapshot()
        XCTAssertEqual(state.call(id)?.conferenceId, ConfId(raw: id.raw))
    }

    func testConferenceInfosWaitForTheirLifecycleOwner() async {
        let infos = [["uri": "peer1", "device": "remote",
                      "sinkId": "conf-1_video_1", "w": "320", "h": "240"]]
        sendEvent(.conferenceInfosUpdated(conferenceId: "conf-1", info: infos))
        callAPI.conferenceCallsReturn["conf-1"] = []

        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: "conf-1")
                    && conference.participants.map(\.sinkId)
                    == [SinkId(raw: "conf-1_video_1")]
            }
            return false
        }
        XCTAssertNotNil(event)
    }

    func testConferenceCreationPreservesEarlierParticipantInfos() async {
        let id = await receiveIncomingCall(callId: "member-1", peer: "peer1")
        let infos = [["uri": "peer1", "device": "remote",
                      "sinkId": "member-1_video_1", "w": "320", "h": "240"]]
        sendEvent(.conferenceInfosUpdated(conferenceId: id.raw, info: infos))
        await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
                    && !conference.participants.isEmpty
            }
            return false
        }

        callAPI.conferenceCallsReturn[id.raw] = [id.raw]
        sendEvent(.conferenceCreated(conferenceId: id.raw, conversationId: "",
                                     accountId: accountId1))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conference) = event {
                return conference.id == ConfId(raw: id.raw)
                    && conference.memberCallIds == [id]
                    && conference.participants.map(\.sinkId)
                    == [SinkId(raw: "member-1_video_1")]
            }
            return false
        }
        XCTAssertNotNil(event)
    }

    func testEmptyConferenceInfosFlapIsIgnored() async {
        _ = await receiveIncomingCall(callId: "member-1")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        let info = ["uri": "u1", "device": deviceId1, "sinkId": "s1", "active": "true"]
        sendEvent(.conferenceInfosUpdated(conferenceId: "conf-1", info: [info]))
        await expectEvent { event in
            if case let .conferenceUpdated(conf) = event { return !conf.participants.isEmpty }
            return false
        }

        sendEvent(.conferenceInfosUpdated(conferenceId: "conf-1", info: []))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        let conference = await store.snapshot().conferences[ConfId(raw: "conf-1")]
        XCTAssertEqual(conference?.participants.count, 1, "flap ignored")
    }

    func testConferenceRemovedCleansUp() async {
        let id = await receiveIncomingCall(callId: "member-1")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        sendEvent(.conferenceRemoved(conferenceId: "conf-1"))

        await expectEvent { if case .conferenceEnded = $0 { return true }; return false }
        let state = await store.snapshot()
        XCTAssertTrue(state.conferences.isEmpty)
        XCTAssertNil(state.call(id)?.conferenceId)
    }

    func testMemberLeavingKeepsConferenceAlive() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        sendEvent(.callStateChanged(callId: "member-1", state: "OVER",
                                    accountId: accountId1, code: 0))

        let shrink = await expectEvent { event in
            if case let .conferenceUpdated(conf) = event {
                return conf.memberCallIds == [CallId(raw: "member-2")]
            }
            return false
        }
        XCTAssertNotNil(shrink, "the conference shrinks to the remaining member")
        let state = await store.snapshot()
        XCTAssertNotNil(state.conferences[ConfId(raw: "conf-1")], "conference persists")
    }

    func testConferenceRemovedReportsRemainingCall() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        sendEvent(.callStateChanged(callId: "member-1", state: "OVER",
                                    accountId: accountId1, code: 0))
        await expectEvent { event in
            if case let .conferenceUpdated(conf) = event {
                return conf.memberCallIds == [CallId(raw: "member-2")]
            }
            return false
        }

        sendEvent(.conferenceRemoved(conferenceId: "conf-1"))

        let ended = await expectEvent { event in
            if case let .conferenceEnded(_, remaining) = event {
                return remaining == CallId(raw: "member-2")
            }
            return false
        }
        XCTAssertNotNil(ended, "the surviving call is reported on collapse")
    }

    func testHangUpConferenceEndsConferenceBeforeItsMembers() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        await store.hangUpConference(ConfId(raw: "conf-1"))
        flushCommands()

        XCTAssertEqual(callAPI.hungUpConferences, ["conf-1"])
        let first = await expectEvent { event in
            switch event {
            case .conferenceEnded, .callEnded: return true
            default: return false
            }
        }
        guard case let .conferenceEnded(_, remaining) = first else {
            return XCTFail("the conference must end before any of its members")
        }
        XCTAssertNil(remaining, "the host ended the session — nothing survives it")

        let state = await store.snapshot()
        XCTAssertTrue(state.conferences.isEmpty)
        XCTAssertTrue(state.calls.isEmpty, "every member ends without libjami")
    }

    func testLibJamiConferenceRemovedAfterLocalHangUpIsIgnored() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        await store.hangUpConference(ConfId(raw: "conf-1"))
        await expectEvent { if case .conferenceEnded = $0 { return true }; return false }

        sendEvent(.conferenceRemoved(conferenceId: "conf-1"))

        let second = await expectEvent { if case .conferenceEnded = $0 { return true }
            return false
        }
        XCTAssertNil(second, "libjami's late removal must not end it twice")
    }

    func testHangUpConferenceEndsSessionEvenWhenLibJamiRefusesTheCommand() async {
        _ = await receiveIncomingCall(callId: "member-1", peer: "p1")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }
        callAPI.hangUpConferenceReturn = false

        await store.hangUpConference(ConfId(raw: "conf-1"))
        flushCommands()

        XCTAssertEqual(callAPI.hungUpConferences, ["conf-1"])
        let state = await store.snapshot()
        XCTAssertNil(state.conferences[ConfId(raw: "conf-1")],
                     "the host's decision does not wait on libjami")
        XCTAssertTrue(state.calls.isEmpty)
    }

    func testConferenceChangeDetachesDepartedMember() async {
        let id1 = await receiveIncomingCall(callId: "member-1", peer: "p1")
        _ = await receiveIncomingCall(callId: "member-2", peer: "p2")
        callAPI.conferenceCallsReturn["conf-1"] = ["member-1", "member-2"]
        sendEvent(.conferenceCreated(conferenceId: "conf-1", conversationId: "",
                                     accountId: accountId1))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        callAPI.conferenceCallsReturn["conf-1"] = ["member-2"]
        sendEvent(.conferenceChanged(conferenceId: "conf-1", accountId: accountId1, state: ""))
        await expectEvent { if case .conferenceUpdated = $0 { return true }; return false }

        let state = await store.snapshot()
        XCTAssertNil(state.call(id1)?.conferenceId, "departed member is detached")
    }

    func testPlaceSwarmCallResolvesOnConferenceCreated() async throws {
        callAPI.placeCallReturn = "swarm-call"
        callAPI.conferenceCallsReturn["conf-s"] = ["swarm-call"]
        let placeCallStarted = expectation(description: "swarm call placed")
        callAPI.onPlaceCall = { placeCallStarted.fulfill() }

        async let placed = store.placeSwarmCall(accountId: accountId1,
                                                conversationId: "conv-1",
                                                audioOnly: false,
                                                videoSource: "camera://front",
                                                timeout: 2)
        await fulfillment(of: [placeCallStarted], timeout: 1)
        sendEvent(.conferenceCreated(conferenceId: "conf-s", conversationId: "conv-1",
                                     accountId: accountId1))

        let confId = try await placed
        XCTAssertEqual(confId, ConfId(raw: "conf-s"))
        XCTAssertEqual(callAPI.placedCalls[0].participantId, "swarm:conv-1")
        XCTAssertEqual(callAPI.placedCalls[0].media.map(\.label), [.audio(0), .video(0)])
    }

    func testPlaceSwarmCallTimesOut() async {
        callAPI.placeCallReturn = "swarm-call"
        do {
            _ = try await store.placeSwarmCall(accountId: accountId1, conversationId: "conv-1",
                                               audioOnly: true, videoSource: "",
                                               timeout: 0.1)
            XCTFail("should time out")
        } catch let error as CallStoreError {
            XCTAssertEqual(error, .swarmCallTimedOut)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testJoiningRendezvousCallMarksItAccepted() async throws {
        let account = ActiveCallsTracker.AccountRef(id: accountId1, jamiId: jamiId1,
                                                    currentDeviceId: deviceId2)
        await store.updateActiveCalls(
            conversationId: conversationId1,
            calls: [["id": "c1", "uri": "remote", "device": deviceId1]],
            account: account)

        callAPI.placeCallReturn = "rdv-call"
        _ = try await store.placeCall(accountId: accountId1,
                                      to: "rdv:\(conversationId1)/remote/\(deviceId1)/c1",
                                      audioOnly: true, videoSource: "")

        let accepted = await expectEvent { event in
            if case let .activeCallsChanged(trackers) = event {
                return trackers[accountId1]?.notAcceptedCalls(for: conversationId1).isEmpty == true
            }
            return false
        }
        XCTAssertNotNil(accepted, "joined rdv call is accepted on all trackers")

        sendEvent(.callStateChanged(callId: "rdv-call", state: "OVER",
                                    accountId: accountId1, code: 0))
        let reopened = await expectEvent { event in
            if case let .activeCallsChanged(trackers) = event {
                return trackers[accountId1]?.notAcceptedCalls(for: conversationId1).count == 1
            }
            return false
        }
        XCTAssertNotNil(reopened, "hangup re-opens the accepted slot")
    }

    func testSwarmHostDetectedFromOutgoingSwarmCall() async throws {
        callAPI.placeCallReturn = "swarm-call"
        callAPI.conferenceCallsReturn["conf-x"] = ["swarm-call"]
        _ = try await store.placeCall(accountId: accountId1, to: "swarm:conv9",
                                      audioOnly: true, videoSource: "")

        sendEvent(.conferenceCreated(conferenceId: "conf-x", conversationId: "conv9",
                                     accountId: accountId1))

        let event = await expectEvent { event in
            if case let .conferenceUpdated(conf) = event { return conf.isHost }
            return false
        }
        XCTAssertNotNil(event)
        let call = await store.snapshot().call(CallId(raw: "swarm-call"))
        XCTAssertEqual(call?.conversationId, "conv9")
    }

    func testSendInCallMessage() async {
        let id = await receiveIncomingCall()
        await store.sendInCallMessage(id, message: ["text/plain": "hi"],
                                      from: jamiId1, isMixed: false)
        flushCommands()
        XCTAssertEqual(callAPI.sentMessages.count, 1)
        XCTAssertEqual(callAPI.sentMessages[0].message["text/plain"], "hi")
    }

    func testIncomingMessageIsForwarded() async {
        let id = await receiveIncomingCall()
        sendEvent(.incomingMessage(callId: id.raw, fromUri: "peer1",
                                   message: ["text/plain": "yo"]))
        let event = await expectEvent { if case .incomingMessage = $0 { return true }; return false }
        XCTAssertNotNil(event)
    }

    func testPlayDTMF() async {
        await store.playDTMF(code: "5")
        flushCommands()
        XCTAssertEqual(callAPI.dtmfCodes, ["5"])
    }
}
