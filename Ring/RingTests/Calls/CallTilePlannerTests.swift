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

final class CallTilePlannerTests: XCTestCase {

    private let localId = jamiId1

    func testConferenceHasNoFloatingPreview() {
        let tiles = CallTilePlanner.conferenceTiles(
            [CallTestFixtures.participant(uri: localId),
             CallTestFixtures.participant(uri: "alice")],
            localJamiId: localId, localCameraOn: true)
        XCTAssertFalse(tiles.contains { $0.isLocalPreview },
                       "a conference shows the local user as a grid tile, not a floating preview")
    }

    func testLocalParticipantRendersLocalCamera() {
        let tiles = CallTilePlanner.conferenceTiles(
            [CallTestFixtures.participant(uri: localId),
             CallTestFixtures.participant(uri: "alice")],
            localJamiId: localId, localCameraOn: true)
        let mine = tiles.first { $0.avatarUri == localId }
        XCTAssertEqual(mine?.source, .localCamera)
        XCTAssertEqual(mine?.showsVideo, true, "our tile follows our own camera state")
    }

    func testEmptyUriHostRendersLocalCamera() {
        let tiles = CallTilePlanner.conferenceTiles(
            [CallTestFixtures.participant(uri: ""),
             CallTestFixtures.participant(uri: "alice")],
            localJamiId: localId, localCameraOn: false)
        let mine = tiles.first { $0.source == .localCamera }
        XCTAssertNotNil(mine, "the empty-uri host cell is our own local-camera tile")
        XCTAssertEqual(mine?.avatarUri, localId, "it resolves against the local jami id")
        XCTAssertEqual(mine?.showsVideo, false, "camera off falls back to the avatar")
    }

    func testRemoteParticipantRendersItsSink() {
        let tiles = CallTilePlanner.conferenceTiles(
            [CallTestFixtures.participant(uri: localId),
             CallTestFixtures.participant(uri: "alice", videoMuted: true)],
            localJamiId: localId, localCameraOn: true)
        let alice = tiles.first { $0.avatarUri == "alice" }
        XCTAssertEqual(alice?.source, .remoteStream(SinkId(raw: "sink_alice")))
        XCTAssertEqual(alice?.showsVideo, false, "a muted remote camera shows the avatar")
    }

    func testDirectVideoCallHasFloatingPreview() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: true, hasVideo: true, hasNegotiatedVideo: true))
        XCTAssertEqual(tiles.count, 2)
        XCTAssertEqual(tiles.first { !$0.isLocalPreview }?.source,
                       .remoteStream(SinkId(raw: "c1")))
        XCTAssertEqual(tiles.filter { $0.isLocalPreview }.count, 1)
        let preview = tiles.first { $0.isLocalPreview }
        XCTAssertEqual(preview?.source, .localCamera)
        XCTAssertTrue(preview?.avatarUri.isEmpty == true, "the preview has no avatar")
    }

    func testDialingVideoCallShowsOnlyFullscreenLocalPreview() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: false, hasVideo: true, hasNegotiatedVideo: true))
        XCTAssertEqual(tiles.count, 1)
        let preview = tiles.first
        XCTAssertEqual(preview?.id, CanvasParticipant.localId)
        XCTAssertEqual(preview?.isLocalPreview, true)
        XCTAssertEqual(preview?.source, .localCamera)
        XCTAssertEqual(preview?.showsVideo, true)
        XCTAssertTrue(preview?.avatarUri.isEmpty == true,
                      "the unanswered video call shows an unobstructed local preview")
    }

    func testAudioCallHasNoPreview() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: true, hasVideo: false, hasNegotiatedVideo: false))
        XCTAssertFalse(tiles.contains { $0.isLocalPreview })
        XCTAssertEqual(tiles.first?.showsVideo, false)
    }

    func testPeerVideoRendersWhileOurCameraStaysOff() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: true, hasVideo: false, hasNegotiatedVideo: true))
        XCTAssertFalse(tiles.contains { $0.isLocalPreview },
                       "our camera is muted — no local preview")
        let remote = tiles.first
        XCTAssertEqual(remote?.source, .remoteStream(SinkId(raw: "c1")))
        XCTAssertEqual(remote?.showsVideo, true,
                       "an audio call the peer upgraded must attach the peer's sink")
    }

    func testConferenceCaptionsEveryTile() {
        let tiles = CallTilePlanner.conferenceTiles(
            [CallTestFixtures.participant(uri: localId),
             CallTestFixtures.participant(uri: "alice")],
            localJamiId: localId, localCameraOn: true)
        XCTAssertTrue(tiles.allSatisfy { $0.showsName },
                      "every conference tile names itself, our own cell included")
    }

    func testDialingAudioCallDoesNotCaptionRemoteTile() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: false, hasVideo: false, hasNegotiatedVideo: false))
        XCTAssertEqual(tiles.first?.showsName, false,
                       "the header already names the peer we are dialing")
    }

    func testOngoingVideoCallCaptionsNoTile() {
        let tiles = CallTilePlanner.directCallTiles(CallTilePlanner.DirectCall(
                                                        id: "c1", peerUri: "bob", isOngoing: true, hasVideo: true, hasNegotiatedVideo: true))
        XCTAssertFalse(tiles.contains { $0.showsName },
                       "neither the fullscreen remote nor the preview is captioned")
    }
}
