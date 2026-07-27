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

final class LibJamiCallParsingTests: XCTestCase {

    func testMediaItemParsesLibJamiDictionary() {
        let dict = [
            "MEDIA_TYPE": "MEDIA_TYPE_AUDIO",
            "ENABLED": "true",
            "MUTED": "false",
            "SOURCE": "",
            "LABEL": "audio_0"
        ]
        let item = MediaItem(dict)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.type, .audio)
        XCTAssertEqual(item?.enabled, true)
        XCTAssertEqual(item?.muted, false)
        XCTAssertEqual(item?.source, "")
        XCTAssertEqual(item?.label, .audio(0))
        XCTAssertEqual(item?.onHold, false)
    }

    func testMediaItemParsesVideoWithHold() {
        let dict = [
            "MEDIA_TYPE": "MEDIA_TYPE_VIDEO",
            "ENABLED": "true",
            "MUTED": "true",
            "SOURCE": "camera://front",
            "LABEL": "video_0",
            "HOLD": "true"
        ]
        let item = MediaItem(dict)
        XCTAssertEqual(item?.type, .video)
        XCTAssertEqual(item?.muted, true)
        XCTAssertEqual(item?.onHold, true)
        XCTAssertEqual(item?.source, "camera://front")
    }

    func testMediaItemRejectsMissingType() {
        XCTAssertNil(MediaItem(["ENABLED": "true", "LABEL": "audio_0"]))
    }

    func testMediaItemRoundTripsToLibJamiDictionary() {
        let dict = [
            "MEDIA_TYPE": "MEDIA_TYPE_VIDEO",
            "ENABLED": "true",
            "MUTED": "false",
            "SOURCE": "camera://back",
            "LABEL": "video_0",
            "HOLD": "false"
        ]
        guard let item = MediaItem(dict) else {
            return XCTFail("parse failed")
        }
        XCTAssertEqual(item.toDictionary(), dict)
    }

    func testMediaItemFactoryProducesLibJamiKeys() {
        let audio = MediaItem.audio()
        let dict = audio.toDictionary()
        XCTAssertEqual(dict["MEDIA_TYPE"], "MEDIA_TYPE_AUDIO")
        XCTAssertEqual(dict["LABEL"], "audio_0")
        XCTAssertEqual(dict["ENABLED"], "true")
        XCTAssertEqual(dict["MUTED"], "false")

        let video = MediaItem.video(muted: true)
        XCTAssertEqual(video.toDictionary()["MEDIA_TYPE"], "MEDIA_TYPE_VIDEO")
        XCTAssertEqual(video.toDictionary()["LABEL"], "video_0")
        XCTAssertEqual(video.toDictionary()["MUTED"], "true")
    }

    func testAllLibJamiCallStatesParse() {
        let expected: [(String, LibJamiCallState)] = [
            ("INCOMING", .incoming),
            ("CONNECTING", .connecting),
            ("RINGING", .ringing),
            ("CURRENT", .current),
            ("HUNGUP", .hungUp),
            ("BUSY", .busy),
            ("PEER_BUSY", .peerBusy),
            ("FAILURE", .failure),
            ("HOLD", .hold),
            ("INACTIVE", .inactive),
            ("OVER", .over)
        ]
        for (raw, state) in expected {
            XCTAssertEqual(LibJamiCallState(rawValue: raw), state, raw)
        }
        XCTAssertNil(LibJamiCallState(rawValue: "NOT_A_STATE"))
    }

    func testCallDetailsParsesLibJamiDictionary() {
        let dict = [
            "CALL_TYPE": "1",
            "PEER_NUMBER": "jami:1234abcd@ring.dht",
            "REGISTERED_NAME": "alice",
            "DISPLAY_NAME": "Alice",
            "CALL_STATE": "CURRENT",
            "CONF_ID": "",
            "TIMESTAMP_START": "1700000000",
            "ACCOUNTID": accountId1,
            "PEER_HOLD": "false",
            "AUDIO_MUTED": "false",
            "VIDEO_MUTED": "true",
            "AUDIO_ONLY": "false",
            "TO_USERNAME": "alice"
        ]
        let details = CallDetails(dict)
        XCTAssertEqual(details.peerNumber, "jami:1234abcd@ring.dht")
        XCTAssertEqual(details.registeredName, "alice")
        XCTAssertEqual(details.displayName, "Alice")
        XCTAssertEqual(details.state, .current)
        XCTAssertNil(details.conferenceId)
        XCTAssertEqual(details.startedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(details.accountId, accountId1)
        XCTAssertEqual(details.peerHold, false)
        XCTAssertEqual(details.audioMuted, false)
        XCTAssertEqual(details.videoMuted, true)
        XCTAssertEqual(details.isAudioOnly, false)
    }

    func testCallDetailsToleratesMissingOptionalKeys() {
        let details = CallDetails([:])
        XCTAssertEqual(details.peerNumber, "")
        XCTAssertNil(details.state)
        XCTAssertNil(details.startedAt)
        XCTAssertNil(details.conferenceId)
        XCTAssertEqual(details.isAudioOnly, false)
    }

    func testCallDetailsNonEmptyConferenceId() {
        let details = CallDetails(["CONF_ID": "conf42"])
        XCTAssertEqual(details.conferenceId, "conf42")
    }

    func testConferenceParticipantInfoParsesAllFields() {
        let dict = [
            "uri": "1234abcd",
            "device": deviceId1,
            "sinkId": "conf1_video_0",
            "active": "true",
            "x": "0", "y": "120", "w": "640", "h": "360",
            "videoMuted": "false",
            "audioLocalMuted": "true",
            "audioModeratorMuted": "false",
            "isModerator": "true",
            "handRaised": "true",
            "voiceActivity": "false",
            "recording": "true"
        ]
        guard let info = ConferenceParticipantInfo(dict) else {
            return XCTFail("parse failed")
        }
        XCTAssertEqual(info.uri, "1234abcd")
        XCTAssertEqual(info.device, deviceId1)
        XCTAssertEqual(info.sinkId, SinkId(raw: "conf1_video_0"))
        XCTAssertTrue(info.isActive)
        XCTAssertEqual(info.frame, CGRect(x: 0, y: 120, width: 640, height: 360))
        XCTAssertFalse(info.isVideoMuted)
        XCTAssertTrue(info.isAudioLocallyMuted)
        XCTAssertFalse(info.isAudioModeratorMuted)
        XCTAssertTrue(info.isModerator)
        XCTAssertTrue(info.isHandRaised)
        XCTAssertFalse(info.hasVoiceActivity)
        XCTAssertTrue(info.isRecording)
    }

    func testConferenceParticipantInfoDefaults() {
        guard let info = ConferenceParticipantInfo(["uri": "x"]) else {
            return XCTFail("parse failed")
        }
        XCTAssertFalse(info.isActive)
        XCTAssertEqual(info.frame, .zero)
        XCTAssertFalse(info.isModerator)
        XCTAssertEqual(info.device, "")
    }

    func testParticipantIdentityIncludesDevice() {
        let participantOnFirstDevice = ConferenceParticipantInfo(["uri": "u1", "device": deviceId1])!
        let participantOnSecondDevice = ConferenceParticipantInfo(["uri": "u1", "device": deviceId2])!
        XCTAssertNotEqual(participantOnFirstDevice.id, participantOnSecondDevice.id)
    }

    func testLibJamiBoolAcceptsLibJamiVariants() {
        XCTAssertEqual(Bool(libJamiString: "true"), true)
        XCTAssertEqual(Bool(libJamiString: "TRUE"), true)
        XCTAssertEqual(Bool(libJamiString: "1"), true)
        XCTAssertEqual(Bool(libJamiString: "false"), false)
        XCTAssertEqual(Bool(libJamiString: "0"), false)
        XCTAssertNil(Bool(libJamiString: nil))
        XCTAssertNil(Bool(libJamiString: "maybe"))
    }
}
