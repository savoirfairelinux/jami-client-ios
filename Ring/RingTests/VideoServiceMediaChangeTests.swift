/*
 *  Copyright (C) 2026-2026 Savoir-faire Linux Inc.
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
@testable import Ring

class VideoServiceMediaChangeTests: XCTestCase {

    private var mockVideoAdapter: ObjCMockVideoAdapter!
    private var videoService: VideoService!

    override func setUp() {
        super.setUp()
        mockVideoAdapter = ObjCMockVideoAdapter()
        mockVideoAdapter.requestMediaChangeReturnValue = true
        videoService = VideoService(withVideoAdapter: mockVideoAdapter)
    }

    override func tearDown() {
        videoService = nil
        mockVideoAdapter = nil
        super.tearDown()
    }

    func testMuteAudio_doesNotChangeSource() {
        let call = CallModel.createTestCall()
        let audioSource = "mic_device"
        let videoSource = "camera://front"
        call.mediaList = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0",
                MediaAttributeKey.muted.rawValue: "false",
                MediaAttributeKey.enabled.rawValue: "true",
                MediaAttributeKey.source.rawValue: audioSource
            ],
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
                MediaAttributeKey.label.rawValue: "video_0",
                MediaAttributeKey.muted.rawValue: "false",
                MediaAttributeKey.enabled.rawValue: "true",
                MediaAttributeKey.source.rawValue: videoSource
            ]
        ]

        videoService.requestMediaChange(call: call, mediaLabel: "audio_0", source: "front")

        let mediaList = mockVideoAdapter.requestMediaChangeMediaList as! [[String: String]]
        let audio = mediaList.first { $0[MediaAttributeKey.label.rawValue] == "audio_0" }!
        let video = mediaList.first { $0[MediaAttributeKey.label.rawValue] == "video_0" }!

        // Audio source must remain unchanged
        XCTAssertEqual(audio[MediaAttributeKey.source.rawValue], audioSource,
                       "Audio source must not change when muting — source changes trigger SDP re-invite")
        // Audio muted flag should toggle
        XCTAssertEqual(audio[MediaAttributeKey.muted.rawValue], "true")
        // Video must be unaffected
        XCTAssertEqual(video[MediaAttributeKey.source.rawValue], videoSource)
        XCTAssertEqual(video[MediaAttributeKey.muted.rawValue], "false")
    }

    func testMuteVideo_doesChangeSource() {
        let call = CallModel.createTestCall()
        let videoSource = "camera://front"
        call.mediaList = [
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.audio.rawValue,
                MediaAttributeKey.label.rawValue: "audio_0",
                MediaAttributeKey.muted.rawValue: "false",
                MediaAttributeKey.enabled.rawValue: "true",
                MediaAttributeKey.source.rawValue: "mic_device"
            ],
            [
                MediaAttributeKey.mediaType.rawValue: MediaAttributeValue.video.rawValue,
                MediaAttributeKey.label.rawValue: "video_0",
                MediaAttributeKey.muted.rawValue: "false",
                MediaAttributeKey.enabled.rawValue: "true",
                MediaAttributeKey.source.rawValue: videoSource
            ]
        ]

        videoService.requestMediaChange(call: call, mediaLabel: "video_0", source: "front")

        let mediaList = mockVideoAdapter.requestMediaChangeMediaList as! [[String: String]]
        let video = mediaList.first { $0[MediaAttributeKey.label.rawValue] == "video_0" }!

        // Video source should change to mutedCamera placeholder
        XCTAssertEqual(video[MediaAttributeKey.source.rawValue], "mutedCamera",
                       "Video source must change to mutedCamera when muting video")
        XCTAssertEqual(video[MediaAttributeKey.muted.rawValue], "true")
    }

    // MARK: - cameraSourceURI

    func testCameraSourceURI_addsPrefix() {
        XCTAssertEqual(videoService.cameraSourceURI(from: "front"), "camera://front")
    }

    func testCameraSourceURI_alreadyPrefixed() {
        XCTAssertEqual(videoService.cameraSourceURI(from: "camera://front"), "camera://front")
    }

    func testCameraSourceURI_emptyString() {
        XCTAssertEqual(videoService.cameraSourceURI(from: ""), "camera://")
    }
}
