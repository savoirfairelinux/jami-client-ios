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

final class MediaNegotiatorTests: XCTestCase {

    func testAnswerMatchesRequestSizeAndOrder() {
        let request: [MediaItem] = [.audio(), .video(), .video(label: .video(1))]
        let answer = MediaNegotiator.answer(forRequest: request, current: [.audio()])
        XCTAssertEqual(answer.map(\.label), request.map(\.label))
    }

    func testAnswerPreservesExistingStatePerLabel() {
        let current: [MediaItem] = [
            .audio(),
            MediaItem(type: .video, enabled: true, muted: true, label: .video(0))
        ]
        let request: [MediaItem] = [
            MediaItem(type: .audio, enabled: true, muted: false, label: .audio(0)),
            MediaItem(type: .video, enabled: true, muted: false, label: .video(0))
        ]

        let answer = MediaNegotiator.answer(forRequest: request, current: current)

        XCTAssertEqual(answer[0].muted, false)
        XCTAssertEqual(answer[0].enabled, true)
        XCTAssertEqual(answer[1].muted, true, "our video stays muted")
        XCTAssertEqual(answer[1].enabled, true)
    }

    func testAnswerDefaultsNewVideoToMuted() {
        let answer = MediaNegotiator.answer(
            forRequest: [.audio(), .video()],
            current: [.audio()]
        )
        XCTAssertEqual(answer[0].muted, false)
        XCTAssertEqual(answer[1].muted, true)
        XCTAssertEqual(answer[1].enabled, true)
    }

    func testAnswerMatchesByLabelAndType() {
        let current = [MediaItem(type: .audio, muted: true, label: .custom("weird"))]
        let request = [MediaItem(type: .video, muted: false, label: .custom("weird"))]

        let answer = MediaNegotiator.answer(forRequest: request, current: current)

        XCTAssertEqual(answer[0].muted, true, "new video defaults muted")
    }

    func testToggleMuteAudio() {
        let media: [MediaItem] = [.audio(), .video()]

        let result = MediaNegotiator.togglingMute(in: media, label: .audio(0),
                                                  cameraSource: "camera://mediumCamera")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].muted, true)
        XCTAssertEqual(result[0].enabled, true)
        XCTAssertEqual(result[1], media[1], "other streams untouched")
    }

    func testMutingVideoSwapsSourceToSentinel() {
        let media = [MediaItem(type: .video, enabled: true, muted: false,
                               source: "camera://mediumCamera", label: .video(0))]

        let result = MediaNegotiator.togglingMute(in: media, label: .video(0),
                                                  cameraSource: "camera://mediumCamera")

        XCTAssertEqual(result[0].muted, true)
        XCTAssertEqual(result[0].source, MediaNegotiator.mutedCameraSource)
    }

    func testUnmutingVideoRestoresCameraSource() {
        let media = [MediaItem(type: .video, enabled: true, muted: true,
                               source: MediaNegotiator.mutedCameraSource, label: .video(0))]

        let result = MediaNegotiator.togglingMute(in: media, label: .video(0),
                                                  cameraSource: "camera://mediumCamera")

        XCTAssertEqual(result[0].muted, false)
        XCTAssertEqual(result[0].source, "camera://mediumCamera")
    }

    func testTogglingMissingVideoAppendsUnmutedVideo() {
        let media: [MediaItem] = [.audio()]

        let result = MediaNegotiator.togglingMute(in: media, label: .video(0),
                                                  cameraSource: "camera://mediumCamera")

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].type, .video)
        XCTAssertEqual(result[1].label, .video(0))
        XCTAssertEqual(result[1].muted, false)
        XCTAssertEqual(result[1].enabled, true)
        XCTAssertEqual(result[1].source, "camera://mediumCamera",
                       "an unmuted stream must carry the camera, not the muted sentinel")
    }

    func testTogglingMissingAudioLabelChangesNothing() {
        let media: [MediaItem] = [.audio()]
        let result = MediaNegotiator.togglingMute(in: media, label: .audio(5),
                                                  cameraSource: "camera://1280_720Camera")
        XCTAssertEqual(result, media)
    }

    func testDefaultMediaListAudioOnly() {
        let list = MediaNegotiator.defaultMediaList(audioOnly: true,
                                                    videoSource: "camera://mediumCamera")
        XCTAssertEqual(list.map(\.label), [.audio(0)])
    }

    func testDefaultMediaListWithVideo() {
        let list = MediaNegotiator.defaultMediaList(audioOnly: false,
                                                    videoSource: "camera://mediumCamera")
        XCTAssertEqual(list.map(\.label), [.audio(0), .video(0)])
        XCTAssertEqual(list[1].source, "camera://mediumCamera")
        XCTAssertEqual(list[1].muted, false)
    }

    func testCompleteMediaListWithMutedVideo() {
        let list = MediaNegotiator.completeMediaList(videoMuted: true,
                                                     videoSource: "camera://mediumCamera")
        XCTAssertEqual(list.map(\.label), [.audio(0), .video(0)])
        XCTAssertEqual(list[1].muted, true)
        XCTAssertEqual(list[1].source, "")
    }

    func testCompleteMediaListWithVideo() {
        let list = MediaNegotiator.completeMediaList(videoMuted: false,
                                                     videoSource: "camera://mediumCamera")
        XCTAssertEqual(list[1].muted, false)
        XCTAssertEqual(list[1].source, "camera://mediumCamera")
    }
}
