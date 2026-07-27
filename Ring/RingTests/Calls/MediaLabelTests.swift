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

final class MediaLabelTests: XCTestCase {

    func testParsesStandardAudioLabel() {
        XCTAssertEqual(MediaLabel("audio_0"), .audio(0))
        XCTAssertEqual(MediaLabel("audio_3"), .audio(3))
    }

    func testParsesStandardVideoLabel() {
        XCTAssertEqual(MediaLabel("video_0"), .video(0))
        XCTAssertEqual(MediaLabel("video_12"), .video(12))
    }

    func testUnknownLabelIsPreservedVerbatim() {
        XCTAssertEqual(MediaLabel("screenshare"), .custom("screenshare"))
        XCTAssertEqual(MediaLabel("video_x"), .custom("video_x"))
        XCTAssertEqual(MediaLabel(""), .custom(""))
    }

    func testLibJamiStringRoundTrip() {
        for raw in ["audio_0", "video_1", "screenshare", "video_"] {
            XCTAssertEqual(MediaLabel(raw).libJamiString, raw)
        }
    }
}
