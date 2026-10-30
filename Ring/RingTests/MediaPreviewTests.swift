/*
 * Copyright (C) 2026 Savoir-faire Linux Inc.
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

final class MediaPreviewTests: XCTestCase {

    func testDaemonInfoParsesIntoPreview() {
        let preview = MediaPreview(libJamiInfo: ["duration": "12500000",
                                                 "audio_stream": "1",
                                                 "video_stream": "0"],
                                   size: CGSize(width: 1080, height: 1920),
                                   thumbnailURL: URL(fileURLWithPath: "/cache/a.mp4.jpg"))

        XCTAssertEqual(preview.durationMicroseconds, 12_500_000)
        XCTAssertTrue(preview.hasAudio)
        XCTAssertTrue(preview.hasVideo)
        XCTAssertEqual(preview.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(preview.thumbnailURL?.path, "/cache/a.mp4.jpg")
        XCTAssertTrue(preview.isPlayable)
    }

    func testAudioFileHasNoVideo() {
        let preview = MediaPreview(libJamiInfo: ["duration": "3000000",
                                                 "audio_stream": "0",
                                                 "video_stream": "-1"])

        XCTAssertFalse(preview.hasVideo)
        XCTAssertNil(preview.thumbnailURL)
        XCTAssertNil(preview.size)
        XCTAssertTrue(preview.isPlayable)
    }

    func testUnreadableFileIsNotPlayable() {
        let defaults = MediaPreview(libJamiInfo: ["duration": "0",
                                                  "audio_stream": "-1",
                                                  "video_stream": "-1"])
        let garbled = MediaPreview(libJamiInfo: ["duration": "abc", "audio_stream": "x"])
        let empty = MediaPreview(libJamiInfo: [:])

        XCTAssertFalse(defaults.isPlayable)
        XCTAssertFalse(garbled.isPlayable)
        XCTAssertFalse(empty.isPlayable)
    }
}
