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

final class SinkIdTests: XCTestCase {

    func testBareCallSink() {
        let sink = SinkId(raw: "0123456789abcdef")
        XCTAssertEqual(sink.baseId, "0123456789abcdef")
        XCTAssertNil(sink.mediaLabel)
        XCTAssertEqual(sink.raw, "0123456789abcdef")
    }

    func testConferenceStreamSink() {
        let sink = SinkId(raw: "0123456789abcdef_video_0")
        XCTAssertEqual(sink.baseId, "0123456789abcdef")
        XCTAssertEqual(sink.mediaLabel, .video(0))
    }

    func testAudioStreamSink() {
        let sink = SinkId(raw: "abc_audio_1")
        XCTAssertEqual(sink.baseId, "abc")
        XCTAssertEqual(sink.mediaLabel, .audio(1))
    }

    func testUnrecognizedSuffixKeepsFullBase() {
        for raw in ["abc_extra", "abc_video_x", "abc_screenshare_0"] {
            let sink = SinkId(raw: raw)
            XCTAssertEqual(sink.baseId, raw)
            XCTAssertNil(sink.mediaLabel)
        }
    }

    func testConstructionFromCallAndLabel() {
        let sink = SinkId(baseId: "abc", label: .video(0))
        XCTAssertEqual(sink.raw, "abc_video_0")
        XCTAssertEqual(sink, SinkId(raw: "abc_video_0"))
    }
}
