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
final class CallEventResolverTests: XCTestCase {

    private enum CollectionError: Error {
        case timedOut
    }

    private var callAPI: TestLibJamiCallAPI!
    private var resolver: CallEventResolver!
    private var source: CallEventSource!

    override func setUp() {
        super.setUp()
        callAPI = TestLibJamiCallAPI()
        resolver = CallEventResolver(api: callAPI)
        source = CallEventSource { [resolver] in resolver?.handle($0) }
    }

    private func collect(count: Int) async throws -> [LibJamiCallEvent] {
        return try await withThrowingTaskGroup(of: [LibJamiCallEvent]?.self) { group in
            group.addTask { [resolver] in
                guard let resolver = resolver else { return nil }
                var events: [LibJamiCallEvent] = []
                for await event in resolver.events {
                    events.append(event)
                    if events.count == count { return events }
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return nil
            }
            guard let events = try await group.next() ?? nil else {
                group.cancelAll()
                throw CollectionError.timedOut
            }
            group.cancelAll()
            return events
        }
    }

    func testIncomingCallSignalBecomesTypedEvent() async throws {
        source.receivingCall(withAccountId: accountId1, callId: "call1", fromURI: "uri1",
                             withMedia: [["MEDIA_TYPE": "MEDIA_TYPE_AUDIO",
                                          "LABEL": "audio_0",
                                          "ENABLED": "true",
                                          "MUTED": "false"]])

        let events = try await collect(count: 1)
        guard case let .incomingCall(accountId, callId, peerUri, media, _) = events[0] else {
            return XCTFail("wrong event: \(events[0])")
        }
        XCTAssertEqual(accountId, accountId1)
        XCTAssertEqual(callId, "call1")
        XCTAssertEqual(peerUri, "uri1")
        XCTAssertEqual(media, [MediaItem.audio()])
    }

    func testIncomingCallCarriesCallDetails() async throws {
        callAPI.callDetailsReturn["call1"] = CallDetails(["PEER_NUMBER": "uri1",
                                                          "REGISTERED_NAME": "alice",
                                                          "DISPLAY_NAME": "Alice",
                                                          "ACCOUNTID": accountId1,
                                                          "AUDIO_ONLY": "true"])
        source.receivingCall(withAccountId: accountId1, callId: "call1", fromURI: "uri1",
                             withMedia: [])

        let events = try await collect(count: 1)
        guard case let .incomingCall(_, _, _, _, details) = events[0] else {
            return XCTFail("wrong event")
        }
        XCTAssertEqual(details?.displayName, "Alice")
        XCTAssertEqual(details?.registeredName, "alice")
    }

    func testStateChangeSignalKeepsRawStateForUnknownValues() async throws {
        source.didChangeCallState(withCallId: "c1", state: "CURRENT",
                                  accountId: accountId1, stateCode: 0)
        source.didChangeCallState(withCallId: "c2", state: "SOME_NEW_STATE",
                                  accountId: accountId1, stateCode: 7)

        let events = try await collect(count: 2)
        guard case let .callStateChanged(_, state1, raw1, _, _, _, _) = events[0],
              case let .callStateChanged(_, state2, raw2, _, code2, _, _) = events[1] else {
            return XCTFail("wrong events")
        }
        XCTAssertEqual(state1, .current)
        XCTAssertEqual(raw1, "CURRENT")
        XCTAssertNil(state2)
        XCTAssertEqual(raw2, "SOME_NEW_STATE")
        XCTAssertEqual(code2, 7)
    }

    func testNegotiatedMediaIsResolvedOnlyWhenCallBecomesCurrent() async throws {
        callAPI.currentMediaReturn["c1"] = [.audio(), .video()]
        source.didChangeCallState(withCallId: "c1", state: "CURRENT",
                                  accountId: accountId1, stateCode: 0)

        let events = try await collect(count: 1)
        guard case let .callStateChanged(_, _, _, _, _, negotiated, _) = events[0] else {
            return XCTFail("wrong event")
        }
        XCTAssertEqual(negotiated.map(\.label), [.audio(0), .video(0)])
    }

    func testNegotiatedMediaIsEmptyForNonCurrentStates() async throws {
        callAPI.currentMediaReturn["c1"] = [.audio(), .video()]
        source.didChangeCallState(withCallId: "c1", state: "RINGING",
                                  accountId: accountId1, stateCode: 0)

        let events = try await collect(count: 1)
        guard case let .callStateChanged(_, _, _, _, _, negotiated, _) = events[0] else {
            return XCTFail("wrong event")
        }
        XCTAssertTrue(negotiated.isEmpty)
    }

    func testConferenceSignalsCarryMemberCalls() async throws {
        callAPI.conferenceCallsReturn["conf1"] = ["m1", "m2"]
        callAPI.currentMediaReturn["conf1"] = [.audio(muted: true), .video()]
        callAPI.conferenceDetailsReturn["conf1"] = ["STATE": "ACTIVE_ATTACHED"]
        callAPI.conferenceInfosReturn["conf1"] = [ConferenceParticipantInfo(
            ["uri": "", "device": "local-device", "sinkId": "host_video_0"]
        )!]
        source.conferenceCreated(conferenceId: "conf1", conversationId: conversationId1,
                                 accountId: accountId1)
        source.conferenceChanged(conference: "conf1", accountId: accountId1, state: "",
                                 memberCallIds: ["m1", "m2"])

        let events = try await collect(count: 2)
        guard case let .conferenceCreated(_, conversationId, _, state, created,
                                          participants, media) = events[0],
              case let .conferenceChanged(_, _, _, changed) = events[1] else {
            return XCTFail("wrong events")
        }
        XCTAssertEqual(conversationId, conversationId1)
        XCTAssertEqual(state, "ACTIVE_ATTACHED")
        XCTAssertEqual(created, ["m1", "m2"])
        XCTAssertEqual(participants.map(\.device), ["local-device"])
        XCTAssertTrue(media.first(where: { $0.type == .audio })?.muted == true)
        XCTAssertEqual(changed, ["m1", "m2"])
    }

    func testMediaNegotiationStatusParsesEventAndMedia() async throws {
        source.didChangeMediaNegotiationStatus(withCallId: "c",
                                               event: "NEGOTIATION_SUCCESS",
                                               withMedia: [["MEDIA_TYPE": "MEDIA_TYPE_VIDEO",
                                                            "LABEL": "video_0",
                                                            "ENABLED": "true",
                                                            "MUTED": "true"]])

        let events = try await collect(count: 1)
        guard case let .mediaNegotiationStatus(callId, event, media) = events[0] else {
            return XCTFail("wrong event")
        }
        XCTAssertEqual(callId, "c")
        XCTAssertEqual(event, .success)
        XCTAssertEqual(media.first?.label, .video(0))
        XCTAssertEqual(media.first?.muted, true)
    }

    func testConferenceInfosSignalParsesParticipants() async throws {
        source.conferenceInfoUpdated(conference: "conf1",
                                     info: [["uri": "u1", "device": deviceId1,
                                             "sinkId": "s1", "active": "false"]])

        let events = try await collect(count: 1)
        guard case let .conferenceInfosUpdated(conferenceId, participants) = events[0] else {
            return XCTFail("wrong event")
        }
        XCTAssertEqual(conferenceId, "conf1")
        XCTAssertEqual(participants.count, 1)
        XCTAssertEqual(participants[0].uri, "u1")
    }

    func testEventsAreBufferedUntilConsumed() async throws {
        source.callPlacedOnHold(withCallId: "c1", hold: true)
        source.audioMuted(call: "c1", mute: true)
        source.videoMuted(call: "c1", mute: false)

        let events = try await collect(count: 3)
        XCTAssertEqual(events.count, 3)
        guard case .peerHold = events[0], case .audioMuted = events[1],
              case .videoMuted = events[2] else {
            return XCTFail("order not preserved: \(events)")
        }
    }
}
